package main

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

// fixtureServer serves the local extras fixture tree so a provider fetches a
// registry, manifests, and assets exactly as it would from raw GitHub. Flip
// *down to fake the source dropping so the stale-cache path is exercised.
func fixtureServer(t *testing.T) (*httptest.Server, *bool) {
	t.Helper()
	down := false
	fs := http.FileServer(http.Dir("testdata/extras"))
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if down {
			http.Error(w, "down", http.StatusServiceUnavailable)
			return
		}
		fs.ServeHTTP(w, r)
	}))
	t.Cleanup(srv.Close)
	return srv, &down
}

// itemsByID indexes a provider's items by ID for direct state assertions.
func itemsByID(items []Item) map[string]Item {
	m := make(map[string]Item, len(items))
	for _, it := range items {
		m[it.ID] = it
	}
	return m
}

// stubPlaceTool puts a fake ryoku-plugins-place on PATH that appends its args to
// a log, so a test can prove install seeds placement but never enables it.
func stubPlaceTool(t *testing.T) string {
	t.Helper()
	bin := t.TempDir()
	log := filepath.Join(t.TempDir(), "place.log")
	t.Setenv("PLACE_LOG", log)
	script := "#!/usr/bin/env bash\necho \"$*\" >> \"$PLACE_LOG\"\nexit 0\n"
	if err := os.WriteFile(filepath.Join(bin, "ryoku-plugins-place"), []byte(script), 0o755); err != nil {
		t.Fatal(err)
	}
	t.Setenv("PATH", bin+string(os.PathListSeparator)+os.Getenv("PATH"))
	return log
}

