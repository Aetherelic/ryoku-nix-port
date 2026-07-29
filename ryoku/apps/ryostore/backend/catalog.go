package main

import (
	"context"
	"sync"
	"time"
)

// Provider is one product catalogue. Load fetches and normalizes the category's
// items, reporting its source state or an error that stays isolated to that
// category. Install fetches an item onto the machine without activating it.
// refresh bypasses any fresh in-process cache.
type Provider interface {
	Category() Category
	Load(ctx context.Context, refresh bool) ([]Item, SourceState, error)
	Install(ctx context.Context, id string) error
}

// providers is the ordered catalogue registry in rail order. Each later task
// appends its provider here; BuildCatalog preserves this order. It is empty
// until the first provider lands.
func providers() []Provider { return nil }

// owned reports whether the item is present on the machine: fully installed, or
// a partially installed bundle. A category's InstalledCount tallies its owned
// items.
func (it *Item) owned() bool { return it.Installed || it.InstalledCount > 0 }

// BuildCatalog probes every provider concurrently and folds the results into one
// catalogue in provider order. Each goroutine writes only its own result slot,
// so a slow or failing source neither blocks nor aborts the others: its error
// lands in that one category and the rest still render. Counts are derived after
// all sources settle.
func BuildCatalog(ctx context.Context, provs []Provider, refresh bool) Catalog {
	type result struct {
		items []Item
		state SourceState
		err   error
	}
	results := make([]result, len(provs))
	var wg sync.WaitGroup
	for i, p := range provs {
		wg.Add(1)
		go func() {
			defer wg.Done()
			items, state, err := p.Load(ctx, refresh)
			results[i] = result{items, state, err}
		}()
	}
	wg.Wait()

	cat := Catalog{
		GeneratedAt: time.Now().UTC().Format(time.RFC3339),
		Categories:  make([]Category, len(provs)),
		Items:       []Item{},
	}
	for i, p := range provs {
		c := p.Category()
		r := results[i]
		c.Offline = r.state.Offline
		c.CachedAt = r.state.CachedAt
		if r.err != nil {
			c.Error = r.err.Error()
		} else {
			c.Count = len(r.items)
			for j := range r.items {
				if r.items[j].owned() {
					c.InstalledCount++
				}
			}
			cat.Items = append(cat.Items, r.items...)
		}
		if c.Offline || c.Error != "" {
			cat.Offline = true
		}
		cat.Categories[i] = c
	}
	return cat
}

// filterCategory narrows a catalogue to one category and its items for the
// `catalog --category <id>` view. ok is false when no such category exists, so
// the caller can report an unknown category.
func filterCategory(cat Catalog, id string) (Catalog, bool) {
	for _, c := range cat.Categories {
		if c.ID != id {
			continue
		}
		out := Catalog{
			GeneratedAt: cat.GeneratedAt,
			Offline:     c.Offline || c.Error != "",
			Categories:  []Category{c},
			Items:       []Item{},
		}
		for _, it := range cat.Items {
			if it.Category == id {
				out.Items = append(out.Items, it)
			}
		}
		return out, true
	}
	return cat, false
}
