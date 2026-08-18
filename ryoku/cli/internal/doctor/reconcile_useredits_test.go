package doctor

import (
	"os"
	"path/filepath"
	"ryoku-cli/internal/sys"
	"testing"
)

func ueSetup(t *testing.T) string {
	t.Helper()
	home := t.TempDir()
	base := t.TempDir()
	t.Setenv("HOME", home)
	t.Setenv("XDG_CONFIG_HOME", filepath.Join(home, ".config"))
	t.Setenv("XDG_STATE_HOME", filepath.Join(home, ".local", "state"))
	t.Setenv("RYOKU_CONFIG_BASE", base)
	return base
}

func ueWrite(t *testing.T, path, body string) {
	t.Helper()
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(path, []byte(body), 0o644); err != nil {
		t.Fatal(err)
	}
}

func ueWantFile(t *testing.T, path, want string) {
	t.Helper()
	b, err := os.ReadFile(path)
	if err != nil {
		t.Fatalf("read %s: %v", path, err)
	}
	if string(b) != want {
		t.Fatalf("%s = %q, want %q", path, string(b), want)
	}
}

// A live-owned user file is edited in place and must never be adopted into the
// overlay: the reconciler seeds the guide and leaves the live file alone. (The
// old adopt step copied it in, and the overlay then re-laid a frozen snapshot
// over the live file every update, wiping later edits.)
func TestReconcileUserEditsSeedsGuideNoAdopt(t *testing.T) {
	ueSetup(t)
	cfg := sys.ConfigHome()
	edits := sys.UserEditsDir()

	ueWrite(t, filepath.Join(cfg, "hypr/user.lua"), "-- my hypr\n")

	if r := reconcileUserEdits(true); r.status != recWouldFix {
		t.Fatalf("fresh check: status=%s detail=%q, want todo", r.status.label(), r.detail)
	}
	if r := reconcileUserEdits(false); r.status != recFixed {
		t.Fatalf("fresh fix: status=%s detail=%q, want fixed", r.status.label(), r.detail)
	}
	if !sys.Exists(filepath.Join(edits, "README.md")) {
		t.Fatal("overlay guide not written")
	}
	if sys.Exists(filepath.Join(edits, "hypr/user.lua")) {
		t.Fatal("live-owned user.lua was adopted into the overlay; it must stay live-only")
	}
	ueWantFile(t, filepath.Join(cfg, "hypr/user.lua"), "-- my hypr\n")

	if r := reconcileUserEdits(false); r.status != recOK {
		t.Fatalf("idempotent: status=%s, want ok", r.status.label())
	}
}

// A box upgraded from the retired adopt step has a stale overlay copy that used
// to clobber the live file every update. The reconciler moves it back out
// without losing data, whatever the live file's state.
func TestReconcileUserEditsRetiresStaleOverlayCopy(t *testing.T) {
	ueSetup(t)
	cfg := sys.ConfigHome()
	edits := sys.UserEditsDir()
	ueWrite(t, filepath.Join(edits, "README.md"), "guide\n") // guide already present

	// identical live+overlay: drop the dead duplicate, keep the live file.
	ueWrite(t, filepath.Join(cfg, "hypr/user.lua"), "-- same\n")
	ueWrite(t, filepath.Join(edits, "hypr/user.lua"), "-- same\n")
	// diverged: the live file has the real edits, the overlay a stale snapshot.
	ueWrite(t, filepath.Join(cfg, "kitty/user.conf"), "font_size 14\n")
	ueWrite(t, filepath.Join(edits, "kitty/user.conf"), "font_size 12\n")
	// live missing: restore the overlay copy to its live home.
	ueWrite(t, filepath.Join(edits, "hypr/monitors_user.lua"), "-- pins\n")

	if r := reconcileUserEdits(true); r.status != recWouldFix {
		t.Fatalf("stale check: status=%s, want todo", r.status.label())
	}
	if r := reconcileUserEdits(false); r.status != recFixed {
		t.Fatalf("stale fix: status=%s detail=%q, want fixed", r.status.label(), r.detail)
	}

	for _, rel := range sys.LiveOwnedConfig {
		if sys.Exists(filepath.Join(edits, rel)) {
			t.Fatalf("overlay still carries %s", rel)
		}
	}
	// identical: live kept, no backup.
	ueWantFile(t, filepath.Join(cfg, "hypr/user.lua"), "-- same\n")
	if sys.Exists(filepath.Join(cfg, "hypr/user.lua.overlay.bak")) {
		t.Fatal("identical case must not leave a backup")
	}
	// diverged: live untouched, overlay snapshot preserved beside it.
	ueWantFile(t, filepath.Join(cfg, "kitty/user.conf"), "font_size 14\n")
	ueWantFile(t, filepath.Join(cfg, "kitty/user.conf.overlay.bak"), "font_size 12\n")
	// live missing: restored from the overlay copy.
	ueWantFile(t, filepath.Join(cfg, "hypr/monitors_user.lua"), "-- pins\n")

	if r := reconcileUserEdits(false); r.status != recOK {
		t.Fatalf("idempotent: status=%s, want ok", r.status.label())
	}
}
