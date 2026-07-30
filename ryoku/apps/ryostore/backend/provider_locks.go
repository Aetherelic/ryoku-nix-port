// The lockscreen provider owns qylock discovery and installation for Ryostore.
// It joins the upstream GitHub tree with the local theme directory, but install
// only publishes files: activation and greeter management remain in Ryoku Hub.
package main

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"sync"
	"time"
)

const (
	qylockOwnerRepo    = "Darkkal44/qylock"
	qylockBranch       = "main"
	defaultQylockAPI   = "https://api.github.com"
	defaultQylockRaw   = "https://raw.githubusercontent.com"
	lockTreeTTL        = 6 * time.Hour
	lockGifTTL         = 7 * 24 * time.Hour
	lockGifWorkers     = 6
	lockMaxPreviewFile = 64 << 20
	lockMaxFile        = 512 << 20
	lockWarmBudget     = 2 * time.Second
)

var lockGifAlias = map[string]string{
	"last-of-us": "the_last_of_us",
	"windows_7":  "win7",
}

type ghTreeEntry struct {
	Path string `json:"path"`
	Type string `json:"type"`
	Size int    `json:"size"`
}

type ghTree struct {
	Tree      []ghTreeEntry `json:"tree"`
	Truncated bool          `json:"truncated"`
}

type qylockTree struct {
	Themes []string
	Gifs   map[string]bool
	Files  map[string][]string
	Bytes  map[string]int
}

type lockProvider struct {
	client         *http.Client
	downloadClient *http.Client
	apiBase        string
	rawBase        string
	cacheDir       string
	themesDir      string
	prefPath       string
	warmTimeout    time.Duration
}

func newLockProvider() lockProvider {
	apiBase := os.Getenv("RYOKU_QYLOCK_API")
	if apiBase == "" {
		apiBase = defaultQylockAPI
	}
	rawBase := os.Getenv("RYOKU_QYLOCK_RAW")
	if rawBase == "" {
		rawBase = defaultQylockRaw
	}
	apiBase = strings.TrimRight(apiBase, "/")
	rawBase = strings.TrimRight(rawBase, "/")
	return lockProvider{
		client:         &http.Client{Timeout: 25 * time.Second},
		downloadClient: &http.Client{Timeout: 5 * time.Minute},
		apiBase:        apiBase,
		rawBase:        rawBase,
		cacheDir:       lockCacheDir(apiBase, rawBase),
		themesDir:      filepath.Join(dataHome(), "qylock", "themes"),
		prefPath:       filepath.Join(configHome(), "qylock", "theme"),
		warmTimeout:    lockWarmBudget,
	}
}

func lockCacheDir(apiBase, rawBase string) string {
	root := filepath.Join(xdgCacheHome(), "ryoku")
	if apiBase == defaultQylockAPI && rawBase == defaultQylockRaw {
		return root
	}
	sum := sha256.Sum256([]byte(apiBase + "\n" + rawBase))
	return filepath.Join(root, "lock-sources", hex.EncodeToString(sum[:8]))
}

func (lockProvider) Category() Category {
	return Category{
		ID:          "lockscreens",
		Name:        "Lockscreens",
		Group:       "wear",
		Description: "Complete qylock scenes for the session lock and sign-in screen.",
	}
}

