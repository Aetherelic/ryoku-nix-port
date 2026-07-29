package main

import (
	"bytes"
	"context"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"sync"
	"testing"
)

// TestCacheServesStaleDiskWhenOffline proves the archive-when-offline contract:
// a live fetch caches to disk, and a later invocation whose network is gone
// serves the same bytes flagged Offline with a non-empty CachedAt.
func TestCacheServesStaleDiskWhenOffline(t *testing.T) {
	t.Setenv("XDG_CACHE_HOME", t.TempDir())
	body := []byte(`{"registry":true}`)
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Write(body)
	}))
	t.Setenv("RYOKU_EXTRAS_BASE", srv.URL)

	live, state, err := newCache().Fetch(context.Background(), "plugins/registry.json", false)
	if err != nil {
		t.Fatalf("live fetch: %v", err)
	}
	if state.Offline {
		t.Fatalf("live fetch must not report Offline")
	}
	if !bytes.Equal(live, body) {
		t.Fatalf("live bytes = %q, want %q", live, body)
	}

	srv.Close() // a fresh invocation with the network gone must fall back to disk.

	stale, state, err := newCache().Fetch(context.Background(), "plugins/registry.json", false)
	if err != nil {
		t.Fatalf("offline fetch: %v", err)
	}
	if !bytes.Equal(stale, body) {
		t.Fatalf("stale bytes = %q, want %q", stale, body)
	}
	if !state.Offline {
		t.Fatalf("offline fetch must report Offline")
	}
	if state.CachedAt == "" {
		t.Fatalf("offline fetch must report a CachedAt")
	}
}

// TestCacheRefreshBypassesMemoAndReplacesDisk proves refresh semantics: a
// repeated fetch answers from the fresh in-process copy, while refresh bypasses
// it to pull the new upstream bytes and rewrite the disk cache.
func TestCacheRefreshBypassesMemoAndReplacesDisk(t *testing.T) {
	cacheHome := t.TempDir()
	t.Setenv("XDG_CACHE_HOME", cacheHome)
	var mu sync.Mutex
	body := []byte("v1")
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		mu.Lock()
		defer mu.Unlock()
		w.Write(body)
	}))
	t.Cleanup(srv.Close)
	t.Setenv("RYOKU_EXTRAS_BASE", srv.URL)

	c := newCache()
	ctx := context.Background()

	if b, _, err := c.Fetch(ctx, "bundles/registry.json", false); err != nil || string(b) != "v1" {
		t.Fatalf("prime fetch = %q, %v", b, err)
	}

	mu.Lock()
	body = []byte("v2")
	mu.Unlock()

	if b, _, err := c.Fetch(ctx, "bundles/registry.json", false); err != nil || string(b) != "v1" {
		t.Fatalf("repeat fetch = %q, %v; want cached v1 without a network hit", b, err)
	}

	got, state, err := c.Fetch(ctx, "bundles/registry.json", true)
	if err != nil {
		t.Fatalf("refresh fetch: %v", err)
	}
	if string(got) != "v2" {
		t.Fatalf("refresh bytes = %q, want v2", got)
	}
	if state.Offline {
		t.Fatalf("a live refresh must not report Offline")
	}
	disk, err := os.ReadFile(filepath.Join(cacheHome, "ryoku", "extras", "bundles", "registry.json"))
	if err != nil {
		t.Fatalf("read disk cache: %v", err)
	}
	if string(disk) != "v2" {
		t.Fatalf("disk cache = %q, want v2", disk)
	}
}
