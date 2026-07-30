// The plugins provider adapts the ryoku-extras plugin registry into the store
// contract. It fetches the registry, enriches sparse entries from each plugin's
// manifest, and resolves relative preview art to absolute source URLs. Local
// state is joined in: installed from the plugin data dir, enabled from
// plugins.json placement, and update when the registry names a numerically newer
// version than the installed one. Install downloads the source without ever
// enabling the plugin; enable, placement, update, and removal stay with Ryoku
// Settings.
package main

import (
	"context"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strconv"
	"strings"
)

type pluginRegistryEntry struct {
	ID          string   `json:"id"`
	Name        string   `json:"name"`
	Tagline     string   `json:"tagline,omitempty"`
	Description string   `json:"description,omitempty"`
	Author      string   `json:"author,omitempty"`
	Official    bool     `json:"official,omitempty"`
	Tags        []string `json:"tags,omitempty"`
	Icon        string   `json:"icon,omitempty"`
	Screenshots []string `json:"screenshots,omitempty"`
	Preview     string   `json:"preview,omitempty"`
	Hosts       []string `json:"hosts,omitempty"`
	Path        string   `json:"path,omitempty"`
	Version     string   `json:"version,omitempty"`
}

type pluginRegistry struct {
	Version int                   `json:"version"`
	Plugins []pluginRegistryEntry `json:"plugins"`
}

type pluginProvider struct {
	cache *Cache
}

func (pluginProvider) Category() Category {
	return Category{
		ID:          "plugins",
		Name:        "Plugins",
		Group:       "EXTEND",
		Description: "Shell plugins that mount as widgets or frame popouts.",
	}
}

func (p pluginProvider) Load(ctx context.Context, refresh bool) ([]Item, SourceState, error) {
	raw, state, err := p.cache.Fetch(ctx, "plugins/registry.json", refresh)
	if err != nil {
		return nil, state, err
	}
	var reg pluginRegistry
	if err := json.Unmarshal(raw, &reg); err != nil {
		return nil, state, fmt.Errorf("plugins/registry.json: %w", err)
	}

	placements := readPluginPlacements()
	items := make([]Item, 0, len(reg.Plugins))
	for _, e := range reg.Plugins {
		path := e.Path
		if path == "" {
			path = "plugins/" + e.ID
		}
		name, desc, version := e.Name, e.Description, e.Version
		hosts, tags := e.Hosts, e.Tags
		// best-effort manifest enrichment: only fill what the registry omitted,
		// so a curated registry always wins.
		if b, st, err := p.cache.Fetch(ctx, path+"/manifest.json", refresh); err == nil {
			state = combineOffline(state, st)
			var man struct {
				Name        string   `json:"name"`
				Description string   `json:"description"`
				Hosts       []string `json:"hosts"`
				Tags        []string `json:"tags"`
				Version     string   `json:"version"`
			}
			if json.Unmarshal(b, &man) == nil {
				if name == "" {
					name = man.Name
				}
				if desc == "" {
					desc = man.Description
				}
				if len(hosts) == 0 {
					hosts = man.Hosts
				}
				if len(tags) == 0 {
					tags = man.Tags
				}
				if version == "" {
					version = man.Version
				}
			}
		}

		installedVer, installed := localPluginVersion(e.ID)
		pl, placed := placements[e.ID]
		enabled := placed && pl.Enabled
		update := installed && version != "" && installedVer != "" && semverNewer(version, installedVer)

		md := map[string]any{}
		if e.Official {
			md["official"] = true
		}
		if len(hosts) > 0 {
			md["hosts"] = hosts
		}
		if e.Icon != "" {
			md["icon"] = e.Icon
		}
		if installed && installedVer != "" {
			md["installedVersion"] = installedVer
		}
		if placed && pl.Host != "" {
			md["placement"] = pl.Host
		}
		if len(md) == 0 {
			md = nil
		}

		items = append(items, Item{
			ID:              e.ID,
			Category:        "plugins",
			Name:            name,
			Summary:         e.Tagline,
			Description:     desc,
			Art:             resolveAsset(extrasBase(), path, e.Preview),
			Author:          e.Author,
			Version:         version,
			Screenshots:     resolveAssets(extrasBase(), path, e.Screenshots),
			Tags:            tags,
			Installed:       installed,
			Enabled:         enabled,
			UpdateAvailable: update,
			Metadata:        md,
		})
	}
	return items, state, nil
}

func (p pluginProvider) Install(ctx context.Context, id string) error {
	_, err := ensurePlugin(id)
	return err
}

func configHome() string {
	if b := os.Getenv("XDG_CONFIG_HOME"); b != "" {
		return b
	}
	return filepath.Join(os.Getenv("HOME"), ".config")
}

// pluginPlacement is one plugin's entry in plugins.json: whether it is enabled
// and which host it is placed on. Ryostore reads this state; Settings owns it.
type pluginPlacement struct {
	Enabled bool   `json:"enabled"`
	Host    string `json:"host"`
}

func readPluginPlacements() map[string]pluginPlacement {
	b, err := os.ReadFile(filepath.Join(configHome(), "ryoku", "plugins.json"))
	if err != nil {
		return nil
	}
	var m map[string]pluginPlacement
	if json.Unmarshal(b, &m) != nil {
		return nil
	}
	return m
}

// localPluginVersion reads an installed plugin's version from its data-dir
// manifest, reporting installed=true whenever that manifest exists.
func localPluginVersion(id string) (string, bool) {
	b, err := os.ReadFile(filepath.Join(pluginDataDir(id), "manifest.json"))
	if err != nil {
		return "", false
	}
	var m struct {
		Version string `json:"version"`
	}
	_ = json.Unmarshal(b, &m)
	return m.Version, true
}

// resolveAsset turns a registry-relative asset path into an absolute source URL,
// passing an already-absolute http(s) URL through unchanged.
func resolveAsset(base, path, p string) string {
	if p == "" {
		return ""
	}
	if strings.HasPrefix(p, "http://") || strings.HasPrefix(p, "https://") {
		return p
	}
	return base + "/" + path + "/" + strings.TrimLeft(p, "/")
}

func resolveAssets(base, path string, ps []string) []string {
	if len(ps) == 0 {
		return nil
	}
	out := make([]string, len(ps))
	for i, s := range ps {
		out[i] = resolveAsset(base, path, s)
	}
	return out
}

// combineOffline folds a secondary fetch's state into the category's: any source
// served from the archive makes the category offline, keeping the first cache
// timestamp seen.
func combineOffline(base, extra SourceState) SourceState {
	if extra.Offline {
		base.Offline = true
		if base.CachedAt == "" {
			base.CachedAt = extra.CachedAt
		}
	}
	return base
}

// semverNewer reports whether version a is numerically greater than b, comparing
// dotted components left to right and ignoring any pre-release or build suffix.
func semverNewer(a, b string) bool {
	av, bv := parseSemver(a), parseSemver(b)
	n := len(av)
	if len(bv) > n {
		n = len(bv)
	}
	for i := range n {
		x, y := 0, 0
		if i < len(av) {
			x = av[i]
		}
		if i < len(bv) {
			y = bv[i]
		}
		if x != y {
			return x > y
		}
	}
	return false
}

func parseSemver(v string) []int {
	v = strings.TrimPrefix(strings.TrimSpace(v), "v")
	if i := strings.IndexAny(v, "-+"); i >= 0 {
		v = v[:i]
	}
	parts := strings.Split(v, ".")
	out := make([]int, len(parts))
	for i, p := range parts {
		n, _ := strconv.Atoi(strings.TrimSpace(p))
		out[i] = n
	}
	return out
}
