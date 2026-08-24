package doctor

import "testing"

func TestPlanPhantomOutput(t *testing.T) {
	real := phantomMon{Name: "eDP-2", Make: "Thermotrex Corporation", Model: "TL140ADXP02-0", PhysicalWidth: 300}
	extReal := phantomMon{Name: "DP-1", Make: "Dell", Model: "U2720Q", Serial: "ABC", PhysicalWidth: 600}
	ghost := phantomMon{Name: "HDMI-A-1", Make: "", Model: "", PhysicalWidth: 0}
	ghostDP := phantomMon{Name: "DP-3", Make: "", Model: "", PhysicalWidth: 0}
	// an EDID-less output that is DISABLED must never be flagged.
	ghostOff := phantomMon{Name: "DP-9", Make: "", Model: "", PhysicalWidth: 0, Disabled: true}
	// an internal panel with a blank EDID is still a real panel, never a phantom.
	blankPanel := phantomMon{Name: "eDP-1", Make: "", Model: "", PhysicalWidth: 0}

	cases := []struct {
		name string
		in   []phantomMon
		want recStatus
	}{
		{"single real panel", []phantomMon{real}, recOK},
		{"real panel + real external", []phantomMon{real, extReal}, recOK},
		{"real panel + one ghost", []phantomMon{real, ghost}, recWarn},
		{"real panel + two ghosts", []phantomMon{real, ghost, ghostDP}, recWarn},
		{"ghost is disabled", []phantomMon{real, ghostOff}, recOK},
		{"sole output has no EDID (real quirky screen)", []phantomMon{ghost}, recOK},
		{"internal panel with blank EDID is not a phantom", []phantomMon{blankPanel}, recOK},
		{"internal blank panel + real external, no ghost", []phantomMon{blankPanel, extReal}, recOK},
		{"empty (no session / parse failure)", nil, recOK},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			got := planPhantomOutput(tc.in)
			if got.status != tc.want {
				t.Fatalf("status = %v, want %v (detail: %q)", got.status, tc.want, got.detail)
			}
			if tc.want == recWarn {
				if got.remedy == "" {
					t.Fatalf("a phantom warning must carry a remedy")
				}
				// the named ghost must appear in the detail so the user knows which output.
				if got.detail == "" {
					t.Fatalf("warning must name the phantom output")
				}
			}
		})
	}
}

func TestLooksPhantom(t *testing.T) {
	cases := []struct {
		name string
		in   phantomMon
		want bool
	}{
		{"ghost external", phantomMon{Name: "DP-2", PhysicalWidth: 0}, true},
		{"real external", phantomMon{Name: "DP-2", Make: "LG", PhysicalWidth: 500}, false},
		{"model-only external is real", phantomMon{Name: "DP-2", Model: "X", PhysicalWidth: 0}, false},
		{"sized external with blank EDID is real", phantomMon{Name: "DP-2", PhysicalWidth: 500}, false},
		{"internal panel never a phantom", phantomMon{Name: "eDP-1", PhysicalWidth: 0}, false},
		{"DSI internal never a phantom", phantomMon{Name: "DSI-1", PhysicalWidth: 0}, false},
		{"disabled output never a phantom", phantomMon{Name: "DP-2", PhysicalWidth: 0, Disabled: true}, false},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			if got := looksPhantom(tc.in); got != tc.want {
				t.Fatalf("looksPhantom(%+v) = %v, want %v", tc.in, got, tc.want)
			}
		})
	}
}
