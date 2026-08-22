package doctor

import (
	"encoding/json"
	"os"
	"path/filepath"

	"ryoku-cli/internal/sys"
)

// The WebExtension native-messaging host name and the extension ids that may
// talk to it. The Chromium id is fixed by the "key" in manifest.chromium.json.
const (
	browserHostName   = "ryoku_theme"
	browserFirefoxExt = "ryoku-theme@ryoku.arch"
	browserChromiumID = "mcmfbdeecgccbnlekdmalihgmpbplcij"
)

// reconcileBrowserTheme installs the native-messaging host so the Ryoku browser
// extension can reach the palette daemon. It writes a small launcher (execs
// `ryoku-shell browser-host`) and a host manifest into every browser profile
// root that exists. No-op when no supported browser is present; idempotent, and
// it never touches a browser's own settings.
func reconcileBrowserTheme(checkOnly bool) recResult {
	home := os.Getenv("HOME")
	if home == "" {
		return okRes("no HOME")
	}
	launcher := filepath.Join(dataHome(), "ryoku", "ryoku-browser-host")

	// Firefox family keys on allowed_extensions; Chromium on allowed_origins.
	ffManifest := map[string]any{
		"name": browserHostName, "description": "Ryoku palette host",
		"path": launcher, "type": "stdio",
		"allowed_extensions": []string{browserFirefoxExt},
	}
	crManifest := map[string]any{
		"name": browserHostName, "description": "Ryoku palette host",
		"path": launcher, "type": "stdio",
		"allowed_origins": []string{"chrome-extension://" + browserChromiumID + "/"},
	}

	// browser profile root -> native-messaging dir + which manifest it takes.
	type target struct {
		root, dir string
		manifest  map[string]any
	}
	targets := []target{
		{".mozilla", "native-messaging-hosts", ffManifest},
		{".librewolf", "native-messaging-hosts", ffManifest},
		{".zen", "native-messaging-hosts", ffManifest},
		{".config/chromium", "NativeMessagingHosts", crManifest},
		{".config/google-chrome", "NativeMessagingHosts", crManifest},
		{".config/BraveSoftware/Brave-Browser", "NativeMessagingHosts", crManifest},
		{".config/microsoft-edge", "NativeMessagingHosts", crManifest},
		{".config/vivaldi", "NativeMessagingHosts", crManifest},
	}

	var pending, did []string
	present := false
	for _, t := range targets {
		root := filepath.Join(home, t.root)
		if !sys.Exists(root) {
			continue
		}
		present = true
		manifestPath := filepath.Join(root, t.dir, browserHostName+".json")
		if manifestCurrent(manifestPath, t.manifest, launcher) {
			continue
		}
		if checkOnly {
			pending = append(pending, "install host for "+t.root)
			continue
		}
		if err := writeLauncher(launcher); err != nil {
			return failRes("could not write the browser host launcher: %v", err)
		}
		if err := writeJSON(manifestPath, t.manifest); err != nil {
			return failRes("could not install the host manifest for %s: %v", t.root, err)
		}
		did = append(did, t.root)
	}

	switch {
	case !present:
		return okRes("no supported browser present")
	case checkOnly && len(pending) > 0:
		return wouldRes("install the Ryoku browser host")
	case len(did) > 0:
		return fixedRes("installed the browser host for: %v", did)
	default:
		return okRes("browser host installed")
	}
}

func dataHome() string {
	if d := os.Getenv("XDG_DATA_HOME"); d != "" {
		return d
	}
	return filepath.Join(os.Getenv("HOME"), ".local", "share")
}

// manifestCurrent reports whether the host manifest already exists with our
// launcher path, so a run that changes nothing stays a no-op.
func manifestCurrent(path string, want map[string]any, launcher string) bool {
	b, err := os.ReadFile(path)
	if err != nil {
		return false
	}
	var got map[string]any
	if json.Unmarshal(b, &got) != nil {
		return false
	}
	return got["path"] == launcher && got["name"] == want["name"]
}

func writeLauncher(path string) error {
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		return err
	}
	body := "#!/bin/sh\nexec ryoku-shell browser-host \"$@\"\n"
	return os.WriteFile(path, []byte(body), 0o755)
}

func writeJSON(path string, v map[string]any) error {
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		return err
	}
	b, err := json.MarshalIndent(v, "", "  ")
	if err != nil {
		return err
	}
	return os.WriteFile(path, b, 0o644)
}
