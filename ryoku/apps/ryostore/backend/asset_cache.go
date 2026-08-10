// Browse asset cache: the store shows a preview (and screenshots) for every
// catalogue item, all served from a remote base by default. Loading those over
// the network on every open is slow, fails offline, and -- because the QML front
// end tears down in-flight network image loads when its window closes -- is a
// source of shutdown crashes. warmAssets pulls each remote image to disk once
// and rewrites the item to a local file:// path, so the store renders from the
// cache: instant, offline-capable, and with no live image requests to abort.
package main

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"io"
	"net/http"
	"os"
	"path"
	"path/filepath"
	"strings"
	"sync"
	"syscall"
	"time"
)

const (
	// maxAssetBytes caps one cached image so a misrouted URL cannot fill the
	// cache; generous enough for animated decor gifs.
	maxAssetBytes = 16 << 20
	// assetFetchTimeout bounds a single image download. Generous because a
	// preview can be a multi-megabyte gif and the source throttles concurrent
	// pulls from one address.
	assetFetchTimeout = 40 * time.Second
	// warmBudget caps the whole background warm so it always terminates even
	// against a slow source; the per-asset timeout bounds each download.
	warmBudget = 5 * time.Minute
	// assetFetchWorkers bounds concurrent downloads. Kept low so the source does
	// not throttle the batch into timeouts -- steady beats greedy here.
	assetFetchWorkers = 4
)

func assetCacheDir() string {
	return filepath.Join(extrasCacheDir(), "assets")
}

// rewriteCachedAssets swaps every already-cached remote asset URL for its local
// file:// path, leaving uncached and local assets untouched. It never downloads,
// so the catalogue command stays instant: the background warm fills the cache,
// and this picks up whatever is already on disk.
func rewriteCachedAssets(items []Item) {
	swap := func(u string) string {
		if !remoteAsset(u) {
			return u
		}
		if dst := cachedAssetPath(u); isRegularFile(dst) {
			return "file://" + dst
		}
		return u
	}
	for i := range items {
		items[i].Art = swap(items[i].Art)
		items[i].ArtRaw = swap(items[i].ArtRaw)
		for j := range items[i].Screenshots {
			items[i].Screenshots[j] = swap(items[i].Screenshots[j])
		}
	}
}

// warmLock takes a non-blocking exclusive lock so only one background warm runs
// at a time; a second launch exits at once instead of re-downloading in
// parallel. The lock releases when the holding process exits.
func warmLock() (func(), bool) {
	if err := os.MkdirAll(assetCacheDir(), 0o755); err != nil {
		return nil, false
	}
	f, err := os.OpenFile(filepath.Join(assetCacheDir(), ".warm.lock"), os.O_CREATE|os.O_RDWR, 0o600)
	if err != nil {
		return nil, false
	}
	if err := syscall.Flock(int(f.Fd()), syscall.LOCK_EX|syscall.LOCK_NB); err != nil {
		f.Close()
		return nil, false
	}
	return func() {
		_ = syscall.Flock(int(f.Fd()), syscall.LOCK_UN)
		_ = f.Close()
	}, true
}

func assetHTTPClient() *http.Client {
	return &http.Client{Timeout: assetFetchTimeout}
}

// remoteAsset reports whether u is an http(s) URL warmAssets should cache. A
// local file:// asset (a checkout under test) is already on disk and is left
// untouched.
func remoteAsset(u string) bool {
	return strings.HasPrefix(u, "http://") || strings.HasPrefix(u, "https://")
}

// cachedAssetPath is the content-addressed disk path for a remote asset URL,
// keyed by the URL so a stable upstream path maps to a stable cache file and its
// extension is preserved for QML's format detection.
func cachedAssetPath(url string) string {
	clean := url
	if i := strings.IndexAny(clean, "?#"); i >= 0 {
		clean = clean[:i]
	}
	ext := path.Ext(clean)
	if len(ext) > 8 || strings.ContainsAny(ext, "/\\") {
		ext = ""
	}
	sum := sha256.Sum256([]byte(url))
	return filepath.Join(assetCacheDir(), hex.EncodeToString(sum[:16])+ext)
}

// warmAssets downloads every unique remote preview and screenshot referenced by
// items into the asset cache and rewrites those fields to local file:// paths.
// It is idempotent: an already-cached URL is reused, so only the first warm (or
// a genuinely new asset) hits the network. A download failure leaves that item's
// remote URL in place, so the store still shows it over the network as a
// fallback rather than a blank tile.
func warmAssets(ctx context.Context, client *http.Client, items []Item) {
	if len(items) == 0 {
		return
	}
	if err := os.MkdirAll(assetCacheDir(), 0o755); err != nil {
		return
	}

	local := map[string]string{} // remote url -> local file:// path
	var order []string
	note := func(u string) {
		if !remoteAsset(u) {
			return
		}
		if _, seen := local[u]; seen {
			return
		}
		local[u] = ""
		order = append(order, u)
	}
	// Previews first: the grid is fully cached even if the deadline cuts the warm
	// short. Screenshots (shown only in a detail) fill whatever budget remains and
	// converge over later refreshes.
	for i := range items {
		note(items[i].Art)
		note(items[i].ArtRaw)
	}
	for i := range items {
		for _, s := range items[i].Screenshots {
			note(s)
		}
	}

	var mu sync.Mutex
	var wg sync.WaitGroup
	sem := make(chan struct{}, assetFetchWorkers)
	for _, u := range order {
		if ctx.Err() != nil {
			break
		}
		u := u
		dst := cachedAssetPath(u)
		if isRegularFile(dst) {
			mu.Lock()
			local[u] = "file://" + dst
			mu.Unlock()
			continue
		}
		wg.Add(1)
		sem <- struct{}{}
		go func() {
			defer wg.Done()
			defer func() { <-sem }()
			if err := downloadAsset(ctx, client, u, dst); err == nil {
				mu.Lock()
				local[u] = "file://" + dst
				mu.Unlock()
			}
		}()
	}
	wg.Wait()

	rewrite := func(u string) string {
		if p := local[u]; p != "" {
			return p
		}
		return u
	}
	for i := range items {
		items[i].Art = rewrite(items[i].Art)
		items[i].ArtRaw = rewrite(items[i].ArtRaw)
		for j := range items[i].Screenshots {
			items[i].Screenshots[j] = rewrite(items[i].Screenshots[j])
		}
	}
}

// downloadAsset fetches url to dst via a same-directory temp file and rename, so
// a reader never sees a half-written image.
func downloadAsset(ctx context.Context, client *http.Client, url, dst string) error {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, url, nil)
	if err != nil {
		return err
	}
	resp, err := client.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("%s: %s", url, resp.Status)
	}
	tmp, err := os.CreateTemp(assetCacheDir(), ".asset-*")
	if err != nil {
		return err
	}
	name := tmp.Name()
	n, copyErr := io.Copy(tmp, io.LimitReader(resp.Body, maxAssetBytes+1))
	closeErr := tmp.Close()
	if copyErr != nil {
		os.Remove(name)
		return copyErr
	}
	if closeErr != nil {
		os.Remove(name)
		return closeErr
	}
	if n > maxAssetBytes {
		os.Remove(name)
		return fmt.Errorf("%s: exceeds %d bytes", url, maxAssetBytes)
	}
	if err := os.Rename(name, dst); err != nil {
		os.Remove(name)
		return err
	}
	return nil
}
