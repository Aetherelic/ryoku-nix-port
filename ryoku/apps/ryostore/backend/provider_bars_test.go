package main

import (
	"context"
	"crypto/sha256"
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"testing"
)

type barProviderFixture struct {
	cache *Cache
	entry ProductEntry
	scene []byte
}

func newBarProviderFixture(t *testing.T) barProviderFixture {
	t.Helper()
	t.Setenv("XDG_CONFIG_HOME", filepath.Join(t.TempDir(), "config"))
	t.Setenv("XDG_DATA_HOME", filepath.Join(t.TempDir(), "data"))
	t.Setenv("XDG_STATE_HOME", filepath.Join(t.TempDir(), "state"))
	t.Setenv("XDG_CACHE_HOME", filepath.Join(t.TempDir(), "cache"))

	scene := []byte("import QtQuick\nItem { property string marker: \"obi-v1\" }\n")
	sceneHash := sha256.Sum256(scene)
	manifest := ProductManifest{
		Schema: 1, ID: "obi", Category: "barstyles", Version: "1.0.0",
		Destination: "ryoku/barstyles/obi",
		Files: []ProductFile{{
			Source: "Scene.qml", Destination: "Scene.qml", Mode: "0644",
			Size: int64(len(scene)), SHA256: fmt.Sprintf("%x", sceneHash), Install: true,
		}},
	}
	manifestRaw, err := json.Marshal(manifest)
	if err != nil {
		t.Fatal(err)
	}
	manifestDigest := sha256.Sum256(manifestRaw)
	entry := ProductEntry{
		ID: "obi", Name: "Obi", Version: "1.0.0", Path: "barstyles/obi",
		Author: "Ryoku Team", Summary: "Floating sash", Description: "A complete bar scene.",
		Tags: []string{"top"}, Accent: "#b86b5f", Surface: "#11100f",
		Preview: "assets/preview.webp", Screenshots: []string{}, Manifest: "manifest.json",
		ManifestSHA256: fmt.Sprintf("%x", manifestDigest),
	}
	registryRaw, err := json.Marshal(map[string]any{"schema": 1, "barstyles": []ProductEntry{entry}})
	if err != nil {
		t.Fatal(err)
	}
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		switch r.URL.Path {
		case "/barstyles/registry.json":
			_, _ = w.Write(registryRaw)
		case "/barstyles/obi/manifest.json":
			_, _ = w.Write(manifestRaw)
		case "/barstyles/obi/Scene.qml":
			_, _ = w.Write(scene)
		default:
			http.NotFound(w, r)
		}
	}))
	t.Cleanup(server.Close)
	return barProviderFixture{
		entry: entry, scene: scene,
		cache: &Cache{client: server.Client(), base: server.URL, dir: t.TempDir(), memo: map[string]memoEntry{}},
	}
}

func TestBarProviderUsesRegistryReceiptsAndDerivedIndex(t *testing.T) {
	fixture := newBarProviderFixture(t)
	config := filepath.Join(configHome(), "ryoku", "shell.json")
	if err := os.MkdirAll(filepath.Dir(config), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(config, []byte("{\"barStyle\":\"obi\",\"keep\":true}\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	provider := barProvider{cache: fixture.cache, shellConfig: config}

	items, _, err := provider.Load(context.Background(), false)
	if err != nil {
		t.Fatal(err)
	}
	if len(items) != 2 || items[0].ID != "sumi" || !items[0].Installed || !items[0].Active {
		t.Fatalf("initial items = %+v", items)
	}
	if items[1].ID != "obi" || items[1].Installed || items[1].Active {
		t.Fatalf("initial external item = %+v", items[1])
	}

	if err := provider.Install(context.Background(), "obi"); err != nil {
		t.Fatal(err)
	}
	dst, _, err := productDestination("barstyles", "obi")
	if err != nil {
		t.Fatal(err)
	}
	if body, err := os.ReadFile(filepath.Join(dst, "Scene.qml")); err != nil || string(body) != string(fixture.scene) {
		t.Fatalf("installed scene = %q, err=%v", body, err)
	}
	var rows []barStyleIndexRow
	if raw, err := os.ReadFile(barStyleIndexPath()); err != nil {
		t.Fatal(err)
	} else if err := json.Unmarshal(raw, &rows); err != nil {
		t.Fatal(err)
	}
	if len(rows) != 1 || rows[0] != (barStyleIndexRow{ID: "obi", Version: "1.0.0", Scene: "Scene.qml"}) {
		t.Fatalf("installed index = %+v", rows)
	}

	items, _, err = provider.Load(context.Background(), false)
	if err != nil {
		t.Fatal(err)
	}
	if !items[1].Installed || !items[1].Active {
		t.Fatalf("installed item = %+v", items[1])
	}

	if err := provider.Remove(context.Background(), "obi"); err != nil {
		t.Fatal(err)
	}
	if _, err := os.Stat(dst); !os.IsNotExist(err) {
		t.Fatalf("removed destination still exists: %v", err)
	}
	if raw, err := os.ReadFile(barStyleIndexPath()); err != nil {
		t.Fatal(err)
	} else if string(raw) != "[]\n" {
		t.Fatalf("removed index = %q", raw)
	}
	var shell map[string]any
	if raw, err := os.ReadFile(config); err != nil {
		t.Fatal(err)
	} else if err := json.Unmarshal(raw, &shell); err != nil {
		t.Fatal(err)
	}
	if shell["barStyle"] != "sumi" || shell["keep"] != true {
		t.Fatalf("fallback config = %#v", shell)
	}
}

func TestBarProviderRefusesBuiltinRemoval(t *testing.T) {
	if err := (barProvider{}).Remove(context.Background(), "sumi"); err == nil {
		t.Fatal("built-in Sumi was removable")
	}
}
