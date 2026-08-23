package doctor

import (
	"bytes"
	"context"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"syscall"
	"time"

	"ryoku-cli/internal/sys"
)

// reconcileSpicetifyCanvas wires the Ryoku Canvas spicetify extension for a user
// who runs Spotify, so the desktop music widget's "Spotify Canvas" backdrop works
// out of the box. Spotify's Canvas token is bot-gated, so the shell daemon cannot
// fetch it (ipc/music.go); the extension runs inside the spicetified client, where
// a valid session token exists, and relays the Canvas URL to the daemon's loopback
// endpoint (ryoku/apps/spicetify/ryoku-canvas.js).
//
// Gated on Spotify being installed -- nothing to spicetify otherwise. Every
// spicetify step is best-effort and bounded: a missing AUR helper, an unwritable
// Spotify install (root-owned /opt/spotify), a flatpak client spicetify cannot
// reach, or a Spotify update that invalidated the patch all degrade to a warning
// and NEVER block `ryoku update`. Idempotent: the extension is (re)placed, enabled
// and applied only when it is missing, stale, or not yet enabled.
func reconcileSpicetifyCanvas(checkOnly bool) recResult {
	if !spotifyInstalled() {
		return okRes("no Spotify installed; the Canvas spicetify setup is not needed")
	}
	if spotifyLauncherPending() {
		return okRes("Spotify (spotify-launcher) is not downloaded yet; the Canvas wires up after its first launch")
	}
	src := spicetifyCanvasSource()
	if src == "" {
		return okRes("Canvas extension asset not present yet (ships with ryoku-desktop; arrives on the package update)")
	}
	extDir := filepath.Join(sys.ConfigHome(), "spicetify", "Extensions")
	dst := filepath.Join(extDir, "ryoku-canvas.js")

	needCli := !spicetifyCliPresent()
	needPlace := !sameBytes(src, dst)
	needEnable := !needCli && !spicetifyExtensionEnabled()

	// The patch has to be VERIFIED, not inferred. Until this check the ok path
	// below reported "installed, enabled, and applied" whenever the CLI existed,
	// the extension file matched and the config listed it, none of which says the
	// Spotify client was ever patched. On a flatpak or a root-owned /opt client
	// `spicetify apply` fails with EACCES on Apps/login.spa, so doctor was
	// reporting a green tick over an unpatched client: exactly the state a user
	// then reports as "spicetify is broken".
	if !needCli {
		// Aim spicetify at the per-user spotify-launcher tree (writable) before
		// judging writability: spicetify auto-detects a root-owned flatpak or /opt
		// client but not the launcher path, so without this it flags the
		// unpatchable client even when Ryoku's writable one is right there. Mutates
		// only in apply mode; the check pass reads the current target.
		if !checkOnly {
			spicetifyPointAtLauncher()
		}
		if path, ok := spicetifyClientWritable(); !ok {
			// spotify-launcher is the writable client Ryoku ships. Installed but
			// not launched yet -> its tree is not unpacked, so the Canvas wires up
			// after first launch; defer rather than warn about (and tell the user
			// to install) a client that is already there.
			if spotifyLauncherUnlaunched() {
				return okRes("Spotify (spotify-launcher) is not launched yet; the Canvas wires up after its first launch (the %s client cannot be patched)", path)
			}
			return warnRes("the Spotify client at %s is not writable, so spicetify cannot patch it", path).
				withFix("install the shipped client instead (`sudo pacman -S --needed spotify-launcher`), which unpacks a per-user tree spicetify can patch without root; a native /opt client needs `sudo chmod a+wr -R /opt/spotify /opt/spotify/Apps`")
		}
	}
	if !needCli && !needPlace && !needEnable {
		return okRes("Ryoku Canvas spicetify extension is installed, enabled, and applied")
	}
	if checkOnly {
		var todo []string
		if needCli {
			todo = append(todo, "install spicetify-cli")
		}
		if needPlace {
			todo = append(todo, "place the Ryoku Canvas extension")
		}
		if needEnable {
			todo = append(todo, "enable + apply it")
		}
		return wouldRes("Spotify is installed but the Ryoku Canvas setup is incomplete: %s", strings.Join(todo, ", ")).
			withFix("ryoku doctor")
	}

	var did []string
	if needCli {
		if !installSpicetifyCli() {
			return warnRes("Spotify is installed but spicetify-cli is missing and could not be installed").
				withFix("install it by hand (`sudo pacman -S spicetify-cli`, it ships in [ryoku]), then run `ryoku doctor`")
		}
		did = append(did, "installed spicetify-cli")
	}
	if err := os.MkdirAll(extDir, 0o755); err != nil {
		return warnRes("could not create %s: %v", extDir, err)
	}
	if err := sys.CopyFile(src, dst); err != nil {
		return warnRes("could not place the Ryoku Canvas extension at %s: %v", dst, err).
			withFix("copy %s to %s by hand", src, dst)
	}
	did = append(did, "placed the Ryoku Canvas extension")
	if !spicetifyExtensionEnabled() {
		_ = spicetifyRun(60*time.Second, "config", "extensions", "ryoku-canvas.js")
	}
	spicetifyPointAtLauncher()
	if err := spicetifyApply(); err != nil {
		return warnRes("the Ryoku Canvas extension is in place and enabled, but `spicetify apply` did not complete: %v", err).
			withFix("run `spicetify backup apply` once (a native /opt/spotify needs write access first: sudo chmod a+wr -R /opt/spotify /opt/spotify/Apps)")
	}
	did = append(did, "applied it to Spotify")
	return fixedRes("Ryoku Canvas: %s", strings.Join(did, ", "))
}