// TestPluginProviderNormalization proves the plugin provider carries registry
// metadata, resolves relative art to source URLs while passing absolute ones
// through, enriches sparse entries from the manifest, and joins local install,
// enabled, and update state from the data dir and plugins.json.
func TestPluginProviderNormalization(t *testing.T) {
	t.Setenv("XDG_CACHE_HOME", t.TempDir())
	data := t.TempDir()
	t.Setenv("XDG_DATA_HOME", data)
	config := t.TempDir()
	t.Setenv("XDG_CONFIG_HOME", config)
	srv, _ := fixtureServer(t)
	t.Setenv("RYOKU_EXTRAS_BASE", srv.URL)

	// market is installed at an older version and enabled in placement.
	localMan := filepath.Join(data, "ryoku", "plugins", "market", "manifest.json")
	if err := os.MkdirAll(filepath.Dir(localMan), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(localMan, []byte(`{"version":"1.0.0"}`), 0o644); err != nil {
		t.Fatal(err)
	}
	pj := filepath.Join(config, "ryoku", "plugins.json")
	if err := os.MkdirAll(filepath.Dir(pj), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(pj, []byte(`{"market":{"enabled":true,"host":"sidebarLeft"},"clock":{"enabled":true,"host":"sidebarLeft"}}`), 0o644); err != nil {
		t.Fatal(err)
	}

	prov := pluginProvider{cache: newCache()}
	if prov.Category().ID != "plugins" {
		t.Fatalf("category id = %q, want plugins", prov.Category().ID)
	}
	got, _, err := prov.Load(context.Background(), false)
	if err != nil {
		t.Fatalf("Load: %v", err)
	}

	by := itemsByID(got)
	if !by["market"].Installed {
		t.Fatal("installed plugin not marked installed")
	}
	if !by["market"].Enabled {
		t.Fatal("enabled plugin not marked enabled")
	}
	if !by["market"].UpdateAvailable {
		t.Fatal("newer registry version not marked update")
	}
	if art := by["market"].Art; art != srv.URL+"/plugins/market/assets/preview.gif" {
		t.Fatalf("relative preview not resolved: %q", art)
	}
	shots := by["market"].Screenshots
	if len(shots) != 2 || shots[0] != srv.URL+"/plugins/market/assets/a.png" {
		t.Fatalf("relative screenshot not resolved: %+v", shots)
	}
	if shots[1] != "https://cdn.example/b.png" {
		t.Fatalf("absolute screenshot must pass through: %q", shots[1])
	}

	// clock's registry entry is bare; name and version come from the manifest.
	if by["clock"].Name != "Clock" {
		t.Fatalf("manifest name not enriched: %q", by["clock"].Name)
	}
	if by["clock"].Version != "1.5.0" {
		t.Fatalf("manifest version not enriched: %q", by["clock"].Version)
	}
	if by["clock"].Installed || by["clock"].Enabled || by["clock"].UpdateAvailable {
		t.Fatalf("uninstalled clock carries install state: %+v", by["clock"])
	}
}

// TestPluginProviderOfflineFallback proves a source outage still renders the
// catalogue from the disk archive, flagged offline.
func TestPluginProviderOfflineFallback(t *testing.T) {
	t.Setenv("XDG_CACHE_HOME", t.TempDir())
	t.Setenv("XDG_DATA_HOME", t.TempDir())
	t.Setenv("XDG_CONFIG_HOME", t.TempDir())
	srv, down := fixtureServer(t)
	t.Setenv("RYOKU_EXTRAS_BASE", srv.URL)

	if _, _, err := (pluginProvider{cache: newCache()}).Load(context.Background(), false); err != nil {
		t.Fatalf("warm Load: %v", err)
	}
	*down = true
	got, state, err := (pluginProvider{cache: newCache()}).Load(context.Background(), false)
	if err != nil {
		t.Fatalf("offline Load: %v", err)
	}
	if !state.Offline {
		t.Error("offline load not flagged offline")
	}
	if len(got) == 0 {
		t.Error("offline load returned no items from the archive")
	}
}

// TestEnsurePluginStagesAndSeedsWithoutEnabling proves install downloads every
// manifest-declared file, seeds the placement preset, and never enables the
// plugin (install must not activate placement).
func TestEnsurePluginStagesAndSeedsWithoutEnabling(t *testing.T) {
	data := t.TempDir()
	t.Setenv("XDG_DATA_HOME", data)
	t.Setenv("XDG_CACHE_HOME", t.TempDir())
	srv, _ := fixtureServer(t)
	t.Setenv("RYOKU_EXTRAS_BASE", srv.URL)
	log := stubPlaceTool(t)

	dir, err := ensurePlugin("market")
	if err != nil {
		t.Fatalf("ensurePlugin: %v", err)
	}
	for _, f := range []string{"manifest.json", "SidebarLeft.qml", "extra.js"} {
		if _, err := os.Stat(filepath.Join(dir, f)); err != nil {
			t.Errorf("declared file missing after install: %s: %v", f, err)
		}
	}
	b, _ := os.ReadFile(log)
	if !strings.Contains(string(b), "market seed") {
		t.Errorf("plugin preset not seeded on install; log=%q", b)
	}
	if strings.Contains(string(b), "enabled true") {
		t.Errorf("install must not enable the plugin; log=%q", b)
	}
}

// TestEnsurePluginDiscardsPartialStage proves a missing declared file aborts the
// install and leaves no half-written plugin dir the runtime could mount.
func TestEnsurePluginDiscardsPartialStage(t *testing.T) {
	t.Setenv("XDG_DATA_HOME", t.TempDir())
	t.Setenv("XDG_CACHE_HOME", t.TempDir())
	srv, _ := fixtureServer(t)
	t.Setenv("RYOKU_EXTRAS_BASE", srv.URL)
	stubPlaceTool(t)

	if _, err := ensurePlugin("broken"); err == nil {
		t.Fatal("expected an error when a declared file is missing")
	}
	if _, err := os.Stat(pluginDataDir("broken")); !os.IsNotExist(err) {
		t.Errorf("aborted install left a partial plugin dir: %v", err)
	}
}

// TestRemovePluginUnlinksSymlink proves a dev plugin symlinked into a checkout
// is unlinked on removal, never recursed into, so the source tree survives.
func TestRemovePluginUnlinksSymlink(t *testing.T) {
	t.Setenv("XDG_DATA_HOME", t.TempDir())
	log := stubPlaceTool(t)

	src := t.TempDir()
	if err := os.WriteFile(filepath.Join(src, "manifest.json"), []byte(`{}`), 0o644); err != nil {
		t.Fatal(err)
	}
	link := pluginDataDir("dev")
	if err := os.MkdirAll(filepath.Dir(link), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.Symlink(src, link); err != nil {
		t.Fatal(err)
	}
	if err := removePlugin("dev"); err != nil {
		t.Fatalf("removePlugin: %v", err)
	}
	if _, err := os.Lstat(link); !os.IsNotExist(err) {
		t.Errorf("symlink not unlinked: %v", err)
	}
	if _, err := os.Stat(filepath.Join(src, "manifest.json")); err != nil {
		t.Errorf("symlink target eaten by removal: %v", err)
	}
	b, err := os.ReadFile(log)
	if err != nil && !os.IsNotExist(err) {
		t.Fatal(err)
	}
	if strings.Contains(string(b), "forget") {
		t.Fatalf("file-only removal forgot preserved placement: %q", b)
	}
}

// TestPluginProviderInstallPlaces proves the provider's Install surface places
// the plugin on disk via the shared asset primitive.
func TestPluginProviderInstallPlaces(t *testing.T) {
	t.Setenv("XDG_DATA_HOME", t.TempDir())
	t.Setenv("XDG_CACHE_HOME", t.TempDir())
	srv, _ := fixtureServer(t)
	t.Setenv("RYOKU_EXTRAS_BASE", srv.URL)
	stubPlaceTool(t)

	if err := (pluginProvider{cache: newCache()}).Install(context.Background(), "market"); err != nil {
		t.Fatalf("Install: %v", err)
	}
	if _, err := os.Stat(filepath.Join(pluginDataDir("market"), "manifest.json")); err != nil {
		t.Fatalf("provider install did not place the plugin: %v", err)
	}
}

func TestEnsurePluginForcesStalePlacementDisabled(t *testing.T) {
	data := t.TempDir()
	config := t.TempDir()
	t.Setenv("XDG_DATA_HOME", data)
	t.Setenv("XDG_CONFIG_HOME", config)
	t.Setenv("XDG_CACHE_HOME", t.TempDir())
	srv, _ := fixtureServer(t)
	t.Setenv("RYOKU_EXTRAS_BASE", srv.URL)

	helper, err := filepath.Abs(filepath.Join("..", "..", "..", "shell", "quickshell", "plugins", "ryoku-plugins-place"))
	if err != nil {
		t.Fatal(err)
	}
	bin := t.TempDir()
	if err := os.Symlink(helper, filepath.Join(bin, "ryoku-plugins-place")); err != nil {
		t.Fatal(err)
	}
	t.Setenv("PATH", bin+string(os.PathListSeparator)+os.Getenv("PATH"))
	if err := os.MkdirAll(pluginDataDir("market"), 0o755); err != nil {
		t.Fatal(err)
	}

	configPath := filepath.Join(config, "ryoku", "plugins.json")
	if err := os.MkdirAll(filepath.Dir(configPath), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(configPath, []byte(`{"market":{"enabled":true,"host":"sidebarLeft","settings":{"kept":"yes"}}}`), 0o644); err != nil {
		t.Fatal(err)
	}
	if _, err := ensurePlugin("market"); err != nil {
		t.Fatalf("ensurePlugin: %v", err)
	}
	raw, err := os.ReadFile(configPath)
	if err != nil {
		t.Fatal(err)
	}
	var placements map[string]struct {
		Enabled bool           `json:"enabled"`
		Host    string         `json:"host"`
		Settings map[string]any `json:"settings"`
	}
	if err := json.Unmarshal(raw, &placements); err != nil {
		t.Fatal(err)
	}
	got := placements["market"]
	if got.Enabled {
		t.Fatal("install re-enabled stale placement")
	}

	if got.Host != "sidebarLeft" || got.Settings["kept"] != "yes" {
		t.Fatalf("install discarded placement state: %#v", got)
	}
}

func TestEnsurePluginRejectsAbsoluteManifestPath(t *testing.T) {
	data := t.TempDir()
	t.Setenv("XDG_DATA_HOME", data)
	t.Setenv("XDG_CACHE_HOME", t.TempDir())
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if strings.HasSuffix(r.URL.Path, "/manifest.json") {
			w.Write([]byte(`{"files":["/absolute.js"]}`))
			return
		}
		w.Write([]byte("payload"))
	}))
	t.Cleanup(srv.Close)
	t.Setenv("RYOKU_EXTRAS_BASE", srv.URL)
	stubPlaceTool(t)

	if _, err := ensurePlugin("safe"); err == nil {
		t.Fatal("absolute manifest path accepted")
	}
	if _, err := os.Lstat(filepath.Join(data, "absolute.js")); !os.IsNotExist(err) {
		t.Fatalf("absolute manifest path wrote outside stage: %v", err)
	}
}

func TestEnsurePluginRejectsEscapingPaths(t *testing.T) {
	t.Run("id", func(t *testing.T) {
		data := t.TempDir()
		t.Setenv("XDG_DATA_HOME", data)
		t.Setenv("XDG_CACHE_HOME", t.TempDir())
		srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
			w.Write([]byte(`{}`))
		}))
		t.Cleanup(srv.Close)
		t.Setenv("RYOKU_EXTRAS_BASE", srv.URL)
		stubPlaceTool(t)

		if _, err := ensurePlugin("../../escape"); err == nil {
			t.Fatal("escaping plugin id accepted")
		}
		if _, err := os.Lstat(filepath.Join(data, "escape")); !os.IsNotExist(err) {
			t.Fatalf("escaping id mutated outside plugin root: %v", err)
		}
	})

	t.Run("manifest file", func(t *testing.T) {
		data := t.TempDir()
		t.Setenv("XDG_DATA_HOME", data)
		t.Setenv("XDG_CACHE_HOME", t.TempDir())
		srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			if strings.HasSuffix(r.URL.Path, "/manifest.json") {
				w.Write([]byte(`{"files":["../../escape.js"]}`))
				return
			}
			w.Write([]byte("payload"))
		}))
		t.Cleanup(srv.Close)
		t.Setenv("RYOKU_EXTRAS_BASE", srv.URL)
		stubPlaceTool(t)

		if _, err := ensurePlugin("safe"); err == nil {
			t.Fatal("escaping manifest path accepted")
		}
		if _, err := os.Lstat(filepath.Join(data, "ryoku", "escape.js")); !os.IsNotExist(err) {
			t.Fatalf("manifest path wrote outside stage: %v", err)
		}
	})
}

