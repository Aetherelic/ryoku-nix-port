package doctor

import (
	"os"
	"path/filepath"
	"testing"
	"time"
)

// kmHome writes a settings.lua carrying the given kb_layout and points
// configHome at it.
func kmHome(t *testing.T, layout string) {
	t.Helper()
	home := t.TempDir()
	t.Setenv("HOME", home)
	t.Setenv("XDG_CONFIG_HOME", filepath.Join(home, ".config"))
	dir := filepath.Join(home, ".config", "hypr")
	if err := os.MkdirAll(dir, 0o755); err != nil {
		t.Fatal(err)
	}
	body := `settings = {
  input = { kb_layout = "` + layout + `", kb_variant = "", follow_mouse = 1 },
}`
	if err := os.WriteFile(filepath.Join(dir, "settings.lua"), []byte(body), 0o644); err != nil {
		t.Fatal(err)
	}
}

// The primary layout is what a login screen needs; a second layout rides along
// in the same string and must not leak into the comparison.
func TestKeymapReadsPrimaryLayout(t *testing.T) {
	kmHome(t, "fr,us")
	if got := hyprLayout(); got != "fr" {
		t.Errorf("hyprLayout() = %q, want fr", got)
	}
}

func TestKeymapNoLayoutRecorded(t *testing.T) {
	home := t.TempDir()
	t.Setenv("HOME", home)
	t.Setenv("XDG_CONFIG_HOME", filepath.Join(home, ".config"))
	if got := reconcileKeymap(true); got.status != recOK {
		t.Errorf("a box with no settings.lua should be ok, got %v (%s)", got.status, got.detail)
	}
}

// A boot image older than /etc/vconsole.conf means the passphrase prompt still
// carries the keymap baked in when it was built. That is the LUKS trap: it has
// to be reported even when every file under /etc already agrees, which is
// exactly the case a plain config comparison misses.
func TestKeymapBootImageTimePicksNewestNonFallback(t *testing.T) {
	dir := t.TempDir()
	old := filepath.Join(dir, "ryoku_linux.efi")
	newer := filepath.Join(dir, "ryoku_linux-cachyos.efi")
	fallback := filepath.Join(dir, "initramfs-linux-fallback.img")
	for _, f := range []string{old, newer, fallback} {
		if err := os.WriteFile(f, []byte("img"), 0o644); err != nil {
			t.Fatal(err)
		}
	}
	base := time.Now().Add(-2 * time.Hour)
	mustTouch(t, old, base)
	mustTouch(t, newer, base.Add(30*time.Minute))
	// a fallback image is regenerated on its own schedule and must never be the
	// one the freshness check trusts
	mustTouch(t, fallback, base.Add(90*time.Minute))

	orig := bootImageGlobs
	bootImageGlobs = []string{filepath.Join(dir, "*.efi"), filepath.Join(dir, "initramfs-*.img")}
	t.Cleanup(func() { bootImageGlobs = orig })

	when, which := bootImageTime()
	if filepath.Base(which) != "ryoku_linux-cachyos.efi" {
		t.Errorf("picked %q, want the newest non-fallback image", filepath.Base(which))
	}
	if !when.Equal(base.Add(30 * time.Minute)) {
		t.Errorf("time = %v, want the newest non-fallback mtime", when)
	}
}

func mustTouch(t *testing.T, path string, when time.Time) {
	t.Helper()
	if err := os.Chtimes(path, when, when); err != nil {
		t.Fatal(err)
	}
}
