// The bundles provider adapts the ryoku-extras bundle registry into the store
// contract. It fetches the registry, merges each bundle.json, resolves art, and
// warms every script item's installer into the cache. Installed state is joined
// from `ryoku-extras-install status`, run only after the caches it reads exist:
// partial counts are first-class, and a bundle is installed only when every item
// is present. Install launches the actuator in a floating terminal, which owns
// the privileged package work; Settings owns installed bundle status and removal.
package main

import (
	"context"
	"encoding/json"
	"fmt"
	"os/exec"
	"syscall"
)

type registryEntry struct {
	ID          string   `json:"id"`
	Name        string   `json:"name"`
	Description string   `json:"description"`
	Tagline     string   `json:"tagline,omitempty"`
	Sources     string   `json:"sources,omitempty"`
	Icon        string   `json:"icon,omitempty"`
	Accent      string   `json:"accent,omitempty"`
	Preview     string   `json:"preview,omitempty"`
	Screenshots []string `json:"screenshots,omitempty"`
	Path        string   `json:"path"`
}

type registry struct {
	Version int             `json:"version"`
	Bundles []registryEntry `json:"bundles"`
}

type bundleItem struct {
	Type        string `json:"type"`
	Name        string `json:"name"`
	Detect      string `json:"detect,omitempty"`
	Summary     string `json:"summary,omitempty"`
	Source      string `json:"source,omitempty"`
	Upstream    string `json:"upstream,omitempty"`
	Tier        string `json:"tier,omitempty"`
	Interactive bool   `json:"interactive,omitempty"`
}

type bundleDef struct {
	ID          string       `json:"id"`
	Name        string       `json:"name"`
	Description string       `json:"description"`
	Icon        string       `json:"icon,omitempty"`
	Accent      string       `json:"accent,omitempty"`
	Preview     string       `json:"preview,omitempty"`
	Screenshots []string     `json:"screenshots,omitempty"`
	Items       []bundleItem `json:"items"`
}

type bundleProvider struct {
	cache  *Cache
	status func(context.Context) map[string]map[string]bool
	launch func(id string) error
}

func (bundleProvider) Category() Category {
	return Category{
		ID:          "bundles",
		Name:        "Bundles",
		Group:       "EXTEND",
		Description: "Curated sets of packages, scripts, and guests installed together.",
	}
}

