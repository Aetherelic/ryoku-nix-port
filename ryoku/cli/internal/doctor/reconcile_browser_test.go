package doctor

import (
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func browserMkdir(t *testing.T, p string) {
	t.Helper()
	if err := os.MkdirAll(p, 0o755); err != nil {
		t.Fatal(err)
	}
}

func browserReadManifest(t *testing.T, p string) map[string]any {
	t.Helper()
	b, err := os.ReadFile(p)
	if err != nil {
		t.Fatalf("read %s: %v", p, err)
	}
	var m map[string]any
	if err := json.Unmarshal(b, &m); err != nil {
		t.Fatalf("json %s: %v", p, err)
	}
	return m
}

// TestReconcileBrowserTheme covers the guard (no browser -> no-op), the install
// (launcher + per-engine manifest), idempotency (a second run reports ok), and
// check-only (reports without writing).
func TestReconcileBrowserTheme(t *testing.T) {
	home := t.TempDir()
	t.Setenv("HOME", home)
	t.Setenv("XDG_DATA_HOME", filepath.Join(home, ".local", "share"))
	t.Setenv("XDG_CONFIG_HOME", "") // browser roots key off $HOME/.config directly

	if r := reconcileBrowserTheme(false); r.status != recOK {
		t.Fatalf("no browser: status=%s want ok", r.status.label())
	}

	browserMkdir(t, filepath.Join(home, ".mozilla"))
	browserMkdir(t, filepath.Join(home, ".config", "chromium"))

	r := reconcileBrowserTheme(false)
	if r.status != recFixed {
		t.Fatalf("first run: status=%s want fixed", r.status.label())
	}

	launcher := filepath.Join(home, ".local", "share", "ryoku", "ryoku-browser-host")
	body, err := os.ReadFile(launcher)
	if err != nil {
		t.Fatalf("launcher missing: %v", err)
	}
	if !strings.Contains(string(body), "browser-host") {
		t.Fatalf("launcher body missing exec line: %q", body)
	}

	ff := browserReadManifest(t, filepath.Join(home, ".mozilla", "native-messaging-hosts", "ryoku_theme.json"))
	if ff["name"] != browserHostName || ff["path"] != launcher {
		t.Fatalf("firefox manifest wrong: %v", ff)
	}
	if _, ok := ff["allowed_extensions"]; !ok {
		t.Fatalf("firefox manifest missing allowed_extensions: %v", ff)
	}

	cr := browserReadManifest(t, filepath.Join(home, ".config", "chromium", "NativeMessagingHosts", "ryoku_theme.json"))
	origins, ok := cr["allowed_origins"].([]any)
	if !ok || len(origins) == 0 || !strings.Contains(origins[0].(string), browserChromiumID) {
		t.Fatalf("chromium manifest origins wrong: %v", cr)
	}

	if r2 := reconcileBrowserTheme(false); r2.status != recOK {
		t.Fatalf("second run: status=%s want ok (idempotent)", r2.status.label())
	}

	// A removed manifest is reported by check-only without being rewritten.
	ffPath := filepath.Join(home, ".mozilla", "native-messaging-hosts", "ryoku_theme.json")
	if err := os.Remove(ffPath); err != nil {
		t.Fatal(err)
	}
	if r3 := reconcileBrowserTheme(true); r3.status != recWouldFix {
		t.Fatalf("check-only: status=%s want todo", r3.status.label())
	}
	if _, err := os.Stat(ffPath); err == nil {
		t.Fatalf("check-only must not rewrite the manifest")
	}
}