func parseQylockTree(b []byte) (qylockTree, error) {
	var source ghTree
	if err := json.Unmarshal(b, &source); err != nil {
		return qylockTree{}, err
	}
	if source.Truncated {
		return qylockTree{}, fmt.Errorf("qylock tree is truncated")
	}
	out := qylockTree{
		Gifs:  map[string]bool{},
		Files: map[string][]string{},
		Bytes: map[string]int{},
	}
	for _, entry := range source.Tree {
		switch {
		case strings.HasPrefix(entry.Path, "Assets/") && strings.HasSuffix(entry.Path, ".gif"):
			out.Gifs[strings.TrimSuffix(strings.TrimPrefix(entry.Path, "Assets/"), ".gif")] = true
		case strings.HasPrefix(entry.Path, "themes/") && entry.Type == "blob" && strings.HasSuffix(entry.Path, "/Main.qml"):
			slug := strings.TrimSuffix(strings.TrimPrefix(entry.Path, "themes/"), "/Main.qml")
			if !validLocalPath(slug) {
				return qylockTree{}, fmt.Errorf("invalid lockscreen slug %q", slug)
			}
			out.Themes = append(out.Themes, slug)
		}
	}
	sort.Strings(out.Themes)
	fileThemes := append([]string(nil), out.Themes...)
	sort.Slice(fileThemes, func(i, j int) bool { return len(fileThemes[i]) > len(fileThemes[j]) })
	for _, entry := range source.Tree {
		if entry.Type != "blob" || !strings.HasPrefix(entry.Path, "themes/") {
			continue
		}
		rel := strings.TrimPrefix(entry.Path, "themes/")
		for _, slug := range fileThemes {
			if strings.HasPrefix(rel, slug+"/") {
				file := strings.TrimPrefix(rel, slug+"/")
				if !validLocalPath(file) {
					return qylockTree{}, fmt.Errorf("lockscreen %q has invalid file path %q", slug, file)
				}
				out.Files[slug] = append(out.Files[slug], file)
				out.Bytes[slug] += entry.Size
				break
			}
		}
	}
	return out, nil
}

func lockNorm(s string) string {
	var b strings.Builder
	for _, r := range strings.ToLower(s) {
		if r >= 'a' && r <= 'z' || r >= '0' && r <= '9' {
			b.WriteRune(r)
		}
	}
	return b.String()
}

func mapThemeGif(slug string, gifs map[string]bool) (string, bool) {
	top := strings.SplitN(slug, "/", 2)[0]
	if alias, ok := lockGifAlias[slug]; ok {
		return alias, gifs[alias]
	}
	if alias, ok := lockGifAlias[top]; ok {
		return alias, gifs[alias]
	}
	want := lockNorm(top)
	for gif := range gifs {
		if lockNorm(gif) == want {
			return gif, true
		}
	}
	return "", false
}

func (p lockProvider) treeURL() string {
	return fmt.Sprintf("%s/repos/%s/git/trees/%s?recursive=1", p.apiBase, qylockOwnerRepo, qylockBranch)
}

func (p lockProvider) rawURL(path string) string {
	return fmt.Sprintf("%s/%s/%s/%s", p.rawBase, qylockOwnerRepo, qylockBranch, path)
}

func (p lockProvider) treeCachePath() string {
	return filepath.Join(p.cacheDir, "lock-catalog-tree.json")
}
func (p lockProvider) previewCachePath(gif string) string {
	return filepath.Join(p.cacheDir, "lock-previews", gif+".gif")
}

func (p lockProvider) fetch(ctx context.Context, url string, limit int64) ([]byte, error) {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, url, nil)
	if err != nil {
		return nil, err
	}
	req.Header.Set("Accept", "application/vnd.github+json")
	req.Header.Set("User-Agent", "ryostore")
	resp, err := p.client.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("%s: HTTP %d", url, resp.StatusCode)
	}
	b, err := io.ReadAll(io.LimitReader(resp.Body, limit+1))
	if err != nil {
		return nil, err
	}
	if int64(len(b)) > limit {
		return nil, fmt.Errorf("%s: response exceeds %d bytes", url, limit)
	}
	return b, nil
}

