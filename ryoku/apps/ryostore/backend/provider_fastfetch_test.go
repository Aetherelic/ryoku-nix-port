package main

import (
	"context"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"testing"
)

func TestFastfetchProviderTreatsUncached404AsEmptyCategory(t *testing.T) {
	srv := httptest.NewServer(http.NotFoundHandler())
	defer srv.Close()
	cache := &Cache{client: srv.Client(), base: srv.URL, dir: t.TempDir(), memo: map[string]memoEntry{}}
	items, state, err := (fastfetchProvider{cache: cache}).Load(context.Background(), false)
	if err != nil {
		t.Fatal(err)
	}
	if len(items) != 0 || state.Offline {
		t.Fatalf("items=%+v state=%+v", items, state)
	}
}

func TestFastfetchProviderNormalizesRegistryAndActiveStyle(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/fastfetch/registry.json" {
			http.NotFound(w, r)
			return
		}
		_, _ = w.Write([]byte(`{"version":1,"styles":[{"id":"minimal","name":"Minimal","summary":"Quiet system dossier","description":"A compact readout","preview":"fastfetch/minimal.png","tags":["compact"],"version":"1.0.0"}]}`))
	}))
	defer srv.Close()
	cache := &Cache{client: srv.Client(), base: srv.URL, dir: t.TempDir(), memo: map[string]memoEntry{}}
	config := filepath.Join(t.TempDir(), "config.jsonc")
	if err := os.WriteFile(config, []byte("{\n  // future store selection\n  \"style\": \"minimal\"\n}\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	items, _, err := (fastfetchProvider{cache: cache, configPath: config}).Load(context.Background(), false)
	if err != nil {
		t.Fatal(err)
	}
	if len(items) != 1 || items[0].ID != "minimal" || !items[0].Active {
		t.Fatalf("items = %+v", items)
	}
	if items[0].Art != srv.URL+"/fastfetch/minimal.png" {
		t.Fatalf("art = %q", items[0].Art)
	}
}

func TestFastfetchProviderLeavesMissingPreviewEmpty(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		_, _ = w.Write([]byte(`{"version":1,"styles":[{"id":"plain","name":"Plain"}]}`))
	}))
	defer srv.Close()
	cache := &Cache{client: srv.Client(), base: srv.URL, dir: t.TempDir(), memo: map[string]memoEntry{}}
	items, _, err := (fastfetchProvider{cache: cache}).Load(context.Background(), false)
	if err != nil {
		t.Fatal(err)
	}
	if len(items) != 1 || items[0].Art != "" {
		t.Fatalf("items = %+v", items)
	}
}
