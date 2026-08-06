package doctor

import (
	"encoding/json"
	"os"
	"path/filepath"
	"ryoku-cli/internal/sys"
	"testing"
)

// The retired-menu strip drops menus.screenshot_menu, menus.screenshare_menu,
// and frameBars.menus.screenshare, leaves every sibling menu and every
// top-level key untouched, and does nothing once all three are gone.
func TestStripCaptureMenu(t *testing.T) {
	// all three retired leaves present alongside sibling menus and unrelated
	// top-level keys: the retired leaves go, everything else stays.
	full := []byte(`{"menus":{"clock_menu":{"position":"Left","minimum_width":410},"screenshot_menu":{"position":"Left"},"screenshare_menu":{"position":"Left"}},"frameBars":{"menus":{"quick-settings":{"anchor":"left"},"screenshare":{"anchor":"left","minWidth":410}}},"weatherLocation":"Oslo"}`)
	out, changed, err := stripRetiredMenus(full)
	if err != nil || !changed {
		t.Fatalf("retired menus must be stripped: changed=%v err=%v", changed, err)
	}
	var cfg map[string]any
	if err := json.Unmarshal(out, &cfg); err != nil {
		t.Fatalf("stripped JSON does not parse: %v", err)
	}
	menus, ok := cfg["menus"].(map[string]any)
	if !ok {
		t.Fatalf("menus namespace lost: %v", cfg)
	}
	for _, retired := range []string{"screenshot_menu", "screenshare_menu"} {
		if _, present := menus[retired]; present {
			t.Errorf("retired menu %q survived the strip", retired)
		}
	}
	if _, present := menus["clock_menu"]; !present {
		t.Errorf("sibling menu clock_menu was lost: %v", menus)
	}
	frameMenus, ok := cfg["frameBars"].(map[string]any)["menus"].(map[string]any)
	if !ok {
		t.Fatalf("frameBars.menus namespace lost: %v", cfg)
	}
	if _, present := frameMenus["screenshare"]; present {
		t.Error("frameBars.menus.screenshare survived the strip")
	}
	if _, present := frameMenus["quick-settings"]; !present {
		t.Errorf("sibling frameBars.menus.quick-settings was lost: %v", frameMenus)
	}
	if cfg["weatherLocation"] != "Oslo" {
		t.Errorf("passthrough key weatherLocation was lost: %v", cfg)
	}

	// stripping is idempotent: the cleaned store is now a no-op.
	if _, changed, err := stripRetiredMenus(out); err != nil || changed {
		t.Errorf("re-stripping a clean store must be a no-op: changed=%v err=%v", changed, err)
	}

	// a store carrying none of the retired leaves is untouched.
	if _, changed, err := stripRetiredMenus([]byte(`{"menus":{"clock_menu":{"position":"Left"}},"frameBars":{"menus":{"quick-settings":{"anchor":"left"}}}}`)); err != nil || changed {
		t.Errorf("a store without the retired leaves must be untouched: changed=%v err=%v", changed, err)
	}

	// a store with neither namespace at all is untouched.
	if _, changed, err := stripRetiredMenus([]byte(`{"bars":{}}`)); err != nil || changed {
		t.Errorf("a store with no menus or frameBars namespace must be untouched: changed=%v err=%v", changed, err)
	}

	// garbage errors rather than silently rewriting.
	if _, _, err := stripRetiredMenus([]byte("not json")); err == nil {
		t.Fatal("garbage must error, not silently rewrite")
	}
}

// the reconciler reads the persisted store: check reports the retired menus
// without mutating, fix strips them in place and reports the change, and a clean
// store is a no-op.
func TestReconcileCaptureMenu(t *testing.T) {
	home := t.TempDir()
	t.Setenv("HOME", home)
	t.Setenv("XDG_CONFIG_HOME", filepath.Join(home, ".config"))
	path := filepath.Join(sys.ConfigHome(), "ryoku", "shell.json")
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		t.Fatal(err)
	}

	// no shell.json yet: ok, nothing to do.
	if r := reconcileRetiredMenus(false); r.status != recOK {
		t.Fatalf("missing shell.json: status=%s detail=%q, want ok", r.status.label(), r.detail)
	}

	// all three retired leaves, alongside siblings the shell still reads.
	stored := `{"menus":{"clock_menu":{"position":"Left","minimum_width":410},"screenshot_menu":{"position":"Left"},"screenshare_menu":{"position":"Left"}},"frameBars":{"menus":{"quick-settings":{"anchor":"left"},"screenshare":{"anchor":"left","minWidth":410}}},"weatherLocation":"Oslo"}`
	if err := os.WriteFile(path, []byte(stored), 0o644); err != nil {
		t.Fatal(err)
	}

	// check-only reports the leftovers but leaves the file byte-for-byte.
	if r := reconcileRetiredMenus(true); r.status != recWouldFix {
		t.Fatalf("check with retired menus: status=%s detail=%q, want todo", r.status.label(), r.detail)
	}
	if got, _ := os.ReadFile(path); string(got) != stored {
		t.Fatalf("check-only mutated the store: %s", got)
	}

	// fix strips every retired leaf and reports the change.
	if r := reconcileRetiredMenus(false); r.status != recFixed {
		t.Fatalf("fix with retired menus: status=%s detail=%q, want fixed", r.status.label(), r.detail)
	}
	raw, err := os.ReadFile(path)
	if err != nil {
		t.Fatal(err)
	}
	var cfg map[string]any
	if err := json.Unmarshal(raw, &cfg); err != nil {
		t.Fatalf("rewritten store does not parse: %v", err)
	}
	menus := cfg["menus"].(map[string]any)
	for _, retired := range []string{"screenshot_menu", "screenshare_menu"} {
		if _, present := menus[retired]; present {
			t.Errorf("fix did not strip %s from the store", retired)
		}
	}
	if _, present := menus["clock_menu"]; !present {
		t.Error("fix dropped the sibling clock_menu")
	}
	frameMenus := cfg["frameBars"].(map[string]any)["menus"].(map[string]any)
	if _, present := frameMenus["screenshare"]; present {
		t.Error("fix did not strip frameBars.menus.screenshare from the store")
	}
	if _, present := frameMenus["quick-settings"]; !present {
		t.Error("fix dropped the sibling frameBars.menus.quick-settings")
	}
	if cfg["weatherLocation"] != "Oslo" {
		t.Errorf("fix dropped the passthrough key weatherLocation: %v", cfg["weatherLocation"])
	}

	// second run is a no-op: the store is now clean.
	if r := reconcileRetiredMenus(false); r.status != recOK {
		t.Fatalf("clean store: status=%s detail=%q, want ok", r.status.label(), r.detail)
	}
}
