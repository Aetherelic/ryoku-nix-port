// The bar-style provider exposes the manifests shipped with the shell. Bar
// Studio owns activation and configuration; every valid local manifest is an
// installed store item.
package main

import (
	"context"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strings"
)

type barManifest struct {
	ID          string   `json:"id"`
	Name        string   `json:"name"`
	Summary     string   `json:"summary"`
	Description string   `json:"description"`
	Scene       string   `json:"scene"`
	Tags        []string `json:"tags,omitempty"`
	Preview     string   `json:"preview,omitempty"`
}

type barProvider struct {
	root        string
	shellConfig string
}

func newBarProvider() barProvider {
	return barProvider{
		root:        filepath.Join(configHome(), "quickshell", "pill", "barstyles"),
		shellConfig: filepath.Join(configHome(), "ryoku", "shell.json"),
	}
}

func (barProvider) Category() Category {
	return Category{
		ID:          "barstyles",
		Name:        "Bar styles",
		Group:       "wear",
		Description: "Shipped frame and bar compositions for the Ryoku shell.",
	}
}

func (p barProvider) Load(context.Context, bool) ([]Item, SourceState, error) {
	entries, err := os.ReadDir(p.root)
	if err != nil {
		return nil, SourceState{}, fmt.Errorf("scan bar styles: %w", err)
	}
	active := p.activeStyle()
	items := make([]Item, 0, len(entries))
	for _, dir := range entries {
		if !dir.IsDir() {
			continue
		}
		manifestPath := filepath.Join(p.root, dir.Name(), "manifest.json")
		raw, err := os.ReadFile(manifestPath)
		if os.IsNotExist(err) {
			continue
		}
		if err != nil {
			return nil, SourceState{}, fmt.Errorf("read %s: %w", manifestPath, err)
		}
		var manifest barManifest
		if err := json.Unmarshal(raw, &manifest); err != nil {
			return nil, SourceState{}, fmt.Errorf("parse %s: %w", manifestPath, err)
		}
		if !validComponent(manifest.ID) || manifest.ID != dir.Name() {
			return nil, SourceState{}, fmt.Errorf("bar manifest id %q does not match directory %q", manifest.ID, dir.Name())
		}
		if manifest.Name == "" {
			return nil, SourceState{}, fmt.Errorf("bar manifest %q has no name", manifest.ID)
		}
		if manifest.Scene != "" {
			scene := strings.TrimPrefix(filepath.ToSlash(manifest.Scene), "barstyles/")
			if !validLocalPath(filepath.FromSlash(scene)) || !isRegularFile(filepath.Join(p.root, filepath.FromSlash(scene))) {
				return nil, SourceState{}, fmt.Errorf("bar style %q scene %q is missing", manifest.ID, manifest.Scene)
			}
		}
		art := ""
		if manifest.Preview != "" {
			preview := filepath.FromSlash(manifest.Preview)
			if !validLocalPath(preview) {
				return nil, SourceState{}, fmt.Errorf("bar style %q has invalid preview %q", manifest.ID, manifest.Preview)
			}
			if !filepath.IsAbs(preview) {
				preview = filepath.Join(filepath.Dir(manifestPath), preview)
			}
			if isRegularFile(preview) {
				art = "file://" + preview
			}
		}
		items = append(items, Item{
			ID:          manifest.ID,
			Category:    "barstyles",
			Name:        manifest.Name,
			Summary:     manifest.Summary,
			Description: manifest.Description,
			Art:         art,
			Tags:        manifest.Tags,
			Installed:   true,
			Active:      manifest.ID == active,
			Metadata:    map[string]any{"scene": manifest.Scene},
		})
	}
	return items, SourceState{}, nil
}

func (barProvider) Install(context.Context, string) error {
	return fmt.Errorf("bar styles ship with Ryoku and are managed in Ryoku Settings")
}

func (p barProvider) activeStyle() string {
	raw, err := os.ReadFile(p.shellConfig)
	if err != nil {
		return ""
	}
	var state struct {
		BarStyle string `json:"barStyle"`
	}
	if json.Unmarshal(raw, &state) != nil {
		return ""
	}
	return state.BarStyle
}
