package main

import (
	"context"
	"errors"
	"strings"
	"testing"
)

// fakeProvider stands in for a real catalogue source so BuildCatalog can be
// exercised without network or disk: it returns canned items, source state, and
// an optional error.
type fakeProvider struct {
	category Category
	items    []Item
	state    SourceState
	err      error
}

func (f fakeProvider) Category() Category { return f.category }
func (f fakeProvider) Load(context.Context, bool) ([]Item, SourceState, error) {
	return f.items, f.state, f.err
}
func (f fakeProvider) Install(context.Context, string) error { return nil }

func TestBuildCatalogIsolatesProviderFailure(t *testing.T) {
	providers := []Provider{
		fakeProvider{category: Category{ID: "plugins", Name: "Plugins", Group: "extend"}, items: []Item{{ID: "market", Category: "plugins", Installed: true}}},
		fakeProvider{category: Category{ID: "locks", Name: "Lockscreens", Group: "wear"}, err: errors.New("offline")},
	}
	got := BuildCatalog(context.Background(), providers, false)
	if len(got.Items) != 1 || got.Items[0].ID != "market" {
		t.Fatalf("items = %#v", got.Items)
	}
	if got.Categories[0].InstalledCount != 1 {
		t.Fatalf("installed = %d", got.Categories[0].InstalledCount)
	}
	if got.Categories[1].Error != "offline" {
		t.Fatalf("error = %q", got.Categories[1].Error)
	}
}

// TestBuildCatalogCountsAndOffline feeds one active, one enabled, one partially
// installed bundle, and one available item through a single offline source, and
// asserts the derived category counts and the catalogue-wide offline flag.
func TestBuildCatalogCountsAndOffline(t *testing.T) {
	providers := []Provider{
		fakeProvider{
			category: Category{ID: "rices", Name: "Rices", Group: "wear"},
			items: []Item{
				{ID: "worn", Category: "rices", Installed: true, Active: true},
				{ID: "running", Category: "rices", Installed: true, Enabled: true},
				{ID: "starter", Category: "rices", InstalledCount: 2, TotalCount: 3},
				{ID: "browse", Category: "rices"},
			},
			state: SourceState{Offline: true, CachedAt: "2026-07-01T00:00:00Z"},
		},
	}
	got := BuildCatalog(context.Background(), providers, false)
	if len(got.Items) != 4 {
		t.Fatalf("items = %d, want 4", len(got.Items))
	}
	cat := got.Categories[0]
	if cat.Count != 4 {
		t.Fatalf("count = %d, want 4", cat.Count)
	}
	if cat.InstalledCount != 3 {
		t.Fatalf("installedCount = %d, want 3 (active, enabled, partial bundle)", cat.InstalledCount)
	}
	if !cat.Offline || cat.CachedAt != "2026-07-01T00:00:00Z" {
		t.Fatalf("offline state not carried onto category: %+v", cat)
	}
	if !got.Offline {
		t.Fatalf("catalogue should aggregate offline from its sources")
	}
}

func TestFilterCategory(t *testing.T) {
	cat := Catalog{
		Categories: []Category{{ID: "plugins", Name: "Plugins"}, {ID: "rices", Name: "Rices"}},
		Items: []Item{
			{ID: "market", Category: "plugins"},
			{ID: "nord", Category: "rices"},
			{ID: "clock", Category: "plugins"},
		},
	}
	got, ok := filterCategory(cat, "plugins")
	if !ok {
		t.Fatal("plugins category should be found")
	}
	if len(got.Categories) != 1 || got.Categories[0].ID != "plugins" {
		t.Fatalf("categories = %#v", got.Categories)
	}
	if len(got.Items) != 2 {
		t.Fatalf("items = %#v", got.Items)
	}
	if _, ok := filterCategory(cat, "bundles"); ok {
		t.Fatal("unknown category must report ok=false")
	}
}

// TestDispatchErrors covers the argument and category errors the CLI must
// surface: every one returns a non-nil error carrying a useful phrase.
func TestDispatchErrors(t *testing.T) {
	cases := []struct {
		name string
		args []string
		want string
	}{
		{"no command", nil, "no command"},
		{"unknown command", []string{"wibble"}, "unknown command"},
		{"install too few args", []string{"install", "plugins"}, "install needs"},
		{"install unknown category", []string{"install", "nope", "x"}, "unknown category"},
		{"catalog unknown flag", []string{"catalog", "--wat"}, "unknown catalog flag"},
		{"catalog category needs value", []string{"catalog", "--category"}, "needs"},
		{"catalog unknown category", []string{"catalog", "--category", "nope"}, "unknown category"},
		{"internal needs subcommand", []string{"internal"}, "internal needs"},
		{"internal unknown subcommand", []string{"internal", "frobnicate"}, "unknown internal command"},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			err := dispatch(tc.args)
			if err == nil {
				t.Fatalf("args %v: want an error", tc.args)
			}
			if !strings.Contains(err.Error(), tc.want) {
				t.Fatalf("args %v: error %q, want substring %q", tc.args, err, tc.want)
			}
		})
	}
}