func TestEnsurePluginRestoresPriorInstallOnPublishFailure(t *testing.T) {
	data := t.TempDir()
	t.Setenv("XDG_DATA_HOME", data)
	t.Setenv("XDG_CACHE_HOME", t.TempDir())
	srv, _ := fixtureServer(t)
	t.Setenv("RYOKU_EXTRAS_BASE", srv.URL)
	stubPlaceTool(t)

	dst := pluginDataDir("market")
	if err := os.MkdirAll(dst, 0o755); err != nil {
		t.Fatal(err)
	}
	old := filepath.Join(dst, "old.txt")
	if err := os.WriteFile(old, []byte("known-good"), 0o644); err != nil {
		t.Fatal(err)
	}

	realRename := renamePath
	renamePath = func(from, to string) error {
		if to == dst && strings.Contains(filepath.Base(from), ".stage-") {
			return os.ErrPermission
		}
		return realRename(from, to)
	}
	t.Cleanup(func() { renamePath = realRename })

	if _, err := ensurePlugin("market"); err == nil {
		t.Fatal("expected publish failure")
	}
	b, err := os.ReadFile(old)
	if err != nil || string(b) != "known-good" {
		t.Fatalf("prior install was not restored: data=%q err=%v", b, err)
	}
}

func TestRemovePluginRejectsDotID(t *testing.T) {
	t.Setenv("XDG_DATA_HOME", t.TempDir())
	root := filepath.Join(dataHome(), "ryoku", "plugins")
	if err := os.MkdirAll(root, 0o755); err != nil {
		t.Fatal(err)
	}
	marker := filepath.Join(root, "keep")
	if err := os.WriteFile(marker, []byte("keep"), 0o644); err != nil {
		t.Fatal(err)
	}
	if err := removePlugin("."); err == nil {
		t.Fatal("dot plugin id accepted")
	}
	if _, err := os.Stat(marker); err != nil {
		t.Fatalf("dot id removed plugin root: %v", err)
	}
}