func (p bundleProvider) Load(ctx context.Context, refresh bool) ([]Item, SourceState, error) {
	raw, state, err := p.cache.Fetch(ctx, "bundles/registry.json", refresh)
	if err != nil {
		return nil, state, err
	}
	var reg registry
	if err := json.Unmarshal(raw, &reg); err != nil {
		return nil, state, fmt.Errorf("bundles/registry.json: %w", err)
	}

	type built struct {
		item  Item
		items []bundleItem
	}
	out := make([]built, 0, len(reg.Bundles))
	for _, e := range reg.Bundles {
		if !validComponent(e.ID) {
			return nil, state, fmt.Errorf("bundle has invalid id %q", e.ID)
		}
		path := e.Path
		if path == "" {
			path = "bundles/" + e.ID
		}
		if !validLocalPath(path) {
			return nil, state, fmt.Errorf("bundle %q has invalid path %q", e.ID, path)
		}
		name, desc := e.Name, e.Description
		icon, accent, preview := e.Icon, e.Accent, e.Preview
		screenshots := e.Screenshots
		b, st, err := p.cache.Fetch(ctx, path+"/bundle.json", refresh)
		state = combineOffline(state, st)
		if err != nil {
			return nil, state, fmt.Errorf("bundle %q definition: %w", e.ID, err)
		}
		var def bundleDef
		if err := json.Unmarshal(b, &def); err != nil {
			return nil, state, fmt.Errorf("bundle %q definition: %w", e.ID, err)
		}
		if def.ID != "" && def.ID != e.ID {
			return nil, state, fmt.Errorf("bundle %q definition id is %q", e.ID, def.ID)
		}
		if len(def.Items) == 0 {
			return nil, state, fmt.Errorf("bundle %q definition has no items", e.ID)
		}
		items := def.Items
		if name == "" {
			name = def.Name
		}
		if desc == "" {
			desc = def.Description
		}
		if icon == "" {
			icon = def.Icon
		}
		if accent == "" {
			accent = def.Accent
		}
		if preview == "" {
			preview = def.Preview
		}
		if len(screenshots) == 0 {
			screenshots = def.Screenshots
		}
		for _, it := range items {
			if it.Type == "script" {
				if !validComponent(it.Name) {
					return nil, state, fmt.Errorf("bundle %q has invalid installer name %q", e.ID, it.Name)
				}
				if _, _, err := p.cache.Fetch(ctx, "installers/"+it.Name+".sh", refresh); err != nil {
					return nil, state, fmt.Errorf("bundle %q installer %q: %w", e.ID, it.Name, err)
				}
			}
		}

		md := map[string]any{}
		if e.Sources != "" {
			md["sources"] = e.Sources
		}
		if icon != "" {
			md["icon"] = icon
		}
		if accent != "" {
			md["accent"] = accent
		}
		if len(items) > 0 {
			comps := make([]map[string]any, len(items))
			for i, it := range items {
				comp := map[string]any{"type": it.Type, "name": it.Name}
				if it.Summary != "" {
					comp["summary"] = it.Summary
				}
				if it.Tier != "" {
					comp["tier"] = it.Tier
				}
				comps[i] = comp
			}
			md["items"] = comps
		}
		if len(md) == 0 {
			md = nil
		}

		out = append(out, built{
			item: Item{
				ID:          e.ID,
				Category:    "bundles",
				Name:        name,
				Summary:     e.Tagline,
				Description: desc,
				Art:         resolveAsset(extrasBase(), path, preview),
				Screenshots: resolveAssets(extrasBase(), path, screenshots),
				TotalCount:  len(items),
				Metadata:    md,
			},
			items: items,
		})
	}

	// join installed state now the registry + bundle caches the actuator reads
	// exist. A missing or failed status source degrades to nothing installed.
	var status map[string]map[string]bool
	if p.status != nil {
		status = p.status(ctx)
	}
	items := make([]Item, len(out))
	for i, b := range out {
		it := b.item
		present := status[it.ID]
		for _, comp := range b.items {
			if present[comp.Name] {
				it.InstalledCount++
			}
		}
		it.Installed = it.TotalCount > 0 && it.InstalledCount == it.TotalCount
		items[i] = it
	}
	return items, state, nil
}

func (p bundleProvider) Install(ctx context.Context, id string) error {
	return p.launch(id)
}

// defaultBundleStatus queries the actuator for every bundle's item state and
// indexes it by bundle id then item name. Any failure yields no status rather
// than an error, so a broken actuator cannot blank the catalogue.
func defaultBundleStatus(ctx context.Context) map[string]map[string]bool {
	out, err := exec.CommandContext(ctx, "ryoku-extras-install", "status").Output()
	if err != nil {
		return nil
	}
	var parsed struct {
		Bundles []struct {
			ID    string `json:"id"`
			Items []struct {
				Name   string `json:"name"`
				Status string `json:"status"`
			} `json:"items"`
		} `json:"bundles"`
	}
	if json.Unmarshal(out, &parsed) != nil {
		return nil
	}
	m := make(map[string]map[string]bool, len(parsed.Bundles))
	for _, b := range parsed.Bundles {
		present := make(map[string]bool, len(b.Items))
		for _, it := range b.Items {
			present[it.Name] = it.Status == "present"
		}
		m[b.ID] = present
	}
	return m
}

// launchBundleInstall runs the actuator's bundle install in a floating kitty
// terminal, detached into its own session so it owns the sudo prompt and
// long-running output independently of this short-lived process.
func launchBundleInstall(id string) error {
	cmd := exec.Command("kitty", "--class", "ryoku-extras", "-e", "ryoku-extras-install", "install", "bundle", id)
	cmd.SysProcAttr = &syscall.SysProcAttr{Setsid: true}
	if err := cmd.Start(); err != nil {
		return err
	}
	return cmd.Process.Release()
}