func (p lockProvider) downloadTo(ctx context.Context, url, dst string, limit int64) error {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, url, nil)
	if err != nil {
		return err
	}
	req.Header.Set("User-Agent", "ryostore")
	resp, err := p.downloadClient.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("%s: HTTP %d", url, resp.StatusCode)
	}
	if err := os.MkdirAll(filepath.Dir(dst), 0o755); err != nil {
		return err
	}
	tmp, err := os.CreateTemp(filepath.Dir(dst), ".download-*")
	if err != nil {
		return err
	}
	tmpName := tmp.Name()
	defer os.Remove(tmpName)
	n, copyErr := io.CopyN(tmp, resp.Body, limit+1)
	if copyErr != nil && copyErr != io.EOF {
		tmp.Close()
		return copyErr
	}
	if n > limit {
		tmp.Close()
		return fmt.Errorf("%s: response exceeds %d bytes", url, limit)
	}
	if err := tmp.Chmod(0o644); err != nil {
		tmp.Close()
		return err
	}
	if err := tmp.Close(); err != nil {
		return err
	}
	return os.Rename(tmpName, dst)
}

func (p lockProvider) warmPreviews(ctx context.Context, tree qylockTree, refresh bool) {
	wanted := map[string]bool{}
	for _, slug := range tree.Themes {
		if gif, ok := mapThemeGif(slug, tree.Gifs); ok {
			wanted[gif] = true
		}
	}
	var wg sync.WaitGroup
	sem := make(chan struct{}, lockGifWorkers)
	for gif := range wanted {
		dst := p.previewCachePath(gif)
		if !refresh {
			if fi, err := os.Stat(dst); err == nil && time.Since(fi.ModTime()) < lockGifTTL {
				continue
			}
		}
		wg.Add(1)
		sem <- struct{}{}
		go func() {
			defer wg.Done()
			defer func() { <-sem }()
			_ = p.downloadTo(ctx, p.rawURL("Assets/"+gif+".gif"), dst, lockMaxPreviewFile)
		}()
	}
	wg.Wait()
}

func (p lockProvider) loadTree(ctx context.Context, refresh bool) (qylockTree, SourceState, error) {
	cache := p.treeCachePath()
	if !refresh {
		if fi, err := os.Stat(cache); err == nil && time.Since(fi.ModTime()) < lockTreeTTL {
			if b, err := os.ReadFile(cache); err == nil {
				if tree, err := parseQylockTree(b); err == nil {
					return tree, SourceState{}, nil
				}
			}
		}
	}
	b, err := p.fetch(ctx, p.treeURL(), maxBody)
	if err == nil {
		if parsed, parseErr := parseQylockTree(b); parseErr == nil {
			_ = atomicWrite(cache, b, 0o644)
			return parsed, SourceState{}, nil
		} else {
			err = parseErr
		}
	}
	if stale, readErr := os.ReadFile(cache); readErr == nil {
		tree, parseErr := parseQylockTree(stale)
		if parseErr == nil {
			state := SourceState{Offline: true}
			if fi, statErr := os.Stat(cache); statErr == nil {
				state.CachedAt = fi.ModTime().UTC().Format(time.RFC3339)
			}
			return tree, state, nil
		}
	}
	return qylockTree{}, SourceState{Offline: true}, err
}

func scanLocalLockSlugs(dir string) []string {
	var slugs []string
	tops, _ := os.ReadDir(dir)
	for _, top := range tops {
		if !top.IsDir() {
			continue
		}
		if lockFileExists(filepath.Join(dir, top.Name(), "Main.qml")) {
			slugs = append(slugs, top.Name())
			continue
		}
		subs, _ := os.ReadDir(filepath.Join(dir, top.Name()))
		for _, sub := range subs {
			if sub.IsDir() && lockFileExists(filepath.Join(dir, top.Name(), sub.Name(), "Main.qml")) {
				slugs = append(slugs, top.Name()+"/"+sub.Name())
			}
		}
	}
	sort.Strings(slugs)
	return slugs
}

func displayLockPart(s string) string {
	words := strings.Fields(strings.NewReplacer("-", " ", "_", " ").Replace(s))
	for i, word := range words {
		if word != "" {
			words[i] = strings.ToUpper(word[:1]) + word[1:]
		}
	}
	return strings.Join(words, " ")
}