func TestEnsurePluginUpdatePreservesEnabledPlacement(t *testing.T) {
	data := t.TempDir()
	config := t.TempDir()
	t.Setenv("XDG_DATA_HOME", data)
	t.Setenv("XDG_CONFIG_HOME", config)
	t.Setenv("XDG_CACHE_HOME", t.TempDir())
	srv, _ := fixtureServer(t)
	t.Setenv("RYOKU_EXTRAS_BASE", srv.URL)

	helper, err := filepath.Abs(filepath.Join("..", "..", "..", "shell", "quickshell", "plugins", "ryoku-plugins-place"))
	if err != nil {
		t.Fatal(err)
	}
	bin := t.TempDir()
	if err := os.Symlink(helper, filepath.Join(bin, "ryoku-plugins-place")); err != nil {
		t.Fatal(err)
	}
	t.Setenv("PATH", bin+string(os.PathListSeparator)+os.Getenv("PATH"))

	dst := pluginDataDir("market")
	if err := os.MkdirAll(dst, 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(dst, "manifest.json"), []byte(`{"version":"1.0.0"}`), 0o644); err != nil {
		t.Fatal(err)
	}
	configPath := filepath.Join(config, "ryoku", "plugins.json")
	if err := os.MkdirAll(filepath.Dir(configPath), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(configPath, []byte(`{"market":{"enabled":true,"host":"sidebarLeft"}}`), 0o644); err != nil {
		t.Fatal(err)
	}

	if _, err := ensurePlugin("market"); err != nil {
		t.Fatalf("ensurePlugin update: %v", err)
	}
	raw, err := os.ReadFile(configPath)
	if err != nil {
		t.Fatal(err)
	}
	var placements map[string]pluginPlacement
	if err := json.Unmarshal(raw, &placements); err != nil {
		t.Fatal(err)
	}
	if !placements["market"].Enabled {
		t.Fatal("updating an installed plugin deactivated it")
	}
}

func TestRecoverTreeRestoresInterruptedReplacement(t *testing.T) {
	parent := t.TempDir()
	dst := filepath.Join(parent, "market")
	backup := backupTreePath(dst)
	if err := os.MkdirAll(backup, 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(journalTreePath(dst), nil, 0o600); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(backup, "manifest.json"), []byte("known-good"), 0o644); err != nil {
		t.Fatal(err)
	}
	if err := recoverTree(dst); err != nil {
		t.Fatalf("recoverTree: %v", err)
	}
	if b, err := os.ReadFile(filepath.Join(dst, "manifest.json")); err != nil || string(b) != "known-good" {
		t.Fatalf("interrupted replacement was not recovered: data=%q err=%v", b, err)
	}
	if _, err := os.Lstat(backup); !os.IsNotExist(err) {
		t.Fatalf("backup journal survived recovery: %v", err)
	}
}

func TestTreeLockSerializesConcurrentInstallers(t *testing.T) {
	dst := filepath.Join(t.TempDir(), "market")
	unlockFirst, err := lockTree(dst)
	if err != nil {
		t.Fatal(err)
	}
	acquired := make(chan struct{})
	go func() {
		unlockSecond, err := lockTree(dst)
		if err == nil {
			close(acquired)
			unlockSecond()
		}
	}()
	select {
	case <-acquired:
		t.Fatal("second installer acquired destination lock concurrently")
	case <-time.After(50 * time.Millisecond):
	}
	unlockFirst()
	select {
	case <-acquired:
	case <-time.After(time.Second):
		t.Fatal("second installer did not acquire released destination lock")
	}
}

func TestRemovePluginWaitsForPublicationLock(t *testing.T) {
	t.Setenv("XDG_DATA_HOME", t.TempDir())
	dst := pluginDataDir("market")
	if err := os.MkdirAll(dst, 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(dst, "manifest.json"), []byte(`{}`), 0o644); err != nil {
		t.Fatal(err)
	}
	unlock, err := lockTree(dst)
	if err != nil {
		t.Fatal(err)
	}
	done := make(chan error, 1)
	go func() { done <- removePlugin("market") }()
	select {
	case err := <-done:
		t.Fatalf("removal raced publication lock: %v", err)
	case <-time.After(50 * time.Millisecond):
	}
	unlock()
	select {
	case err := <-done:
		if err != nil {
			t.Fatal(err)
		}
	case <-time.After(time.Second):
		t.Fatal("removal did not resume after publication lock")
	}
}
