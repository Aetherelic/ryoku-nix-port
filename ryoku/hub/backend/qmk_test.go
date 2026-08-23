package main

import (
	"errors"
	"reflect"
	"testing"
)

// rgbToHSV255 must match Python colorsys.rgb_to_hsv scaled to 0-255 and
// truncated, since that is the reference omarchy's Framework 16 script uses.
func TestRGBToHSV255MatchesColorsys(t *testing.T) {
	cases := []struct {
		name             string
		r, g, b          float64
		wantHue, wantSat uint8
	}{
		{"red", 1, 0, 0, 0, 255},
		{"green", 0, 1, 0, 85, 255},
		{"blue", 0, 0, 1, 170, 255},
		{"cyan", 0, 1, 1, 127, 255},
		{"white", 1, 1, 1, 0, 0},
		{"black", 0, 0, 0, 0, 0},
	}
	for _, c := range cases {
		hue, sat := rgbToHSV255(c.r, c.g, c.b)
		if hue != c.wantHue || sat != c.wantSat {
			t.Errorf("%s: got hue=%d sat=%d, want hue=%d sat=%d", c.name, hue, sat, c.wantHue, c.wantSat)
		}
	}
}

func TestQmkDevicePresent(t *testing.T) {
	defer restoreQmkSeams(qmkLookPath, qmkList, qmkRun)
	qmkLookPath = func() bool { return true }

	qmkList = func() (string, error) { return "No device found\n", nil }
	if qmkDevicePresent() {
		t.Error("the no-device marker must read as absent")
	}
	qmkList = func() (string, error) { return "", nil }
	if qmkDevicePresent() {
		t.Error("empty output must read as absent")
	}
	qmkList = func() (string, error) { return "", errors.New("permission denied") }
	if qmkDevicePresent() {
		t.Error("an enumeration error must read as absent")
	}
	qmkList = func() (string, error) {
		return "32ac:0014  Framework  Laptop 16 Keyboard  0.1.0  FRAK000\n", nil
	}
	if !qmkDevicePresent() {
		t.Error("a listed device must read as present")
	}

	qmkLookPath = func() bool { return false }
	if qmkDevicePresent() {
		t.Error("without qmk_hid the provider must read as absent")
	}
}

func TestReadQMKDevicesAbsentIsQuiet(t *testing.T) {
	defer restoreQmkSeams(qmkLookPath, qmkList, qmkRun)
	qmkLookPath = func() bool { return false }
	devices, err := readQMKDevices()
	if err != nil {
		t.Fatalf("absence must not be an error: %v", err)
	}
	if devices != nil {
		t.Fatalf("no device expected, got %+v", devices)
	}
}

func TestQmkDeviceIdentityAndRouting(t *testing.T) {
	d := qmkDeviceView()
	if d.Provider != qmkProvider || d.Type != "Keyboard" {
		t.Fatalf("device = %+v", d)
	}
	if len(d.Modes) != 1 || d.Modes[0].Name != "Static" || d.Modes[0].Value != qmkEffectStatic {
		t.Fatalf("modes = %+v", d.Modes)
	}
	key := deviceKey(d)
	if key != "QMK keyboard#qmk:keyboard" {
		t.Fatalf("key = %q", key)
	}
	if providersForKey(key) != lightingQMK {
		t.Fatalf("providersForKey(%q) routed to the wrong provider", key)
	}
}

// applyOne must drive a QMK device through qmk_hid without an OpenRGB connection,
// converting the accent to the hue/saturation the VIA protocol wants.
func TestApplyOneRoutesQMKToHidWrite(t *testing.T) {
	defer restoreQmkSeams(qmkLookPath, qmkList, qmkRun)
	var got []string
	qmkRun = func(args ...string) error { got = args; return nil }

	live := []orgbDevice{qmkDeviceView()}
	s := &lightingSettings{Managed: true, Mode: "Static", Source: "accent", Brightness: -1, Speed: -1}
	if err := applyOne(nil, live, deviceKey(live[0]), s, "#00FF00"); err != nil {
		t.Fatalf("applyOne: %v", err)
	}
	// green accent -> hue 85, full saturation; device-own brightness (-1) -> 100%.
	want := []string{"via", "--rgb-effect", "1", "--rgb-hue", "85", "--rgb-saturation", "255", "--rgb-brightness", "100"}
	if !reflect.DeepEqual(got, want) {
		t.Fatalf("qmk_hid args = %v, want %v", got, want)
	}
}

func TestQmkApplyHonoursBrightness(t *testing.T) {
	defer restoreQmkSeams(qmkLookPath, qmkList, qmkRun)
	var got []string
	qmkRun = func(args ...string) error { got = args; return nil }

	mode := orgbMode{Name: "Static", Value: qmkEffectStatic, Colors: []uint32{0xFF0000}} // blue packed (red low byte)
	if err := qmkApply(mode, 40); err != nil {
		t.Fatalf("qmkApply: %v", err)
	}
	want := []string{"via", "--rgb-effect", "1", "--rgb-hue", "170", "--rgb-saturation", "255", "--rgb-brightness", "40"}
	if !reflect.DeepEqual(got, want) {
		t.Fatalf("qmk_hid args = %v, want %v", got, want)
	}
}

// A QMK keyboard coexists with the other providers' devices in one report.
func TestQmkKeyboardJoinsLightingDevices(t *testing.T) {
	mb := orgbDevice{Name: "Desktop", Type: "Motherboard", Serial: "mb"}
	live := append(combineLightingDevices([]orgbDevice{mb}, nil), qmkDeviceView())
	if len(live) != 2 {
		t.Fatalf("devices = %d, want motherboard and QMK keyboard", len(live))
	}
	if live[1].Provider != qmkProvider || live[1].Type != "Keyboard" {
		t.Fatalf("devices = %+v", live)
	}
}

func restoreQmkSeams(look func() bool, list func() (string, error), run func(...string) error) {
	qmkLookPath = look
	qmkList = list
	qmkRun = run
}
