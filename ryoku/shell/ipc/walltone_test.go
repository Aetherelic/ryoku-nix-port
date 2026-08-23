package main

import (
	"math"
	"path/filepath"
	"testing"
)

// TestWallToneLstar pins the luminance -> L* mapping the whole smart-ink layer
// measures in. The QML side reimplements it, and a tone distance is only a
// contrast budget if both agree: mid gray must land near 53.6, not the 50 a
// gamma-encoded luma would give.
func TestWallToneLstar(t *testing.T) {
	cases := []struct {
		name    string
		r, g, b uint8
		want    float64
	}{
		{"black", 0, 0, 0, 0},
		{"white", 255, 255, 255, 100},
		{"mid gray", 128, 128, 128, 53.6},
	}
	for _, c := range cases {
		got := lstarFromY(relLuminance(c.r, c.g, c.b))
		if math.Abs(got-c.want) > 0.5 {
			t.Errorf("%s: L* = %.2f, want %.1f", c.name, got, c.want)
		}
	}
}

// TestParseMatugenTones proves the tonal ramps survive the same --json output
// the roles are read from, and that neutral_variant reaches QML under the
// camelCase name the role keys already use.
func TestParseMatugenTones(t *testing.T) {
	out := []byte(`{"colors":{},"palettes":{
		"primary":{"0":{"color":"#000000"},"40":{"color":"#96406d"},"80":{"color":"#ffafd3"}},
		"neutral_variant":{"50":{"color":"#7a7580"}},
		"empty":{}
	}}`)
	ramps := parseMatugenTones(out)
	if ramps == nil {
		t.Fatal("parseMatugenTones returned nil for a palette-bearing document")
	}
	if got := ramps["primary"]["40"]; got != "#96406d" {
		t.Errorf("primary tone 40 = %q, want #96406d", got)
	}
	if got := ramps["neutralVariant"]["50"]; got != "#7a7580" {
		t.Errorf("neutralVariant tone 50 = %q, want #7a7580", got)
	}
	if _, ok := ramps["empty"]; ok {
		t.Error("a ramp with no usable tones should be dropped, not published empty")
	}
	if parseMatugenTones([]byte(`{"colors":{}}`)) != nil {
		t.Error("a document with no palettes should return nil so the file is left alone")
	}
}

// TestCellStats pins the per-cell reduction the detail map is built on: the
// mean tone and the POPULATION standard deviation (the whole cell, not a sample
// of it) of its sub-cell L* values.
func TestCellStats(t *testing.T) {
	cases := []struct {
		name     string
		vs       []float64
		mean, sd float64
	}{
		{"flat", []float64{50, 50, 50, 50}, 50, 0},
		{"black/white split", []float64{0, 0, 100, 100}, 50, 50},
		{"empty", nil, 0, 0},
	}
	for _, c := range cases {
		mean, sd := cellStats(c.vs)
		if math.Abs(mean-c.mean) > 1e-9 || math.Abs(sd-c.sd) > 1e-9 {
			t.Errorf("%s: mean=%.4f sd=%.4f, want mean=%.4f sd=%.4f",
				c.name, mean, sd, c.mean, c.sd)
		}
	}
}

// TestWallToneReduce checks the two image-shaped cases the placer relies on,
// through the pure reduction so no image on disk is needed: a flat picture is
// quiet everywhere, and a hard black|white edge is busy only in the cells it
// crosses and quiet in the uniform ones. grid keeps its 64-cell shape either
// way.
func TestWallToneReduce(t *testing.T) {
	sc, sr := wallToneCols*wallToneSub, wallToneRows*wallToneSub

	flat := make([]float64, sc*sr)
	for i := range flat {
		flat[i] = 42
	}
	grid, detail := wallToneReduce(flat)
	if len(grid) != 64 || len(detail) != 64 {
		t.Fatalf("flat: lengths grid=%d detail=%d, want 64 each", len(grid), len(detail))
	}
	for i := range grid {
		if grid[i] != 42 || detail[i] != 0 {
			t.Fatalf("flat: cell %d grid=%v detail=%v, want 42 and 0", i, grid[i], detail[i])
		}
	}

	// Split black|white two sub-columns into cell column 3, so that column
	// straddles the edge (half its samples each side) while every other column
	// sits wholly on one side. split=14 falls inside cell 3's sub-cols 12..15.
	const split = 14
	edge := make([]float64, sc*sr)
	for y := range sr {
		for x := range sc {
			if x >= split {
				edge[y*sc+x] = 100
			}
		}
	}
	grid, detail = wallToneReduce(edge)
	for cy := range wallToneRows {
		for cx := range wallToneCols {
			cell := cy*wallToneCols + cx
			if cx == 3 { // straddling column: 8 black + 8 white -> max spread
				if detail[cell] < 40 {
					t.Errorf("straddle cell (%d,%d) detail=%v, want a high spread", cx, cy, detail[cell])
				}
			} else if detail[cell] != 0 { // uniform column, either side of the edge
				t.Errorf("uniform cell (%d,%d) detail=%v, want 0", cx, cy, detail[cell])
			}
		}
	}
}

// TestWallToneMapMissing proves a missing or unreadable image yields no map, so
// writeWallpaperTone returns before writing and the previous wallpaper-tone.json
// stands (last wallpaper's tones still beat none). ffmpeg failing OR being absent
// both take the same not-ok path.
func TestWallToneMapMissing(t *testing.T) {
	if _, ok := wallToneMap(filepath.Join(t.TempDir(), "does-not-exist.png")); ok {
		t.Error("wallToneMap reported ok for a missing image")
	}
}
