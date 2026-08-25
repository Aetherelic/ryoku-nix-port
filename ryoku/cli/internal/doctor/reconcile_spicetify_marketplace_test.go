package doctor

import (
	"os"
	"strings"
	"testing"
)

// stubMarketplaceTarget arranges the marketplace reconciler to reach its
// writability gate deterministically, then swaps the writability probe. Hermetic:
// no spicetify binary is run (the tests call the check pass, checkOnly=true, which
// skips the mutating spicetify calls) and no real client tree is read.
func stubMarketplaceTarget(t *testing.T, path string, writable bool) {
	t.Helper()
	ow, oi, op := spicetifyClientWritable, spotifyInstalled, spotifyLauncherPending
	occ, oul := spicetifyCliPresent, spotifyLauncherUnlaunched
	osrc, ocol, oen := spicetifyMarketplaceSource, spicetifyMarketplaceColor, spicetifyCustomAppEnabled
	t.Cleanup(func() {
		spicetifyClientWritable, spotifyInstalled, spotifyLauncherPending = ow, oi, op
		spicetifyCliPresent, spotifyLauncherUnlaunched = occ, oul
		spicetifyMarketplaceSource, spicetifyMarketplaceColor, spicetifyCustomAppEnabled = osrc, ocol, oen
	})
	// A client is present, its download is done, the CLI exists, the shipped app
	// resolves and is already listed, so the run reaches the writability gate.
	spotifyInstalled = func() bool { return true }
	spotifyLauncherPending = func() bool { return false }
	spotifyLauncherUnlaunched = func() bool { return false }
	spicetifyCliPresent = func() bool { return true }
	spicetifyCustomAppEnabled = func(string) bool { return true }
	spicetifyMarketplaceColor = func() string { return "" } // no theme fiddling in the gate tests

	cfg := t.TempDir()
	t.Setenv("XDG_CONFIG_HOME", cfg)

	// shipped app dir with a manifest; place an identical installed manifest so
	// needPlace is false and the decision reaches the gate (mirrors the Canvas test).
	srcDir := t.TempDir()
	if err := os.WriteFile(srcDir+"/manifest.json", []byte(`{"name":"marketplace"}`), 0o644); err != nil {
		t.Fatalf("fixture manifest: %v", err)
	}
	spicetifyMarketplaceSource = func() string { return srcDir }

	dstDir := cfg + "/spicetify/CustomApps/marketplace"
	if err := os.MkdirAll(dstDir, 0o755); err != nil {
		t.Fatalf("fixture dirs: %v", err)
	}
	b, err := os.ReadFile(srcDir + "/manifest.json")
	if err != nil {
		t.Fatalf("read fixture: %v", err)
	}
	if err := os.WriteFile(dstDir+"/manifest.json", b, 0o644); err != nil {
		t.Fatalf("place manifest: %v", err)
	}

	spicetifyClientWritable = func() (string, bool) { return path, writable }
}

// An unwritable client (root-owned flatpak/native) must never report ok, and the
// remedy must name the shipped per-user client -- same contract as the Canvas one,
// so the Marketplace never claims a green tick over a client it could not patch.
func TestMarketplaceUnwritableClientIsNotReportedOk(t *testing.T) {
	stubMarketplaceTarget(t, "/var/lib/flatpak/app/com.spotify.Client/files/extra/share/spotify", false)

	got := reconcileSpicetifyMarketplace(true)
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

// A writable tree (the spotify-launcher shape) passes the gate and, with the app
// already placed and listed, reports installed/applied.
func TestMarketplaceWritableClientPassesTheGate(t *testing.T) {
	stubMarketplaceTarget(t, t.TempDir(), true)

	got := reconcileSpicetifyMarketplace(true)
	if strings.Contains(got.detail, "not writable") {
		t.Errorf("a writable tree must not trip the writability gate, got: %q", got.detail)
	}
	if got.status != recOK {
		t.Fatalf("an installed, enabled, writable Marketplace should report ok, got %v: %q", got.status, got.detail)
	}
}

// An unresolvable target must not invent a problem.
func TestMarketplaceUnknownTargetDoesNotWarn(t *testing.T) {
	stubMarketplaceTarget(t, "", true)

	got := reconcileSpicetifyMarketplace(true)
	if strings.Contains(got.detail, "not writable") {
		t.Errorf("an unresolvable target must not be reported as unwritable, got: %q", got.detail)
	}
}

// An unwritable current client with the shipped launcher not yet launched must
// DEFER (ok), not warn about a client that is already on the way.
func TestMarketplaceDefersWhenLauncherUnlaunched(t *testing.T) {
	stubMarketplaceTarget(t, "/var/lib/flatpak/app/com.spotify.Client/files/extra/share/spotify", false)
	spotifyLauncherUnlaunched = func() bool { return true }

	got := reconcileSpicetifyMarketplace(true)
	if got.status != recOK {
		t.Fatalf("unwritable client with spotify-launcher pending must defer (ok), got %v: %q", got.status, got.detail)
	}
	if !strings.Contains(got.detail, "first launch") {
		t.Errorf("detail should say the Marketplace wires up after first launch, got: %q", got.detail)
	}
}

// No Spotify at all: the store is not needed, and the reconciler stays quiet
// (inert) rather than warning.
func TestMarketplaceNoSpotifyIsInert(t *testing.T) {
	stubMarketplaceTarget(t, t.TempDir(), true)
	spotifyInstalled = func() bool { return false }

	got := reconcileSpicetifyMarketplace(false)
	if got.status != recOK {
		t.Fatalf("no Spotify must be ok/inert, got %v: %q", got.status, got.detail)
	}
	if !strings.Contains(got.detail, "not needed") {
		t.Errorf("detail should say the store is not needed, got: %q", got.detail)
	}
}

// The app asset has not shipped yet (package not built/installed): defer quietly
// until it arrives on a package update, never warn.
func TestMarketplaceAssetAbsentDefers(t *testing.T) {
	stubMarketplaceTarget(t, t.TempDir(), true)
	spicetifyMarketplaceSource = func() string { return "" }

	got := reconcileSpicetifyMarketplace(true)
	if got.status != recOK {
		t.Fatalf("a missing app asset must defer (ok), got %v: %q", got.status, got.detail)
	}
	if !strings.Contains(got.detail, "package update") {
		t.Errorf("detail should say it arrives on the package update, got: %q", got.detail)
	}
}
