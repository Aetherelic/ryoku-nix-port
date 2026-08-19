package importer

import (
	"encoding/json"
	"testing"
)

// A ScanResult as ryoku-hub emits it: one deep app (Hyprland, two shadowed
// combos) and one layer app (kitty, no conflicts). The builder must carry both
// apps forward and resolve every conflict to the chosen side, keyed by the
// opaque norm string, never the display combo.
const sampleScan = `{
  "source": "/tmp/ryoku-import-1234",
  "apps": [
    {
      "id": "hyprland",
      "name": "Hyprland",
      "present": true,
      "path": "/tmp/ryoku-import-1234/hypr",
      "tier": "deep",
      "summary": "47 keybinds, 12 window rules, 30 settings",
      "items": [
        { "kind": "bind", "raw": "bind = SUPER, Q, exec, kitty", "combo": "SUPER + Q", "dispatcher": "exec", "ingestable": true }
      ],
      "conflicts": [
        { "combo": "SUPER + Q", "norm": "q+super", "ryoku": { "action": "close", "desc": "Close window" }, "mine": { "raw": "bind = SUPER, Q, exec, kitty", "desc": "Launch kitty" }, "kind": "shipped" },
        { "combo": "SUPER + Return", "norm": "return+super", "ryoku": { "action": "exec", "desc": "Terminal" }, "mine": { "raw": "bind = SUPER, Return, exec, alacritty", "desc": "Launch alacritty" }, "kind": "shipped" }
      ]
    },
    {
      "id": "kitty",
      "name": "kitty",
      "present": true,
      "path": "/tmp/ryoku-import-1234/kitty",
      "tier": "layer",
      "summary": "colors + 20 settings",
      "items": [ { "kind": "setting", "raw": "font_size 12", "ingestable": false } ],
      "conflicts": []
    }
  ]
}`

func parseSample(t *testing.T) scanResult {
	t.Helper()
	var sr scanResult
	if err := json.Unmarshal([]byte(sampleScan), &sr); err != nil {
		t.Fatalf("unmarshal sample scan: %v", err)
	}
	return sr
}

func TestBuildDecisionsIncludesEveryApp(t *testing.T) {
	d := buildDecisions(parseSample(t), "mine")

	if d.Source != "/tmp/ryoku-import-1234" {
		t.Errorf("source not carried through: got %q", d.Source)
	}
	for _, id := range []string{"hyprland", "kitty"} {
		choice, ok := d.Apps[id]
		if !ok {
			t.Errorf("app %q missing from decisions", id)
			continue
		}
		if !choice.Include {
			t.Errorf("app %q should be included", id)
		}
	}
	if len(d.Apps) != 2 {
		t.Errorf("expected 2 apps, got %d", len(d.Apps))
	}
}

// Every conflict resolves to the chosen side, keyed by norm. "ryoku" is the
// safe default the engine assumes for anything absent, so the CLI still emits
// each norm explicitly so the choice is auditable.
func TestBuildDecisionsResolvesConflictsToChosenSide(t *testing.T) {
	for _, keep := range []string{"mine", "ryoku"} {
		d := buildDecisions(parseSample(t), keep)
		if len(d.Conflicts) != 2 {
			t.Fatalf("keep=%s: expected 2 conflicts, got %d", keep, len(d.Conflicts))
		}
		for _, norm := range []string{"q+super", "return+super"} {
			if got := d.Conflicts[norm]; got != keep {
				t.Errorf("keep=%s: conflict %q resolved to %q", keep, norm, got)
			}
		}
	}
}

// The decisions payload is a wire contract with ryoku-hub: the field names and
// nesting must match exactly, so assert the marshalled JSON, not just the Go
// struct.
func TestBuildDecisionsMarshalsToContractShape(t *testing.T) {
	payload, err := json.Marshal(buildDecisions(parseSample(t), "mine"))
	if err != nil {
		t.Fatalf("marshal decisions: %v", err)
	}
	var got struct {
		Source string `json:"source"`
		Apps   map[string]struct {
			Include bool `json:"include"`
		} `json:"apps"`
		Conflicts map[string]string `json:"conflicts"`
	}
	if err := json.Unmarshal(payload, &got); err != nil {
		t.Fatalf("decisions JSON does not match contract shape: %v\n%s", err, payload)
	}
	if got.Source != "/tmp/ryoku-import-1234" {
		t.Errorf("source field: got %q", got.Source)
	}
	if !got.Apps["hyprland"].Include || !got.Apps["kitty"].Include {
		t.Errorf("apps did not marshal with include:true: %s", payload)
	}
	if got.Conflicts["q+super"] != "mine" {
		t.Errorf("conflict did not marshal as string side: %s", payload)
	}
}

func TestParseArgs(t *testing.T) {
	cases := []struct {
		name string
		args []string
		want options
	}{
		{"path only defaults keep mine", []string{"/dots"}, options{source: "/dots", keep: "mine"}},
		{"keep ryoku", []string{"/dots", "--keep", "ryoku"}, options{source: "/dots", keep: "ryoku"}},
		{"url source", []string{"--url", "https://x/y.git"}, options{source: "https://x/y.git", keep: "mine"}},
		{"undo latest", []string{"--undo"}, options{undo: true, keep: "mine"}},
		{"undo with ts", []string{"--undo", "20260818-140322"}, options{undo: true, ts: "20260818-140322", keep: "mine"}},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			got, err := parseArgs(tc.args)
			if err != nil {
				t.Fatalf("parseArgs(%v): %v", tc.args, err)
			}
			if got != tc.want {
				t.Errorf("parseArgs(%v) = %+v, want %+v", tc.args, got, tc.want)
			}
		})
	}
}

func TestParseArgsRejectsBadKeep(t *testing.T) {
	if _, err := parseArgs([]string{"/dots", "--keep", "both"}); err == nil {
		t.Error("expected error for --keep both")
	}
}
