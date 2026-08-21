package doctor

import (
	"os"
	"strings"
	"testing"
)

// stubSpicetifyTarget swaps the writability probe, restoring it when the test
// ends. Hermetic: no spicetify binary is run and no client tree is read.
func stubSpicetifyTarget(t *testing.T, path string, writable bool) {
	t.Helper()
	ow, oi, oc, op := spicetifyClientWritable, spotifyInstalled, spicetifyCanvasSource, spotifyLauncherPending
	occ, oe := spicetifyCliPresent, spicetifyExtensionEnabled
	t.Cleanup(func() {
		spicetifyClientWritable, spotifyInstalled, spicetifyCanvasSource = ow, oi, oc
		spotifyLauncherPending, spicetifyCliPresent = op, occ
		spicetifyExtensionEnabled = oe
	})
	// A client is present, its download is done, the CLI exists and the shipped
	// asset resolves, so the run reaches the writability gate deterministically.
	spotifyInstalled = func() bool { return true }
	spotifyLauncherPending = func() bool { return false }
	spicetifyCliPresent = func() bool { return true }
	// Satisfy ALL THREE of the old ok-path conditions: the CLI exists, the
	// extension file matches byte for byte, and the config lists it. Without the
	// writability gate this exact state returned ok, so the assertions below are
	// what fail if the gate is ever removed.
	spicetifyExtensionEnabled = func() bool { return true }
	cfg := t.TempDir()
	t.Setenv("XDG_CONFIG_HOME", cfg)
	src := canvasFixture(t)
	dst := cfg + "/spicetify/Extensions/ryoku-canvas.js"
	if err := os.MkdirAll(cfg+"/spicetify/Extensions", 0o755); err != nil {
		t.Fatalf("fixture dirs: %v", err)
	}
	b, err := os.ReadFile(src)
	if err != nil {
		t.Fatalf("fixture read: %v", err)
	}
	if err := os.WriteFile(dst, b, 0o644); err != nil {
		t.Fatalf("fixture place: %v", err)
	}
	spicetifyCanvasSource = func() string { return src }
	spicetifyClientWritable = func() (string, bool) { return path, writable }
}

// canvasFixture is a stand-in for the shipped ryoku-canvas.js, so the reconciler
// gets past its asset check without depending on the checkout's layout.
func canvasFixture(t *testing.T) string {
	t.Helper()
	f := t.TempDir() + "/ryoku-canvas.js"
	if err := os.WriteFile(f, []byte("// fixture\n"), 0o644); err != nil {
		t.Fatalf("fixture: %v", err)
	}
	return f
}

// REGRESSION. The ok path used to report "installed, enabled, and applied"
// whenever three things were true: the CLI existed, the extension file matched,
// and the config listed it. None of those says the Spotify client was ever
// patched, so on a flatpak client (root-owned /var/lib/flatpak) or a native
// /opt client, `spicetify apply` failed with EACCES on Apps/login.spa while
// doctor printed a green tick over an unpatched client. That is precisely the
// state a user reports as "spicetify is broken", and a green tick is worse than
// a warning because it sends them looking somewhere else.
//
// An unwritable client tree must therefore never report ok, and the remedy must
// name the shipped client whose tree is writable.
func TestSpicetifyUnwritableClientIsNotReportedOk(t *testing.T) {
	stubSpicetifyTarget(t, "/var/lib/flatpak/app/com.spotify.Client/files/extra/share/spotify", false)

	got := reconcileSpicetifyCanvas(true)
	if got.status == recOK {
		t.Fatalf("an unwritable client reported ok: %q", got.detail)
	}
	if !strings.Contains(got.detail, "not writable") {
		t.Errorf("detail should name the unwritable tree, got: %q", got.detail)
	}
	if !strings.Contains(got.remedy, "spotify-launcher") {
		t.Errorf("remedy should point at the shipped per-user client, got: %q", got.remedy)
	}
}

// The gate must not fire when the tree IS writable, which is the spotify-launcher
// shape Ryoku ships: a per-user tree that needs no root to patch.
func TestSpicetifyWritableClientPassesTheGate(t *testing.T) {
	stubSpicetifyTarget(t, t.TempDir(), true)

	got := reconcileSpicetifyCanvas(true)
	if strings.Contains(got.detail, "not writable") {
		t.Errorf("a writable tree must not trip the writability gate, got: %q", got.detail)
	}
}

// A path the probe cannot resolve must not invent a problem: an unknown target
// reports writable, so doctor stays quiet instead of warning about a tree it
// never saw.
func TestSpicetifyUnknownTargetDoesNotWarn(t *testing.T) {
	stubSpicetifyTarget(t, "", true)

	got := reconcileSpicetifyCanvas(true)
	if strings.Contains(got.detail, "not writable") {
		t.Errorf("an unresolvable target must not be reported as unwritable, got: %q", got.detail)
	}
}
