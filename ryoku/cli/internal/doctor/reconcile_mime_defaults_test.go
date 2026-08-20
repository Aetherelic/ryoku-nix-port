package doctor

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

// shippedMap is what Ryoku lays in the vendor layer.
const shippedMap = `[Default Applications]
text/plain=ryoku-nvim.desktop
text/html=ryoku-nvim.desktop
video/mp4=mpv.desktop
`

// mimeSandbox points the reconciler at a temp home with a vendor map installed,
// so nothing on the real machine is read or written.
func mimeSandbox(t *testing.T, userFile string) (string, string) {
	t.Helper()
	dir := t.TempDir()
	cfg := filepath.Join(dir, "config")
	data := filepath.Join(dir, "data")
	vendor := filepath.Join(dir, "vendor")
	for _, p := range []string{cfg, filepath.Join(data, "applications"), filepath.Join(vendor, "applications")} {
		if err := os.MkdirAll(p, 0o755); err != nil {
			t.Fatal(err)
		}
	}
	t.Setenv("XDG_CONFIG_HOME", cfg)
	t.Setenv("XDG_DATA_HOME", data)
	t.Setenv("XDG_DATA_DIRS", vendor)
	if err := os.WriteFile(filepath.Join(vendor, "applications", "mimeapps.list"), []byte(shippedMap), 0o644); err != nil {
		t.Fatal(err)
	}
	path := filepath.Join(cfg, "mimeapps.list")
	if userFile != "" {
		if err := os.WriteFile(path, []byte(userFile), 0o644); err != nil {
			t.Fatal(err)
		}
	}
	return dir, path
}

func TestMimeDefaultsFrozenCopyIsRemoved(t *testing.T) {
	// the exact damage this fixes: an update had laid Ryoku's map into the
	// user's own file, so their choices were overwritten and Ryoku's later
	// changes could never reach them.
	_, path := mimeSandbox(t, shippedMap)

	if res := reconcileMimeDefaults(true); res.status != recWouldFix {
		t.Fatalf("check-only status = %v (%s)", res.status, res.detail)
	}
	if _, err := os.Stat(path); err != nil {
		t.Fatal("check-only must not touch the file")
	}

	res := reconcileMimeDefaults(false)
	if res.status != recFixed {
		t.Fatalf("status = %v (%s)", res.status, res.detail)
	}
	if _, err := os.Stat(path); !os.IsNotExist(err) {
		b, _ := os.ReadFile(path)
		t.Fatalf("a pure copy of the shipped map should be gone; still holds:\n%s", b)
	}
	if res := reconcileMimeDefaults(false); res.status != recOK {
		t.Fatalf("second pass = %v (%s); the reconciler must settle", res.status, res.detail)
	}
}

func TestMimeDefaultsKeepsTheUsersOwnPicks(t *testing.T) {
	// Firefox for links and images is the user's choice; the nvim and mpv lines
	// are Ryoku's, frozen into their file by an old update.
	user := `[Default Applications]
text/plain=ryoku-nvim.desktop
text/html=firefox.desktop
x-scheme-handler/http=firefox.desktop
image/png=org.gnome.Loupe.desktop
video/mp4=mpv.desktop
`
	_, path := mimeSandbox(t, user)

	if res := reconcileMimeDefaults(false); res.status != recFixed {
		t.Fatalf("status = %v (%s)", res.status, res.detail)
	}
	got, err := os.ReadFile(path)
	if err != nil {
		t.Fatalf("the file must survive: %v", err)
	}
	left := mimeDefaults(string(got))
	for mime, app := range map[string]string{
		"text/html":             "firefox.desktop",
		"x-scheme-handler/http": "firefox.desktop",
		"image/png":             "org.gnome.Loupe.desktop",
	} {
		if left[mime] != app {
			t.Fatalf("%s = %q, want %q (a user's pick must never be dropped)", mime, left[mime], app)
		}
	}
	for _, mime := range []string{"text/plain", "video/mp4"} {
		if _, still := left[mime]; still {
			t.Fatalf("%s was only a copy of the shipped default and should be gone", mime)
		}
	}
	if res := reconcileMimeDefaults(false); res.status != recOK {
		t.Fatalf("second pass = %v (%s)", res.status, res.detail)
	}
}

