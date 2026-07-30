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
)

func lockTreeFixture(t *testing.T) ([]byte, map[string][]byte) {
	t.Helper()
	files := map[string][]byte{
		"Assets/clockwork.gif":                 []byte("clockwork-gif"),
		"Assets/pixel_coffee.gif":              []byte("pixel-gif"),
		"themes/clockwork/orbital/Main.qml":    []byte("orbital-main"),
		"themes/clockwork/orbital/preview.gif": []byte("orbital-preview"),
		"themes/pixel-coffee/Main.qml":         []byte("pixel-main"),
		"themes/pixel-coffee/asset.bin":        []byte("123456"),
	}
	type entry struct {
		Path string `json:"path"`
		Type string `json:"type"`
		Size int    `json:"size"`
	}
	entries := []entry{
		{Path: "Assets/clockwork.gif", Type: "blob", Size: 10},
		{Path: "Assets/pixel_coffee.gif", Type: "blob", Size: 12},
	}
	for path, body := range files {
		entries = append(entries, entry{Path: path, Type: "blob", Size: len(body)})
	}
	b, err := json.Marshal(map[string]any{"truncated": false, "tree": entries})
	if err != nil {
		t.Fatal(err)
	}
	return b, files
}

func lockFixtureServer(t *testing.T) (*httptest.Server, *bool) {
	t.Helper()
	tree, files := lockTreeFixture(t)
	down := false
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if down {
			http.Error(w, "offline", http.StatusServiceUnavailable)
			return
		}
		if strings.Contains(r.URL.Path, "/git/trees/") {
			_, _ = w.Write(tree)
			return
		}
		prefix := "/Darkkal44/qylock/main/"
		if body, ok := files[strings.TrimPrefix(r.URL.Path, prefix)]; ok {
			_, _ = w.Write(body)
			return
		}
		http.NotFound(w, r)
	}))
	t.Cleanup(srv.Close)
	return srv, &down
}

func testLockProvider(t *testing.T, srv *httptest.Server) lockProvider {
	t.Helper()
	return lockProvider{
		client:         srv.Client(),
		downloadClient: srv.Client(),
		apiBase:        srv.URL,
		rawBase:        srv.URL,
		cacheDir:       filepath.Join(t.TempDir(), "cache"),
		themesDir:      filepath.Join(t.TempDir(), "themes"),
		prefPath:       filepath.Join(t.TempDir(), "qylock", "theme"),
	}
}

func TestParseQylockTreePreservesNestedThemesAndInstallBytes(t *testing.T) {
	b, _ := lockTreeFixture(t)
	tree, err := parseQylockTree(b)
	if err != nil {
		t.Fatal(err)
	}
	if strings.Join(tree.Themes, ",") != "clockwork/orbital,pixel-coffee" {
		t.Fatalf("themes = %v", tree.Themes)
	}
	if len(tree.Files["pixel-coffee"]) != 2 {
		t.Fatalf("pixel files = %v", tree.Files["pixel-coffee"])
	}
	if tree.Bytes["pixel-coffee"] != len("pixel-main")+len("123456") {
		t.Fatalf("pixel bytes = %d", tree.Bytes["pixel-coffee"])
	}
}

func TestMapThemeGifAliasesAndNormalizes(t *testing.T) {
	gifs := map[string]bool{"clockwork": true, "pixel_coffee": true, "the_last_of_us": true, "win7": true}
	for slug, want := range map[string]string{
		"clockwork/orbital": "clockwork",
		"pixel-coffee":      "pixel_coffee",
		"last-of-us":        "the_last_of_us",
		"windows_7":         "win7",
	} {
		if got, ok := mapThemeGif(slug, gifs); !ok || got != want {
			t.Errorf("mapThemeGif(%q) = %q,%v; want %q,true", slug, got, ok, want)
		}
	}
}

