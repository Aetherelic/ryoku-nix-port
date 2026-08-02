// The Fastfetch provider keeps the future category honest: an uncached 404 is
// an empty catalogue, while a real registry is normalized without relabelling
// the current editable readout as a downloadable style.
package main

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"os"
	"path/filepath"
	"regexp"
	"strings"
)

type fastfetchRegistryEntry struct {
	ID          string   `json:"id"`
	Name        string   `json:"name"`
	Summary     string   `json:"summary,omitempty"`
	Description string   `json:"description,omitempty"`
	Preview     string   `json:"preview,omitempty"`
	Author      string   `json:"author,omitempty"`
	Version     string   `json:"version,omitempty"`
	Tags        []string `json:"tags,omitempty"`
}

type fastfetchRegistry struct {
	Version int                      `json:"version"`
	Styles  []fastfetchRegistryEntry `json:"styles"`
}

type fastfetchProvider struct {
	cache      *Cache
	configPath string
}

func newFastfetchProvider(cache *Cache) fastfetchProvider {
	return fastfetchProvider{
		cache:      cache,
		configPath: filepath.Join(configHome(), "fastfetch", "config.jsonc"),
	}
}

func (fastfetchProvider) Category() Category {
	return Category{
		ID:          "fastfetch",
		Name:        "Fastfetch",
		Group:       "wear",
		Description: "Downloadable terminal dossiers will appear here when their registry opens.",
	}
}

func (p fastfetchProvider) Load(ctx context.Context, refresh bool) ([]Item, SourceState, error) {
	raw, state, err := p.cache.Fetch(ctx, "fastfetch/registry.json", refresh)
	if err != nil {
		var status *HTTPStatusError
		if errors.As(err, &status) && status.Status == http.StatusNotFound {
			return []Item{}, SourceState{}, nil
		}
		return nil, state, err
	}
	var registry fastfetchRegistry
	if err := json.Unmarshal(raw, &registry); err != nil {
		return nil, state, fmt.Errorf("parse fastfetch registry: %w", err)
	}
	active := p.activeStyle()
	items := make([]Item, 0, len(registry.Styles))
	for _, entry := range registry.Styles {
		if !validComponent(entry.ID) {
			return nil, state, fmt.Errorf("invalid fastfetch style id %q", entry.ID)
		}
		installed := active != "" && entry.ID == active
		items = append(items, Item{
			ID:          entry.ID,
			Category:    "fastfetch",
			Name:        entry.Name,
			Summary:     entry.Summary,
			Description: entry.Description,
			Art:         fastfetchAssetURL(p.cache.base, entry.Preview),
			Author:      entry.Author,
			Version:     entry.Version,
			Tags:        entry.Tags,
			Installed:   installed,
			Active:      installed,
		})
	}
	return items, state, nil
}

func fastfetchAssetURL(base, path string) string {
	if path == "" {
		return ""
	}
	return strings.TrimRight(base, "/") + "/" + strings.TrimLeft(path, "/")
}

func (fastfetchProvider) Install(context.Context, string) error {
	return fmt.Errorf("Fastfetch style installation is unavailable until the catalogue opens")
}

var fastfetchStylePattern = regexp.MustCompile(`(?m)"style"\s*:\s*"([^"\\]+)"`)

func (p fastfetchProvider) activeStyle() string {
	raw, err := os.ReadFile(p.configPath)
	if err != nil {
		return ""
	}
	match := fastfetchStylePattern.FindSubmatch(raw)
	if len(match) != 2 {
		return ""
	}
	return string(match[1])
}
