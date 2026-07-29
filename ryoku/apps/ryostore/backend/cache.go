package main

import (
	"context"
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"time"
)

// Cache is the shared fetch every provider uses to pull a relative path from the
// extras base. It answers a repeated path from an in-process memo, writes each
// live result to disk atomically, and falls back to the last disk copy (flagged
// Offline, with the cache's timestamp) when the network is gone, so a dead
// source degrades to its archive instead of blanking the catalogue.
type Cache struct {
	client *http.Client
	base   string
	dir    string
	mu     sync.Mutex
	memo   map[string][]byte
}

// cacheTimeout bounds a single fetch so one slow source cannot stall a probe.
const cacheTimeout = 12 * time.Second

func newCache() *Cache {
	return &Cache{
		client: &http.Client{Timeout: cacheTimeout},
		base:   extrasBase(),
		dir:    extrasCacheDir(),
		memo:   map[string][]byte{},
	}
}

// Fetch returns the bytes at rel. Without refresh a path already pulled this
// process answers from memory; otherwise it goes to the network, caches the
// result to disk, and memoizes it. On a network failure it serves the disk
// cache with Offline set and the cache file's timestamp. refresh always bypasses
// the memo to pull a fresh copy and replace the disk cache, still degrading to
// disk when offline.
func (c *Cache) Fetch(ctx context.Context, rel string, refresh bool) ([]byte, SourceState, error) {
	if !refresh {
		c.mu.Lock()
		b, ok := c.memo[rel]
		c.mu.Unlock()
		if ok {
			return b, SourceState{}, nil
		}
	}
	if b, err := c.get(ctx, rel); err == nil {
		c.writeDisk(rel, b)
		c.mu.Lock()
		c.memo[rel] = b
		c.mu.Unlock()
		return b, SourceState{}, nil
	}
	p := filepath.Join(c.dir, rel)
	if b, err := os.ReadFile(p); err == nil {
		state := SourceState{Offline: true}
		if fi, err := os.Stat(p); err == nil {
			state.CachedAt = fi.ModTime().UTC().Format(time.RFC3339)
		}
		return b, state, nil
	}
	return nil, SourceState{}, fmt.Errorf("cannot fetch or find cached %s", rel)
}

// get pulls rel live. A unique query parameter and a no-cache header defeat the
// raw GitHub (Fastly) CDN, which otherwise keeps serving a pre-push copy for
// minutes and makes a refresh look broken. The body is capped so a runaway
// response cannot exhaust memory.
func (c *Cache) get(ctx context.Context, rel string) ([]byte, error) {
	url := c.base + "/" + rel
	sep := "?"
	if strings.Contains(url, "?") {
		sep = "&"
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, fmt.Sprintf("%s%s_=%d", url, sep, time.Now().UnixNano()), nil)
	if err != nil {
		return nil, err
	}
	req.Header.Set("Cache-Control", "no-cache")
	resp, err := c.client.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("%s: %s", url, resp.Status)
	}
	return io.ReadAll(io.LimitReader(resp.Body, 4<<20))
}

// writeDisk caches data at rel via a same-directory temp file and rename, so a
// reader never sees a half-written cache. Best effort: a cache write failure
// must not fail the fetch that already has the bytes.
func (c *Cache) writeDisk(rel string, data []byte) {
	p := filepath.Join(c.dir, rel)
	if err := os.MkdirAll(filepath.Dir(p), 0o755); err != nil {
		return
	}
	tmp, err := os.CreateTemp(filepath.Dir(p), ".tmp-*")
	if err != nil {
		return
	}
	name := tmp.Name()
	if _, err := tmp.Write(data); err != nil {
		tmp.Close()
		os.Remove(name)
		return
	}
	if err := tmp.Close(); err != nil {
		os.Remove(name)
		return
	}
	os.Rename(name, p)
}
