package doctor

import (
	"encoding/json"
	"os"
	"path/filepath"
	"ryoku-cli/internal/sys"
	"testing"
)

// stripCaptureMenu drops menus.screenshot_menu, leaves every sibling menu and
// every top-level key untouched, and does nothing once the leaf is gone.
func TestStripCaptureMenu(t *testing.T) {
	// screenshot_menu present alongside a sibling menu and unrelated top-level
	// keys: the one leaf goes, everything else stays.
	full := []byte(`{"menus":{"clock_menu":{"position":"Left","minimum_width":410},"screenshot_menu":{"position":"Left","minimum_width":410,"widgets":[{"type":"Screenshots"}]},"screenshare_menu":{"position":"Left"}},"bars":{"frame":{"enable_frame":true}},"weatherLocation":"Oslo"}`)
	out, changed, err := stripCaptureMenu(full)
	if err != nil || !changed {
		t.Fatalf("screenshot_menu must be stripped: changed=%v err=%v", changed, err)
	}
	var cfg map[string]any
	if err := json.Unmarshal(out, &cfg); err != nil {
		t.Fatalf("stripped JSON does not parse: %v", err)
	}
	menus, ok := cfg["menus"].(map[string]any)
	if !ok {
		t.Fatalf("menus namespace lost: %v", cfg)
	}
	if _, present := menus["screenshot_menu"]; present {
		t.Error("screenshot_menu survived the strip")
	}
	for _, sib := range []string{"clock_menu", "screenshare_menu"} {
		if _, present := menus[sib]; !present {
			t.Errorf("sibling menu %q was lost: %v", sib, menus)
		}
	}
	if _, present := cfg["bars"]; !present {
		t.Errorf("unrelated top-level key bars was lost: %v", cfg)
	}
	if cfg["weatherLocation"] != "Oslo" {
		t.Errorf("passthrough key weatherLocation was lost: %v", cfg)
	}

	// stripping is idempotent: the cleaned store is now a no-op.
	if _, changed, err := stripCaptureMenu(out); err != nil || changed {
		t.Errorf("re-stripping a clean store must be a no-op: changed=%v err=%v", changed, err)
	}

	// a menus block without screenshot_menu is untouched.
	if _, changed, err := stripCaptureMenu([]byte(`{"menus":{"clock_menu":{"position":"Left"}}}`)); err != nil || changed {
		t.Errorf("a menus block without screenshot_menu must be untouched: changed=%v err=%v", changed, err)
	}

	// a store with no menus namespace at all is untouched.
	if _, changed, err := stripCaptureMenu([]byte(`{"bars":{}}`)); err != nil || changed {
		t.Errorf("a store with no menus namespace must be untouched: changed=%v err=%v", changed, err)
	}

	// garbage errors rather than silently rewriting.
	if _, _, err := stripCaptureMenu([]byte("not json")); err == nil {
		t.Fatal("garbage must error, not silently rewrite")
	}
}

// the reconciler reads the persisted store: check reports without mutating, fix
// strips in place and reports the change, and a clean store is a no-op.
func TestReconcileCaptureMenu(t *testing.T) {
	home := t.TempDir()
	t.Setenv("HOME", home)
	t.Setenv("XDG_CONFIG_HOME", filepath.Join(home, ".config"))
	path := filepath.Join(sys.ConfigHome(), "ryoku", "shell.json")
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		t.Fatal(err)
	}

	// no shell.json yet: ok, nothing to do.
	if r := reconcileCaptureMenu(false); r.status != recOK {
		t.Fatalf("missing shell.json: status=%s detail=%q, want ok", r.status.label(), r.detail)
	}

	stored := `{"menus":{"clock_menu":{"position":"Left"},"screenshot_menu":{"position":"Left","widgets":[{"type":"Screenshots"}]}}}`
	if err := os.WriteFile(path, []byte(stored), 0o644); err != nil {
		t.Fatal(err)
	}

	// check-only reports the leftover but leaves the file byte-for-byte.
	if r := reconcileCaptureMenu(true); r.status != recWouldFix {
		t.Fatalf("check with screenshot_menu: status=%s detail=%q, want todo", r.status.label(), r.detail)
	}
	if got, _ := os.ReadFile(path); string(got) != stored {
		t.Fatalf("check-only mutated the store: %s", got)
	}

	// fix strips it and reports the change.
	if r := reconcileCaptureMenu(false); r.status != recFixed {
		t.Fatalf("fix with screenshot_menu: status=%s detail=%q, want fixed", r.status.label(), r.detail)
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
	if _, present := menus["screenshot_menu"]; present {
		t.Error("fix did not strip screenshot_menu from the store")
	}
	if _, present := menus["clock_menu"]; !present {
		t.Error("fix dropped the sibling clock_menu")
	}

	// second run is a no-op: the store is now clean.
	if r := reconcileCaptureMenu(false); r.status != recOK {
		t.Fatalf("clean store: status=%s detail=%q, want ok", r.status.label(), r.detail)
	}
}