func TestMimeDefaultsLeavesOtherSectionsAndComments(t *testing.T) {
	user := `# my associations
[Added Associations]
text/plain=ryoku-nvim.desktop;kate.desktop;

[Default Applications]
text/plain=ryoku-nvim.desktop
application/pdf=org.gnome.Evince.desktop

[Removed Associations]
text/html=chromium.desktop;
`
	_, path := mimeSandbox(t, user)

	if res := reconcileMimeDefaults(false); res.status != recFixed {
		t.Fatalf("status = %v (%s)", res.status, res.detail)
	}
	got, err := os.ReadFile(path)
	if err != nil {
		t.Fatal(err)
	}
	text := string(got)
	for _, want := range []string{"# my associations", "[Added Associations]", "[Removed Associations]",
		"text/plain=ryoku-nvim.desktop;kate.desktop;", "application/pdf=org.gnome.Evince.desktop"} {
		if !strings.Contains(text, want) {
			t.Fatalf("lost %q from:\n%s", want, text)
		}
	}
	if strings.Contains(text, "\n[Default Applications]\ntext/plain=ryoku-nvim.desktop\n") {
		t.Fatalf("the redundant default should be gone:\n%s", text)
	}
}

func TestMimeDefaultsEmptySectionHeaderGoesToo(t *testing.T) {
	user := `[Default Applications]
text/plain=ryoku-nvim.desktop

[Added Associations]
image/png=org.gnome.Loupe.desktop;
`
	_, path := mimeSandbox(t, user)
	if res := reconcileMimeDefaults(false); res.status != recFixed {
		t.Fatalf("status = %v (%s)", res.status, res.detail)
	}
	got, _ := os.ReadFile(path)
	if strings.Contains(string(got), "[Default Applications]") {
		t.Fatalf("an emptied section header should go with its last entry:\n%s", got)
	}
	if !strings.Contains(string(got), "[Added Associations]") {
		t.Fatalf("other sections stay:\n%s", got)
	}
}

func TestMimeDefaultsNoUserFileIsFine(t *testing.T) {
	mimeSandbox(t, "")
	if res := reconcileMimeDefaults(false); res.status != recOK {
		t.Fatalf("status = %v (%s)", res.status, res.detail)
	}
}

func TestMimeDefaultsWithoutAShippedMapChangesNothing(t *testing.T) {
	// a box with no vendor map (a sudo-less dev deploy) must not have its
	// mimeapps.list touched: without the shipped map there is nothing to fall
	// back to, so dropping entries would lose the defaults entirely.
	dir := t.TempDir()
	cfg := filepath.Join(dir, "config")
	if err := os.MkdirAll(cfg, 0o755); err != nil {
		t.Fatal(err)
	}
	t.Setenv("XDG_CONFIG_HOME", cfg)
	t.Setenv("XDG_DATA_HOME", filepath.Join(dir, "data"))
	t.Setenv("XDG_DATA_DIRS", filepath.Join(dir, "empty"))
	path := filepath.Join(cfg, "mimeapps.list")
	if err := os.WriteFile(path, []byte(shippedMap), 0o644); err != nil {
		t.Fatal(err)
	}

	if res := reconcileMimeDefaults(false); res.status != recOK {
		t.Fatalf("status = %v (%s)", res.status, res.detail)
	}
	got, err := os.ReadFile(path)
	if err != nil || string(got) != shippedMap {
		t.Fatalf("file must be untouched, got %q (%v)", got, err)
	}
}

func TestMimeDefaultsCountsTheDataHomeLayer(t *testing.T) {
	// a value the deprecated ~/.local/share/applications layer already provides
	// is redundant too, so a dev box that laid it there converges the same way.
	dir, path := mimeSandbox(t, "[Default Applications]\naudio/flac=mpv.desktop\n")
	if err := os.WriteFile(filepath.Join(dir, "data", "applications", "mimeapps.list"),
		[]byte("[Default Applications]\naudio/flac=mpv.desktop\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	if res := reconcileMimeDefaults(false); res.status != recFixed {
		t.Fatalf("status = %v (%s)", res.status, res.detail)
	}
	if _, err := os.Stat(path); !os.IsNotExist(err) {
		t.Fatal("the user file held nothing but a lower layer's value")
	}
}

func TestSplitEntryHandlesTheSpecShape(t *testing.T) {
	for _, tc := range []struct{ line, mime, app string }{
		{"text/html=firefox.desktop", "text/html", "firefox.desktop"},
		{" text/html = firefox.desktop ; ", "text/html", "firefox.desktop"},
		{"text/html=a.desktop;b.desktop;", "text/html", "a.desktop;b.desktop"},
	} {
		mime, app, ok := splitEntry(tc.line)
		if !ok || mime != tc.mime || app != tc.app {
			t.Fatalf("splitEntry(%q) = %q %q %v", tc.line, mime, app, ok)
		}
	}
	if _, _, ok := splitEntry("not an entry"); ok {
		t.Fatal("a line with no = is not an entry")
	}
	if _, _, ok := splitEntry("text/html="); ok {
		t.Fatal("an entry with no value is not an entry")
	}
}