// spotifyInstalled reports whether any Spotify client is present: the native
// package, the launcher, or the flatpak.
// Seams, so the decision table above is testable without a Spotify client, a
// spicetify binary, or a real client tree.
var spicetifyCliPresent = func() bool { return sys.Has("spicetify") }

var spotifyInstalled = func() bool {
	if sys.PkgInstalled("spotify") || sys.PkgInstalled("spotify-launcher") {
		return true
	}
	if sys.Has("flatpak") && exec.Command("flatpak", "info", "com.spotify.Client").Run() == nil {
		return true
	}
	return false
}

// spicetifyCanvasSource is the shipped ryoku-canvas.js: the package asset, else
// the checkout on a dev box.
var spicetifyCanvasSource = func() string {
	cands := []string{"/usr/share/ryoku/spicetify/ryoku-canvas.js"}
	if repo := sys.ResolveRepo(); repo != "" {
		cands = append(cands, filepath.Join(repo, "ryoku", "apps", "spicetify", "ryoku-canvas.js"))
	}
	for _, p := range cands {
		if sys.Exists(p) {
			return p
		}
	}
	return ""
}

// spicetifyExtensionEnabled reports whether ryoku-canvas.js is already in the
// spicetify extensions list, so enabling stays idempotent (the config verb
// appends, so a blind re-run would duplicate it).
var spicetifyExtensionEnabled = func() bool {
	out, err := sys.RunOut("spicetify", "config", "extensions")
	if err != nil {
		return false
	}
	return strings.Contains(out, "ryoku-canvas.js")
}

// installSpicetifyCli installs spicetify-cli, bounded. It is a [ryoku] repo
// package now (release/packages/spicetify-cli), so pacman is the real path and
// the AUR helpers are only a fallback for a box whose mirror list predates the
// package. That ordering matters: pacman works on a machine with no AUR helper
// at all, which is every offline install, and it is what makes this reachable
// from `ryoku update` instead of only from a manual `yay -S`.
func installSpicetifyCli() bool {
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Minute)
	err := exec.CommandContext(ctx, "sudo", "pacman", "-S", "--needed", "--noconfirm", "spicetify-cli").Run()
	cancel()
	if err == nil && sys.Has("spicetify") {
		return true
	}
	for _, helper := range []string{"yay", "paru"} {
		if !sys.Has(helper) {
			continue
		}
		hctx, hcancel := context.WithTimeout(context.Background(), 5*time.Minute)
		herr := exec.CommandContext(hctx, helper, "-S", "--needed", "--noconfirm", "spicetify-cli").Run()
		hcancel()
		if herr == nil && sys.Has("spicetify") {
			return true
		}
	}
	return false
}

func spicetifyRun(timeout time.Duration, args ...string) error {
	ctx, cancel := context.WithTimeout(context.Background(), timeout)
	defer cancel()
	return exec.CommandContext(ctx, "spicetify", args...).Run()
}

