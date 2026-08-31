package doctor

import (
	"encoding/json"
	"testing"
)

// addDepthModule appends "depth" to a quick-settings rail that is exactly the
// pre-depth default, preserves every sibling and top-level key, and no-ops on a
// customized or already-migrated rail.
func TestAddDepthModule(t *testing.T) {
	full := []byte(`{"frameBars":{"menus":{"quick-settings":{"anchor":"left","minWidth":410,"modules":["home","notifications","weather","capture"]},"weather":{"anchor":"right"}},"style":"slate-frame"},"weatherLocation":"Oslo"}`)
	out, changed, err := addDepthModule(full)
	if err != nil || !changed {
		t.Fatalf("the pre-depth default must gain depth: changed=%v err=%v", changed, err)
	}
	if got, want := captureModules(t, out), []string{"home", "notifications", "weather", "capture", "depth"}; !sameStrings(got, want) {
		t.Fatalf("modules = %v, want %v", got, want)
	}
	var cfg map[string]any
	if err := json.Unmarshal(out, &cfg); err != nil {
		t.Fatalf("migrated JSON does not parse: %v", err)
	}
	frame := cfg["frameBars"].(map[string]any)
	if _, ok := frame["menus"].(map[string]any)["weather"]; !ok {
		t.Error("sibling weather menu was lost")
	}
	if frame["style"] != "slate-frame" {
		t.Errorf("frameBars.style was lost: %v", frame["style"])
	}
	if cfg["weatherLocation"] != "Oslo" {
		t.Errorf("passthrough key weatherLocation was lost: %v", cfg)
	}

	// idempotent once depth is present.
	if _, changed, err := addDepthModule(out); err != nil || changed {
		t.Errorf("re-running on a migrated store must be a no-op: changed=%v err=%v", changed, err)
	}

	// a rail still on the retired three (pre-capture) is left for the capture
	// reconciler, and any customized rail is untouched.
	for _, custom := range []string{
		`{"frameBars":{"menus":{"quick-settings":{"modules":["home","notifications","weather"]}}}}`,
		`{"frameBars":{"menus":{"quick-settings":{"modules":["home","notifications","weather","capture","media"]}}}}`,
	} {
		if _, changed, err := addDepthModule([]byte(custom)); err != nil || changed {
			t.Errorf("a non-matching rail must be untouched: changed=%v err=%v (%s)", changed, err, custom)
		}
	}

	if _, changed, err := addDepthModule([]byte(`{"bars":{}}`)); err != nil || changed {
		t.Errorf("a store with no frameBars must be untouched: changed=%v err=%v", changed, err)
	}
	if _, _, err := addDepthModule([]byte("not json")); err == nil {
		t.Fatal("garbage must error, not silently rewrite")
	}
}