func TestLockProviderLoadsLocalFirstAndSortsActiveInstalled(t *testing.T) {
	srv, _ := lockFixtureServer(t)
	p := testLockProvider(t, srv)
	local := filepath.Join(p.themesDir, "clockwork", "orbital")
	if err := os.MkdirAll(local, 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(local, "Main.qml"), []byte("local"), 0o644); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(local, "preview.gif"), []byte("gif"), 0o644); err != nil {
		t.Fatal(err)
	}
	if err := os.MkdirAll(filepath.Dir(p.prefPath), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(p.prefPath, []byte("clockwork/orbital\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	items, state, err := p.Load(context.Background(), false)
	if err != nil {
		t.Fatal(err)
	}
	if state.Offline || len(items) != 2 {
		t.Fatalf("state=%+v items=%+v", state, items)
	}
	if items[0].ID != "clockwork/orbital" || !items[0].Installed || !items[0].Active {
		t.Fatalf("active installed item not first: %+v", items)
	}
	if items[0].Art != "file://"+filepath.Join(local, "preview.gif") {
		t.Fatalf("local preview not preferred: %q", items[0].Art)
	}
	if items[1].Metadata["slug"] != "pixel-coffee" || items[1].Metadata["theme"] != "" {
		t.Fatalf("metadata = %+v", items[1].Metadata)
	}
}

func TestLockProviderRefreshesThenFallsBackOffline(t *testing.T) {
	srv, down := lockFixtureServer(t)
	p := testLockProvider(t, srv)
	first, state, err := p.Load(context.Background(), false)
	if err != nil || state.Offline || len(first) != 2 {
		t.Fatalf("first load: items=%d state=%+v err=%v", len(first), state, err)
	}
	*down = true
	second, state, err := p.Load(context.Background(), true)
	if err != nil {
		t.Fatal(err)
	}
	if !state.Offline || state.CachedAt == "" || len(second) != 2 {
		t.Fatalf("offline fallback: items=%d state=%+v", len(second), state)
	}
	for _, item := range second {
		if item.Art == "" || !strings.HasPrefix(item.Art, "file://") {
			t.Fatalf("offline preview was not archived: %+v", item)
		}
	}
}

func TestLockInstallDoesNotChangePreference(t *testing.T) {
	srv, _ := lockFixtureServer(t)
	p := testLockProvider(t, srv)
	if err := os.MkdirAll(filepath.Dir(p.prefPath), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(p.prefPath, []byte("clockwork/orbital\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	if err := p.Install(context.Background(), "pixel-coffee"); err != nil {
		t.Fatal(err)
	}
	got, err := os.ReadFile(p.prefPath)
	if err != nil {
		t.Fatal(err)
	}
	if string(got) != "clockwork/orbital\n" {
		t.Fatalf("preference changed: %q", got)
	}
	main, err := os.ReadFile(filepath.Join(p.themesDir, "pixel-coffee", "Main.qml"))
	if err != nil || string(main) != "pixel-main" {
		t.Fatalf("installed Main.qml = %q, err=%v", main, err)
	}
	asset, err := os.ReadFile(filepath.Join(p.themesDir, "pixel-coffee", "asset.bin"))
	if err != nil || string(asset) != "123456" {
		t.Fatalf("installed asset = %q, err=%v", asset, err)
	}
}

func TestLockProviderRepairsMalformedFreshCache(t *testing.T) {
	srv, _ := lockFixtureServer(t)
	p := testLockProvider(t, srv)
	if err := os.MkdirAll(p.cacheDir, 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(p.treeCachePath(), []byte("{broken"), 0o644); err != nil {
		t.Fatal(err)
	}
	items, state, err := p.Load(context.Background(), false)
	if err != nil {
		t.Fatal(err)
	}
	if state.Offline || len(items) != 2 {
		t.Fatalf("fresh malformed cache was not repaired: state=%+v items=%+v", state, items)
	}
}

func TestLockInstallRejectsIntermediateSymlink(t *testing.T) {
	srv, _ := lockFixtureServer(t)
	p := testLockProvider(t, srv)
	if err := os.MkdirAll(p.themesDir, 0o755); err != nil {
		t.Fatal(err)
	}
	external := t.TempDir()
	marker := filepath.Join(external, "keep")
	if err := os.WriteFile(marker, []byte("safe"), 0o644); err != nil {
		t.Fatal(err)
	}
	if err := os.Symlink(external, filepath.Join(p.themesDir, "clockwork")); err != nil {
		t.Fatal(err)
	}
	if err := p.Install(context.Background(), "clockwork/orbital"); err == nil {
		t.Fatal("install accepted a symlinked theme family")
	}
	if got, err := os.ReadFile(marker); err != nil || string(got) != "safe" {
		t.Fatalf("external tree changed: data=%q err=%v", got, err)
	}
}

func TestLockCacheNamespaceFollowsSourceOverrides(t *testing.T) {
	t.Setenv("XDG_CACHE_HOME", t.TempDir())
	t.Setenv("RYOKU_QYLOCK_API", "https://fork-one.test/api")
	t.Setenv("RYOKU_QYLOCK_RAW", "https://fork-one.test/raw")
	one := newLockProvider().cacheDir
	t.Setenv("RYOKU_QYLOCK_API", "https://fork-two.test/api")
	t.Setenv("RYOKU_QYLOCK_RAW", "https://fork-two.test/raw")
	two := newLockProvider().cacheDir
	if one == two {
		t.Fatalf("source overrides shared cache directory %q", one)
	}
}

func TestLockscreenCategoryLeadsWearProviders(t *testing.T) {
	provs := providers()
	if len(provs) < 3 || provs[0].Category().ID != "lockscreens" {
		t.Fatalf("provider order = %v, want lockscreens first", []string{
			provs[0].Category().ID,
			provs[1].Category().ID,
			provs[2].Category().ID,
		})
	}
	if provs[0].Category().Group != "wear" {
		t.Fatalf("lockscreen group = %q, want wear", provs[0].Category().Group)
	}
}
