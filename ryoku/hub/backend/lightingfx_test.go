package main

import "testing"

// a two-row grid, so a spatial effect has real positions to travel across.
func gridDevice() orgbDevice {
	return orgbDevice{
		Name:     "Grid",
		LEDCount: 6,
		Modes: []orgbMode{
			{Name: "Direct", Flags: modeHasPerLEDColor | modeHasBrightness, BriMax: 3},
			{Name: "Static", Flags: modeHasModeColor, ColorsMin: 1, ColorsMax: 1},
		},
		Zones: []orgbZone{{
			Name: "Keys", LEDs: 6, W: 3, H: 2,
			Map: []uint32{0, 1, 2, 3, 4, 5},
		}},
	}
}

func TestPaintModePrefersDirect(t *testing.T) {
	idx, m, ok := paintMode(gridDevice())
	if !ok || idx != 0 || m.Name != "Direct" {
		t.Fatalf("paintMode = %d %q %v", idx, m.Name, ok)
	}
	// a device with no per-LED mode cannot be painted, so no Ryoku effect is
	// offered for it and the UI shows only its own effects.
	plain := orgbDevice{Modes: []orgbMode{{Name: "Static", Flags: modeHasModeColor}}}
	if canPaint(plain) {
		t.Fatal("a device without a per-LED mode must not be paintable")
	}
}

func TestLedPositionsFollowTheGrid(t *testing.T) {
	pos := ledPositions(gridDevice())
	want := []float64{0, 0.5, 1, 0, 0.5, 1}
	for i, w := range want {
		if pos[i] != w {
			t.Fatalf("led %d at %v, want %v (positions %v)", i, pos[i], w, pos)
		}
	}
	// no grid: fall back to LED order, still spanning the device.
	flat := ledPositions(orgbDevice{LEDCount: 3})
	if flat[0] != 0 || flat[2] != 1 {
		t.Fatalf("flat positions = %v", flat)
	}
}

func TestSolidPaintsOneColourScaledByBrightness(t *testing.T) {
	pos := ledPositions(gridDevice())
	full := fxFrame("solid", pos, 0, 0, 1, 0x2356F2) // #F25623
	for i, c := range full {
		if c != 0x2356F2 {
			t.Fatalf("led %d = %#x", i, c)
		}
	}
	half := fxFrame("solid", pos, 0, 0, 0.5, 0x2356F2)
	if half[0] != 0x122B79 { // R 242->121, G 86->43, B 35->18
		t.Fatalf("half brightness = %#x", half[0])
	}
	if dark := fxFrame("solid", pos, 0, 0, 0, 0x2356F2); dark[0] != 0 {
		t.Fatalf("zero brightness = %#x", dark[0])
	}
}

func TestWaveVariesAcrossTheDeviceAndOverTime(t *testing.T) {
	pos := ledPositions(gridDevice())
	a := fxFrame("wave", pos, 0, 0.5, 1, 0x0000FF)
	if a[0] == a[1] || a[1] == a[2] {
		t.Fatalf("a wave must differ along the device: %v", a)
	}
	if a[0] != a[3] || a[2] != a[5] {
		t.Fatal("two LEDs in the same column must match, so the wave reads as vertical bands")
	}
	b := fxFrame("wave", pos, 1.5, 0.5, 1, 0x0000FF)
	if a[0] == b[0] {
		t.Fatal("a wave must move over time")
	}
}

func TestBreatheRisesToTheBaseColourAndFallsBack(t *testing.T) {
	base := uint32(0x2356F2)
	brightest, dimmest := uint32(0), uint32(0xFFFFFF)
	for step := range 200 {
		c := fxFrame("breathe", []float64{0}, float64(step)*0.02, 0.5, 1, base)[0]
		if c&0xFF > brightest&0xFF {
			brightest = c
		}
		if c&0xFF < dimmest&0xFF {
			dimmest = c
		}
	}
	if brightest != base {
		t.Fatalf("a breath must reach the base colour; brightest was %#x, base %#x", brightest, base)
	}
	if dimmest == base || dimmest == 0 {
		t.Fatalf("a breath must dip without going dark; dimmest was %#x", dimmest)
	}
}

func TestCometAndScannerLightOnlyABand(t *testing.T) {
	pos := make([]float64, 20)
	for i := range pos {
		pos[i] = float64(i) / 19
	}
	for _, id := range []string{"comet", "scanner"} {
		frame := fxFrame(id, pos, 0.8, 1, 1, 0x0000FF)
		lit := 0
		for _, c := range frame {
			if c != 0 {
				lit++
			}
		}
		if lit == 0 || lit == len(frame) {
			t.Fatalf("%s lit %d of %d LEDs; it should be a band", id, lit, len(frame))
		}
	}
}

func TestSpectrumIsOneColourThatCycles(t *testing.T) {
	pos := []float64{0, 0.5, 1}
	a := fxFrame("spectrum", pos, 0, 1, 1, 0x0000FF)
	if a[0] != a[1] || a[1] != a[2] {
		t.Fatalf("spectrum must paint the whole device one colour: %v", a)
	}
	b := fxFrame("spectrum", pos, 2, 1, 1, 0x0000FF)
	if a[0] == b[0] {
		t.Fatal("spectrum must cycle over time")
	}
}

func TestUnknownEffectFallsBackToSolid(t *testing.T) {
	got := fxFrame("nonsense", []float64{0, 1}, 3, 1, 1, 0x2356F2)
	if got[0] != 0x2356F2 || got[1] != 0x2356F2 {
		t.Fatalf("unknown effect = %v, want the plain colour", got)
	}
}

func TestHueRoundTrip(t *testing.T) {
	for _, c := range []uint32{0x0000FF, 0x00FF00, 0xFF0000, 0x2356F2} {
		r, g, b := unpackRGB(c)
		h, s, v := rgbToHSV(r, g, b)
		if got := packHSV(h, s, v); got != c {
			t.Fatalf("round trip of %#x gave %#x", c, got)
		}
	}
}

func TestEffectCatalogueIsSelfConsistent(t *testing.T) {
	seen := map[string]bool{}
	for _, e := range fxEffects {
		if e.ID == "" || e.Label == "" {
			t.Fatalf("effect with no id or label: %+v", e)
		}
		if seen[e.ID] {
			t.Fatalf("duplicate effect id %q", e.ID)
		}
		seen[e.ID] = true
		if _, ok := fxByID(e.ID); !ok {
			t.Fatalf("%q is listed but cannot be looked up", e.ID)
		}
	}
	if _, ok := fxByID("solid"); !ok {
		t.Fatal("solid is the still effect every paintable device gets")
	}
	if _, ok := fxByID("does-not-exist"); ok {
		t.Fatal("an unknown id must not resolve, or a bad patch would be stored")
	}
}
