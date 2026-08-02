// The bar-style provider keeps Sumi built into the shell and adapts optional
// styles from the canonical extras registry into receipt-owned Store products.
package main

import (
	"context"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
)

const barStyleScene = "Scene.qml"

type barStyleIndexRow struct {
	ID      string `json:"id"`
	Version string `json:"version"`
	Scene   string `json:"scene"`
}

type barProvider struct {
	cache       *Cache
	shellConfig string
}

func newBarProvider(cache *Cache) barProvider {
	if cache == nil {
		cache = newCache()
	}
	return barProvider{
		cache:       cache,
		shellConfig: filepath.Join(configHome(), "ryoku", "shell.json"),
	}
}

func (barProvider) Category() Category {
	return Category{
		ID:          "barstyles",
		Name:        "Bar styles",
		Group:       "wear",
		Description: "Complete bar compositions for the Ryoku shell.",
	}
}

func (p barProvider) Load(ctx context.Context, refresh bool) ([]Item, SourceState, error) {
	entries, state, err := loadProductRegistry(ctx, p.cache, "barstyles", refresh)
	if err != nil {
		return nil, state, err
	}
	active := p.activeStyle()
	items := make([]Item, 0, len(entries)+1)
	items = append(items, Item{
		ID: "sumi", Category: "barstyles", Name: "Sumi",
		Summary:     "Ink spine",
		Description: "The built-in left rail: paper, ink, and a vertical working edge.",
		Tags:        []string{"rail", "vertical", "built-in"},
		Installed:   true,
		Metadata:    map[string]any{"scene": "", "core": true},
	})
	activeInstalled := false
	for _, entry := range entries {
		item, err := productEntryItem(p.cache.base, "barstyles", entry)
		if err != nil {
			return nil, state, fmt.Errorf("barstyles/%s: installed state: %w", entry.ID, err)
		}
		item.Active = item.Installed && entry.ID == active
		activeInstalled = activeInstalled || item.Active
		if item.Metadata == nil {
			item.Metadata = map[string]any{}
		}
		item.Metadata["scene"] = barStyleScene
		items = append(items, item)
	}
	items[0].Active = !activeInstalled
	if err := writeBarStyleIndex(entries); err != nil {
		return nil, state, err
	}
	return items, state, nil
}

func (p barProvider) Install(ctx context.Context, id string) error {
	if id == "sumi" {
		return fmt.Errorf("the built-in Sumi bar style is already installed")
	}
	entries, _, err := loadProductRegistry(ctx, p.cache, "barstyles", false)
	if err != nil {
		return err
	}
	entry, err := findProductEntry(entries, id)
	if err != nil {
		return err
	}
	if err := installProduct(ctx, p.cache, "barstyles", entry); err != nil {
		return err
	}
	return writeBarStyleIndex(entries)
}

func (p barProvider) Remove(ctx context.Context, id string) error {
	if id == "sumi" {
		return fmt.Errorf("the built-in Sumi bar style is not removable")
	}
	entries, _, err := loadProductRegistry(ctx, p.cache, "barstyles", false)
	if err != nil {
		return err
	}
	if _, err := findProductEntry(entries, id); err != nil {
		return err
	}
	if err := removeProduct(ctx, "barstyles", id); err != nil {
		return err
	}
	if err := writeBarStyleIndex(entries); err != nil {
		return err
	}
	if p.activeStyle() == id {
		if err := writeBarStyleSelection(p.shellConfig, "sumi"); err != nil {
			return fmt.Errorf("bar style removed but Sumi fallback could not be saved: %w", err)
		}
	}
	return nil
}

func barStyleIndexPath() string {
	return filepath.Join(storeStateDir(), "barstyles.json")
}

func writeBarStyleIndex(entries []ProductEntry) error {
	rows := make([]barStyleIndexRow, 0, len(entries))
	for _, entry := range entries {
		receipt, err := readReceipt("barstyles", entry.ID)
		if os.IsNotExist(err) {
			continue
		}
		if err != nil {
			return err
		}
		dst, _, err := productDestination("barstyles", entry.ID)
		if err != nil {
			return err
		}
		if !receiptOwnsFile(receipt, barStyleScene) || !isRegularFile(filepath.Join(dst, barStyleScene)) {
			return fmt.Errorf("barstyles/%s: installed scene is missing", entry.ID)
		}
		rows = append(rows, barStyleIndexRow{ID: entry.ID, Version: receipt.Version, Scene: barStyleScene})
	}
	raw, err := json.Marshal(rows)
	if err != nil {
		return err
	}
	return atomicWrite(barStyleIndexPath(), append(raw, '\n'), 0o600)
}

func receiptOwnsFile(receipt Receipt, destination string) bool {
	for _, file := range receipt.Files {
		if file.Destination == destination {
			return true
		}
	}
	return false
}

func writeBarStyleSelection(path, id string) error {
	state := map[string]any{}
	if raw, err := os.ReadFile(path); err == nil {
		if err := decodeOneJSON(raw, &state); err != nil {
			return fmt.Errorf("parse shell config: %w", err)
		}
		if state == nil {
			return fmt.Errorf("parse shell config: root must be an object")
		}
	} else if !os.IsNotExist(err) {
		return err
	}
	state["barStyle"] = id
	raw, err := json.MarshalIndent(state, "", "  ")
	if err != nil {
		return err
	}
	return atomicWrite(path, append(raw, '\n'), 0o644)
}

func (p barProvider) activeStyle() string {
	raw, err := os.ReadFile(p.shellConfig)
	if err != nil {
		return ""
	}
	var state struct {
		BarStyle string `json:"barStyle"`
	}
	if decodeOneJSON(raw, &state) != nil {
		return ""
	}
	return state.BarStyle
}
