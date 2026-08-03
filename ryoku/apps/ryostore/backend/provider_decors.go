// The decors provider adapts the ryoku-extras "decors" registry into the Store
// contract. A decor is a single curated image the user drops into the Hub's
// decor gallery (~/Pictures/ryodecors), so unlike the tree-installed categories
// it owns exactly one flat file per product, named by the product id, and its
// installed state is simply whether that file exists. Each product ships a raw
// and a pre-baked dithered variant; the store's dither toggle picks which one
// lands.
package main

import (
	"context"
	"fmt"
	"os"
	"path"
	"path/filepath"
	"sort"
)

type decorProvider struct {
	cache   *Cache
	dirPath string
}

func newDecorProvider(cache *Cache) decorProvider {
	if cache == nil {
		cache = newCache()
	}
	return decorProvider{cache: cache, dirPath: filepath.Join(picturesHome(), "ryodecors")}
}

func (decorProvider) Category() Category {
	return Category{
		ID:          "decors",
		Name:        "Decors",
		Group:       "make",
		Description: "Curated specimen art for the empty spaces across the Ryoku hub and apps.",
	}
}

// installedPath is the flat file a decor owns in the gallery folder. The Hub's
// Decor and Placard components list that folder by bare filename, so a store
// install appears there with no further wiring.
func (p decorProvider) installedPath(id string) string {
	return filepath.Join(p.dirPath, id+".png")
}

func (p decorProvider) Load(ctx context.Context, refresh bool) ([]Item, SourceState, error) {
	entries, state, err := loadProductRegistry(ctx, p.cache, "decors", refresh)
	if err != nil {
		return nil, state, err
	}
	items := make([]Item, 0, len(entries))
	for _, entry := range entries {
		item, err := productEntryItem(p.cache.base, "decors", entry)
		if err != nil {
			return nil, state, err
		}
		// The raw (undithered) preview so the store's dither toggle can show both looks.
		item.ArtRaw = resolveAsset(p.cache.base, entry.Path, entry.PreviewRaw)
		// A decor owns one flat file; its presence is the whole install record.
		if _, statErr := os.Stat(p.installedPath(entry.ID)); statErr == nil {
			item.Installed = true
			item.InstalledVersion = entry.Version
			item.UpdateAvailable = false
		}
		items = append(items, item)
	}
	sort.SliceStable(items, func(i, j int) bool {
		if items[i].Installed != items[j].Installed {
			return items[i].Installed
		}
		return items[i].Name < items[j].Name
	})
	return items, state, nil
}

func (p decorProvider) Install(ctx context.Context, id string) error {
	return p.InstallVariant(ctx, id, false)
}

// InstallVariant copies the chosen variant (dithered or raw) of a decor into the
// gallery folder as one flat file. Both variants are PNG, so the installed file
// is always <id>.png regardless of the toggle.
func (p decorProvider) InstallVariant(ctx context.Context, id string, dither bool) error {
	entries, _, err := loadProductRegistry(ctx, p.cache, "decors", false)
	if err != nil {
		return err
	}
	entry, err := findProductEntry(entries, id)
	if err != nil {
		return err
	}
	variant := "source.png"
	if dither {
		variant = "dither.png"
	}
	data, _, err := p.cache.Fetch(ctx, path.Join(entry.Path, "content", variant), true)
	if err != nil {
		return fmt.Errorf("decors/%s: fetch %s: %w", id, variant, err)
	}
	if err := os.MkdirAll(p.dirPath, 0o755); err != nil {
		return err
	}
	return atomicWrite(p.installedPath(id), data, 0o644)
}

func (p decorProvider) Remove(_ context.Context, id string) error {
	if !productIDPattern.MatchString(id) {
		return fmt.Errorf("invalid decor id %q", id)
	}
	if err := os.Remove(p.installedPath(id)); err != nil && !os.IsNotExist(err) {
		return err
	}
	return nil
}

// picturesHome mirrors the Hub's Ryodecors singleton, which resolves the gallery
// at ~/Pictures/ryodecors, so an installed decor lands exactly where the gallery
// reads it.
func picturesHome() string {
	return filepath.Join(os.Getenv("HOME"), "Pictures")
}