// spicetifyOut is spicetifyRun with the output captured, for the config reads
// that have to be inspected rather than merely succeed.
func spicetifyOut(timeout time.Duration, args ...string) (string, error) {
	ctx, cancel := context.WithTimeout(context.Background(), timeout)
	defer cancel()
	out, err := exec.CommandContext(ctx, "spicetify", args...).Output()
	return string(out), err
}

// spicetifyApply patches the Spotify client. A first-ever run needs `backup
// apply` to seed spicetify's backup; a later run is a plain `apply`. Both are
// bounded so a wedge cannot stall an update, and the caller treats any failure as
// advisory.
func spicetifyApply() error {
	if err := spicetifyRun(90*time.Second, "apply"); err == nil {
		return nil
	}
	return spicetifyRun(120*time.Second, "backup", "apply")
}

// spotifyLauncherDir is the per-user Spotify tree a spotify-launcher install
// unpacks under $XDG_DATA_HOME on first launch.
func spotifyLauncherDir() string {
	data := os.Getenv("XDG_DATA_HOME")
	if data == "" {
		data = filepath.Join(os.Getenv("HOME"), ".local", "share")
	}
	return filepath.Join(data, "spotify-launcher", "install", "usr", "share", "spotify")
}

// spotifyLauncherPending: spotify-launcher is installed but has not downloaded its
// client yet (first launch pending) and no other client is present, so there is
// nothing to spicetify. The setup defers quietly instead of warning on every fresh
// box until the user first opens Spotify.
var spotifyLauncherPending = func() bool {
	if !sys.PkgInstalled("spotify-launcher") {
		return false
	}
	if sys.PkgInstalled("spotify") || sys.Exists("/opt/spotify") {
		return false
	}
	if sys.Has("flatpak") && exec.Command("flatpak", "info", "com.spotify.Client").Run() == nil {
		return false
	}
	return !sys.Exists(spotifyLauncherDir())
}

// spotifyLauncherUnlaunched: the shipped spotify-launcher is installed but its
// per-user client tree is not unpacked yet, regardless of any other client. When
// the only patchable client is a root-owned flatpak/native one, the Canvas setup
// defers to the launcher instead of misreporting a client that is already there.
var spotifyLauncherUnlaunched = func() bool {
	return sys.PkgInstalled("spotify-launcher") && !sys.Exists(spotifyLauncherDir())
}

// spicetifyPointAtLauncher aims spicetify at a spotify-launcher install, which
// lives per-user under $XDG_DATA_HOME (not root-owned /opt), so `apply` needs no
// root. spicetify does not auto-detect that path, so set it when it exists; a
// no-op for /opt or flatpak clients, which spicetify finds itself. Best-effort.
func spicetifyPointAtLauncher() {
	if dir := spotifyLauncherDir(); sys.Exists(dir) {
		_ = spicetifyRun(30*time.Second, "config", "spotify_path", dir)
	}
}

// spicetifyClientWritable asks spicetify which client tree it is aimed at and
// whether this user can write it. That is the difference between a patch that
// can be applied and kept, and one that fails on every run: a flatpak client
// lives under root-owned /var/lib/flatpak and a native package under root-owned
// /opt, while spotify-launcher unpacks under the user's own XDG data dir.
//
// An unknown path returns writable, because a check that cannot see the target
// must not invent a problem. The bool is the answer; the string is the path to
// name in the message.
var spicetifyClientWritable = func() (string, bool) {
	out, err := spicetifyOut(10*time.Second, "config", "spotify_path")
	if err != nil {
		return "", true
	}
	// spicetify prints its banner first; the path is the last non-empty line.
	path := ""
	for _, line := range strings.Split(out, "\n") {
		if s := strings.TrimSpace(line); s != "" {
			path = s
		}
	}
	if path == "" || !sys.Exists(path) {
		return path, true
	}
	// W_OK on the directory spicetify writes into. Cheap, and it does not
	// mutate the tree the way a probe file would.
	return path, syscall.Access(path, 2) == nil
}

// sameBytes reports whether both paths exist with identical contents.
func sameBytes(a, b string) bool {
	ba, err := os.ReadFile(a)
	if err != nil {
		return false
	}
	bb, err := os.ReadFile(b)
	if err != nil {
		return false
	}
	return bytes.Equal(ba, bb)
}
