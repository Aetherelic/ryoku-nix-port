package main

import (
	"context"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"testing"
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
	if err := os.WriteFile(pj, []byte(`{"market":{"enabled":true,"host":"sidebarLeft"}}`), 0o644); err != nil {
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
	stubPlaceTool(t)

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
