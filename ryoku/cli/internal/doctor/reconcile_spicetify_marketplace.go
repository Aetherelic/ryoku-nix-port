package doctor

import (
	"io/fs"
	"os"
	"path/filepath"
	"strings"
	"time"

	"ryoku-cli/internal/sys"
)

// reconcileSpicetifyMarketplace wires the Spicetify Marketplace -- the "store"
// icon in Spotify's sidebar that installs themes and extensions -- for a user who
// runs Spotify, so it is there out of the box. The manual install is fiddly (fetch
// a release zip, unzip into CustomApps, `spicetify config custom_apps marketplace`,
// apply, then hand-make a placeholder theme so theme installs land); this does all
// of it from the shipped app shell (spicetify-marketplace ->
// /usr/share/ryoku/spicetify/marketplace).
//
// Mirrors reconcileSpicetifyCanvas: gated on Spotify being installed, aimed at the
// per-user spotify-launcher tree so `apply` needs no root, and every step is
// best-effort and bounded -- an unwritable client, a missing CLI, or a Spotify
// update that invalidated the patch degrade to a warning and NEVER block
// `ryoku update`. Idempotent: the app is (re)placed, enabled and applied only when
// it is missing, stale (a Marketplace version bump), or not yet in custom_apps.
func reconcileSpicetifyMarketplace(checkOnly bool) recResult {
	if !spotifyInstalled() {
		return okRes("no Spotify installed; the Marketplace store is not needed")
	}
	if spotifyLauncherPending() {
		return okRes("Spotify (spotify-launcher) is not downloaded yet; the Marketplace wires up after its first launch")
	}
	src := spicetifyMarketplaceSource()
	if src == "" {
		return okRes("Marketplace app asset not present yet (ships with spicetify-marketplace; arrives on the package update)")
	}
	appDir := filepath.Join(sys.ConfigHome(), "spicetify", "CustomApps", "marketplace")

	needCli := !spicetifyCliPresent()
	// stale/missing detection keys on the shipped manifest vs the installed one:
	// a Marketplace version bump changes it, so the app is re-laid on the update.
	needPlace := !sameBytes(filepath.Join(src, "manifest.json"), filepath.Join(appDir, "manifest.json"))
	needEnable := !needCli && !spicetifyCustomAppEnabled("marketplace")

	// The patch has to be VERIFIED writable, not inferred -- same reason as the
	// Canvas reconciler: a flatpak (root-owned /var/lib/flatpak) or native /opt
	// client cannot be patched, and a green tick over one is the "spicetify is
	// broken" state a user then chases somewhere else.
	if !needCli {
		if !checkOnly {
			spicetifyPointAtLauncher()
		}
		if path, ok := spicetifyClientWritable(); !ok {
			if spotifyLauncherUnlaunched() {
				return okRes("Spotify (spotify-launcher) is not launched yet; the Marketplace wires up after its first launch (the %s client cannot be patched)", path)
			}
			return warnRes("the Spotify client at %s is not writable, so spicetify cannot install the Marketplace", path).
				withFix("install the shipped client instead (`sudo pacman -S --needed spotify-launcher`), which unpacks a per-user tree spicetify can patch without root; a native /opt client needs `sudo chmod a+wr -R /opt/spotify /opt/spotify/Apps`")
		}
	}
	if !needCli && !needPlace && !needEnable {
		return okRes("Spicetify Marketplace is installed, enabled, and applied")
	}
	if checkOnly {
		var todo []string
		if needCli {
			todo = append(todo, "install spicetify-cli")
		}
		if needPlace {
			todo = append(todo, "place the Marketplace app")
		}
		if needEnable {
			todo = append(todo, "enable + apply it")
		}
		return wouldRes("Spotify is installed but the Marketplace store is not set up: %s", strings.Join(todo, ", ")).
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
	if needPlace {
		if err := copyTree(src, appDir); err != nil {
			return warnRes("could not place the Marketplace app at %s: %v", appDir, err).
				withFix("copy %s to %s by hand", src, appDir)
		}
		did = append(did, "placed the Marketplace app")
	}
	// the transparent placeholder theme, so Marketplace can install themes; only
	// touches the theme slot when none is set, so it never clobbers a user's own.
	ensureMarketplaceTheme(sys.ConfigHome())
	if !spicetifyCustomAppEnabled("marketplace") {
		_ = spicetifyRun(60*time.Second, "config", "custom_apps", "marketplace")
		did = append(did, "enabled the Marketplace")
	}
	spicetifyPointAtLauncher()
	if err := spicetifyApply(); err != nil {
		return warnRes("the Marketplace app is in place, but `spicetify apply` did not complete: %v", err).
			withFix("run `spicetify backup apply` once (a native /opt/spotify needs write access first: sudo chmod a+wr -R /opt/spotify /opt/spotify/Apps)")
	}
	did = append(did, "applied it to Spotify")
	return fixedRes("Spicetify Marketplace: %s", strings.Join(did, ", "))
}

// spicetifyMarketplaceSource is the shipped Marketplace app dir (the package
// asset, else the checkout on a dev box), or "" until the package has landed.
var spicetifyMarketplaceSource = func() string {
	cands := []string{"/usr/share/ryoku/spicetify/marketplace"}
	if repo := sys.ResolveRepo(); repo != "" {
		cands = append(cands, filepath.Join(repo, "ryoku", "apps", "spicetify", "marketplace"))
	}
	for _, p := range cands {
		if sys.Exists(filepath.Join(p, "manifest.json")) {
			return p
		}
	}
	return ""
}

// spicetifyMarketplaceColor is the shipped transparent placeholder color.ini.
var spicetifyMarketplaceColor = func() string {
	p := "/usr/share/ryoku/spicetify/marketplace-color.ini"
	if sys.Exists(p) {
		return p
	}
	return ""
}

// spicetifyCustomAppEnabled reports whether a custom app is already in spicetify's
// pipe-separated custom_apps list, so enabling stays idempotent (the config verb
// appends, so a blind re-run would list it twice).
var spicetifyCustomAppEnabled = func(name string) bool {
	out, err := sys.RunOut("spicetify", "config", "custom_apps")
	if err != nil {
		return false
	}
	for _, f := range strings.Split(out, "|") {
		if strings.TrimSpace(f) == name {
			return true
		}
	}
	return false
}

// ensureMarketplaceTheme lays the transparent placeholder theme and points
// spicetify at it, but only when no real theme is set, so it enables theme
// installs without overriding a user's own theme. Best-effort throughout.
func ensureMarketplaceTheme(cfg string) {
	color := spicetifyMarketplaceColor()
	if color == "" {
		return
	}
	themeDir := filepath.Join(cfg, "spicetify", "Themes", "marketplace")
	if err := os.MkdirAll(themeDir, 0o755); err != nil {
		return
	}
	_ = sys.CopyFile(color, filepath.Join(themeDir, "color.ini"))
	_ = spicetifyRun(30*time.Second, "config", "inject_css", "1")
	_ = spicetifyRun(30*time.Second, "config", "replace_colors", "1")
	// claim the theme slot only when it is empty or already the placeholder; a
	// real theme name is left alone (Marketplace's own rule: <= 3 chars = none).
	cur, err := spicetifyOut(30*time.Second, "config", "current_theme")
	if err != nil {
		return
	}
	t := strings.TrimSpace(cur)
	if t == "" || t == "marketplace" || len(t) <= 3 {
		_ = spicetifyRun(30*time.Second, "config", "current_theme", "marketplace")
	}
}

// copyTree copies a directory recursively, replacing the destination so a stale
// file from an older Marketplace build never lingers.
func copyTree(src, dst string) error {
	if err := os.RemoveAll(dst); err != nil {
		return err
	}
	return filepath.WalkDir(src, func(p string, d fs.DirEntry, err error) error {
		if err != nil {
			return err
		}
		rel, err := filepath.Rel(src, p)
		if err != nil {
			return err
		}
		target := filepath.Join(dst, rel)
		if d.IsDir() {
			return os.MkdirAll(target, 0o755)
		}
		return sys.CopyFile(p, target)
	})
}
