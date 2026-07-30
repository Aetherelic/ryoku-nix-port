package main

import (
	"context"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"testing"
	"time"
)

// TestBundleProviderNormalization proves the bundle provider carries registry
// metadata, resolves relative art, warms each script item's installer into the
// cache, and reports the total item count; with no status source nothing is
// installed.
func TestBundleProviderNormalization(t *testing.T) {
	cache := t.TempDir()
	t.Setenv("XDG_CACHE_HOME", cache)
	srv, _ := fixtureServer(t)
	t.Setenv("RYOKU_EXTRAS_BASE", srv.URL)

	prov := bundleProvider{
		cache:  newCache(),
		status: func(context.Context) map[string]map[string]bool { return nil },
		launch: func(string) error { return nil },
	}
	if prov.Category().ID != "bundles" {
		t.Fatalf("category id = %q, want bundles", prov.Category().ID)
	}
	got, _, err := prov.Load(context.Background(), false)
	if err != nil {
		t.Fatalf("Load: %v", err)
	}
	d := itemsByID(got)["demo"]
	if d.TotalCount != 2 {
		t.Fatalf("total count = %d, want 2", d.TotalCount)
	}
	if d.Art != srv.URL+"/bundles/demo/assets/hero.png" {
		t.Fatalf("relative art not resolved: %q", d.Art)
	}
	if len(d.Screenshots) != 2 || d.Screenshots[0] != srv.URL+"/bundles/demo/assets/a.png" {
		t.Fatalf("relative screenshot not resolved: %+v", d.Screenshots)
	}
	if d.Screenshots[1] != "https://cdn.example/b.png" {
		t.Fatalf("absolute screenshot must pass through: %q", d.Screenshots[1])
	}
	if _, err := os.Stat(filepath.Join(extrasCacheDir(), "installers", "demo-cli.sh")); err != nil {
		t.Fatalf("script installer not warmed into the cache: %v", err)
	}
	if d.InstalledCount != 0 || d.Installed {
		t.Fatalf("bundle with no status must be empty: %+v", d)
	}
}

// TestBundleProviderPartialAndFullCounts proves the actuator status join sets a
// first-class partial count and only marks a bundle installed when every item
// is present.
func TestBundleProviderPartialAndFullCounts(t *testing.T) {
	t.Setenv("XDG_CACHE_HOME", t.TempDir())
	srv, _ := fixtureServer(t)
	t.Setenv("RYOKU_EXTRAS_BASE", srv.URL)

	partial := bundleProvider{
		cache:  newCache(),
		status: func(context.Context) map[string]map[string]bool { return map[string]map[string]bool{"demo": {"cmatrix": true, "demo-cli": false}} },
		launch: func(string) error { return nil },
	}
	got, _, err := partial.Load(context.Background(), false)
	if err != nil {
		t.Fatalf("partial Load: %v", err)
	}
	d := itemsByID(got)["demo"]
	if d.InstalledCount != 1 || d.TotalCount != 2 {
		t.Fatalf("partial counts = %d/%d, want 1/2", d.InstalledCount, d.TotalCount)
	}
	if d.Installed {
		t.Fatal("a partial bundle must not be marked fully installed")
	}

	full := bundleProvider{
		cache:  newCache(),
		status: func(context.Context) map[string]map[string]bool { return map[string]map[string]bool{"demo": {"cmatrix": true, "demo-cli": true}} },
		launch: func(string) error { return nil },
	}
	got2, _, err := full.Load(context.Background(), false)
	if err != nil {
		t.Fatalf("full Load: %v", err)
	}
	d2 := itemsByID(got2)["demo"]
	if d2.InstalledCount != 2 || !d2.Installed {
		t.Fatalf("fully present bundle not marked installed: %d/%d installed=%v", d2.InstalledCount, d2.TotalCount, d2.Installed)
	}
}