func (p lockProvider) normalize(tree qylockTree) []Item {
	activeBytes, _ := os.ReadFile(p.prefPath)
	active := strings.TrimSpace(string(activeBytes))
	seen := map[string]bool{}
	for _, slug := range tree.Themes {
		seen[slug] = true
	}
	for _, slug := range scanLocalLockSlugs(p.themesDir) {
		seen[slug] = true
	}
	items := make([]Item, 0, len(seen))
	for slug := range seen {
		leaf := slug
		theme := ""
		if before, after, ok := strings.Cut(slug, "/"); ok {
			theme, leaf = displayLockPart(before), after
		}
		installed := lockFileExists(filepath.Join(p.themesDir, slug, "Main.qml"))
		art := ""
		if local := filepath.Join(p.themesDir, slug, "preview.gif"); installed && lockFileExists(local) {
			art = "file://" + local
		} else if gif, ok := mapThemeGif(slug, tree.Gifs); ok {
			if cached := p.previewCachePath(gif); lockFileExists(cached) {
				art = "file://" + cached
			} else {
				art = p.rawURL("Assets/" + gif + ".gif")
			}
		}
		sizeKB := tree.Bytes[slug] / 1024
		tags := []string(nil)
		if theme != "" {
			tags = []string{theme}
		}
		items = append(items, Item{
			ID:        slug,
			Category:  "lockscreens",
			Name:      displayLockPart(leaf),
			Art:       art,
			Tags:      tags,
			Installed: installed,
			Active:    slug == active,
			Metadata: map[string]any{
				"theme":  theme,
				"slug":   slug,
				"sizeKB": sizeKB,
			},
		})
	}
	sort.Slice(items, func(i, j int) bool {
		if items[i].Active != items[j].Active {
			return items[i].Active
		}
		if items[i].Installed != items[j].Installed {
			return items[i].Installed
		}
		return items[i].Name < items[j].Name
	})
	return items
}

func (p lockProvider) Load(ctx context.Context, refresh bool) ([]Item, SourceState, error) {
	tree, state, err := p.loadTree(ctx, refresh)
	if err != nil {
		local := p.normalize(qylockTree{Gifs: map[string]bool{}, Bytes: map[string]int{}})
		return local, state, nil
	}
	warmTimeout := p.warmTimeout
	if warmTimeout <= 0 {
		warmTimeout = lockWarmBudget
	}
	warmCtx, cancel := context.WithTimeout(ctx, warmTimeout)
	defer cancel()
	p.warmPreviews(warmCtx, tree, refresh)
	return p.normalize(tree), state, nil
}

func (p lockProvider) Install(ctx context.Context, slug string) error {
	if !validLocalPath(slug) {
		return fmt.Errorf("invalid lockscreen id %q", slug)
	}
	tree, _, err := p.loadTree(ctx, true)
	if err != nil {
		return fmt.Errorf("reach qylock: %w", err)
	}
	files := tree.Files[slug]
	if len(files) == 0 {
		return fmt.Errorf("unknown lockscreen %q", slug)
	}
	dst := filepath.Join(p.themesDir, slug)
	if err := rejectSymlinkPath(p.themesDir, slug); err != nil {
		return err
	}
	unlock, err := lockTree(dst)
	if err != nil {
		return err
	}
	defer unlock()
	if err := os.MkdirAll(filepath.Dir(dst), 0o755); err != nil {
		return err
	}
	stage, err := os.MkdirTemp(filepath.Dir(dst), ".stage-*")
	if err != nil {
		return err
	}
	defer os.RemoveAll(stage)
	for _, rel := range files {
		if err := p.downloadTo(ctx, p.rawURL("themes/"+slug+"/"+rel), filepath.Join(stage, rel), lockMaxFile); err != nil {
			return fmt.Errorf("download %s: %w", rel, err)
		}
	}
	if !lockFileExists(filepath.Join(stage, "Main.qml")) {
		return fmt.Errorf("lockscreen %q has no Main.qml", slug)
	}
	return replaceTree(stage, dst, nil)
}

func lockFileExists(path string) bool {
	_, err := os.Stat(path)
	return err == nil
}