// TestBundleProviderInstallLaunches proves Install delegates to the floating
// terminal launcher with the bundle id rather than mutating anything itself.
func TestBundleProviderInstallLaunches(t *testing.T) {
	t.Setenv("XDG_CACHE_HOME", t.TempDir())
	got := ""
	prov := bundleProvider{
		cache:  newCache(),
		status: func(context.Context) map[string]map[string]bool { return nil },
		launch: func(id string) error { got = id; return nil },
	}
	if err := prov.Install(context.Background(), "demo"); err != nil {
		t.Fatalf("Install: %v", err)
	}
	if got != "demo" {
		t.Fatalf("launcher id = %q, want demo", got)
	}
}

// TestEnsureInstaller proves a script installer is cached and served from disk
// when the source is offline, and a never-cached one errors clearly.
func TestEnsureInstaller(t *testing.T) {
	cache := t.TempDir()
	t.Setenv("XDG_CACHE_HOME", cache)
	srv, down := fixtureServer(t)
	t.Setenv("RYOKU_EXTRAS_BASE", srv.URL)

	p, err := ensureInstaller("demo-cli")
	if err != nil {
		t.Fatalf("ensureInstaller: %v", err)
	}
	if want := filepath.Join(extrasCacheDir(), "installers", "demo-cli.sh"); p != want {
		t.Fatalf("path = %q, want %q", p, want)
	}
	*down = true
	if _, err := ensureInstaller("demo-cli"); err != nil {
		t.Fatalf("offline ensureInstaller: %v", err)
	}
	if _, err := ensureInstaller("missing"); err == nil {
		t.Fatal("expected an error for an uncached, unreachable installer")
	}
}

// TestEnsureNautilusPack proves a pack's scripts install executable under their
// subdir, a tracking manifest records them, and removal clears the subdir.
func TestEnsureNautilusPack(t *testing.T) {
	data := t.TempDir()
	t.Setenv("XDG_DATA_HOME", data)
	t.Setenv("XDG_CACHE_HOME", t.TempDir())
	srv, _ := fixtureServer(t)
	t.Setenv("RYOKU_EXTRAS_BASE", srv.URL)

	if _, err := ensureNautilusPack("video-reformat"); err != nil {
		t.Fatalf("ensureNautilusPack: %v", err)
	}
	script := filepath.Join(data, "nautilus", "scripts", "Ryoku Creator", "Reformat 9x16")
	fi, err := os.Stat(script)
	if err != nil {
		t.Fatalf("script not installed: %v", err)
	}
	if fi.Mode().Perm()&0o111 == 0 {
		t.Errorf("script not executable: %v", fi.Mode())
	}
	if _, err := os.Stat(filepath.Join(data, "ryoku", "nautilus", "video-reformat", "manifest.json")); err != nil {
		t.Errorf("tracking manifest missing: %v", err)
	}
	if err := removeNautilusPack("video-reformat"); err != nil {
		t.Fatalf("removeNautilusPack: %v", err)
	}
	if _, err := os.Stat(script); !os.IsNotExist(err) {
		t.Errorf("script survived removal: %v", err)
	}
}

// TestAssetFetchBustsCDN proves the raw source fetch used by the asset install
// primitives defeats the GitHub raw (Fastly) CDN: a unique query per request
// plus a no-cache header, so a refresh never gets a stale hit.
func TestAssetFetchBustsCDN(t *testing.T) {
	got := make(chan string, 2)
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if cc := r.Header.Get("Cache-Control"); cc != "no-cache" {
			t.Errorf("missing no-cache header, got %q", cc)
		}
		got <- r.URL.RawQuery
		w.Write([]byte("ok"))
	}))
	t.Cleanup(srv.Close)
	t.Setenv("XDG_CACHE_HOME", t.TempDir())
	t.Setenv("RYOKU_EXTRAS_BASE", srv.URL)

	c := newCache()
	ctx := context.Background()
	if _, err := c.get(ctx, "plugins/registry.json"); err != nil {
		t.Fatalf("get: %v", err)
	}
	time.Sleep(time.Millisecond)
	if _, err := c.get(ctx, "plugins/registry.json"); err != nil {
		t.Fatalf("get: %v", err)
	}
	q1, q2 := <-got, <-got
	if q1 == "" {
		t.Fatal("first fetch sent no cache-busting query")
	}
	if q1 == q2 {
		t.Fatalf("two fetches reused query %q; a CDN could serve a stale hit", q1)
	}
}
