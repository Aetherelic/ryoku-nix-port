package main

import (
	"bytes"
	"encoding/json"
	"testing"
)

func TestCatalogRevisionIgnoresOrderAndVolatileState(t *testing.T) {
	items := []Item{
		{Category: "rices", ID: "a", Version: "1", ManifestSHA256: "x"},
		{Category: "plugins", ID: "b", Version: "2", ManifestSHA256: "y"},
	}
	base := catalogRevision(Catalog{Items: items})

	reordered := catalogRevision(Catalog{Items: []Item{items[1], items[0]}})
	if reordered != base {
		t.Fatalf("item order must not change revision: %s vs %s", reordered, base)
	}

	volatile := catalogRevision(Catalog{
		GeneratedAt: "2099-01-01T00:00:00Z",
		Offline:     true,
		Items: []Item{
			{Category: "rices", ID: "a", Version: "1", ManifestSHA256: "x", Installed: true, Active: true},
			{Category: "plugins", ID: "b", Version: "2", ManifestSHA256: "y", UpdateAvailable: true},
		},
	})
	if volatile != base {
		t.Fatal("generatedAt, offline, and install state must not change revision")
	}
}

func TestCatalogRevisionChangesOnRealContentChange(t *testing.T) {
	base := catalogRevision(Catalog{Items: []Item{
		{Category: "rices", ID: "a", Version: "1", ManifestSHA256: "x"},
	}})
	cases := map[string]Catalog{
		"version bump":    {Items: []Item{{Category: "rices", ID: "a", Version: "2", ManifestSHA256: "x"}}},
		"manifest digest": {Items: []Item{{Category: "rices", ID: "a", Version: "1", ManifestSHA256: "z"}}},
		"new item": {Items: []Item{
			{Category: "rices", ID: "a", Version: "1", ManifestSHA256: "x"},
			{Category: "decors", ID: "c", Version: "1"},
		}},
	}
	for name, cat := range cases {
		if catalogRevision(cat) == base {
			t.Fatalf("%s must change the revision", name)
		}
	}
}

func TestSeenRevisionRoundTrip(t *testing.T) {
	t.Setenv("RYOKU_EXTRAS_BASE", "")
	t.Setenv("XDG_CONFIG_HOME", t.TempDir())
	t.Setenv("XDG_CACHE_HOME", t.TempDir())

	if got := readSeenRevision(); got != "" {
		t.Fatalf("no seen revision expected initially, got %q", got)
	}
	writeSeenRevision("deadbeef")
	if got := readSeenRevision(); got != "deadbeef" {
		t.Fatalf("seen revision = %q, want deadbeef", got)
	}
}

func TestRunCheckFlagsUpdateOnlyPastSeen(t *testing.T) {
	t.Setenv("RYOKU_EXTRAS_BASE", "")
	t.Setenv("XDG_CONFIG_HOME", t.TempDir())
	t.Setenv("XDG_CACHE_HOME", t.TempDir())

	provsV1 := []Provider{fakeProvider{
		category: Category{ID: "rices", Name: "Rices"},
		items:    []Item{{ID: "a", Category: "rices", Version: "1"}},
	}}
	decode := func(provs []Provider) struct {
		Revision        string `json:"revision"`
		UpdateAvailable bool   `json:"updateAvailable"`
		Offline         bool   `json:"offline"`
	} {
		var buf bytes.Buffer
		if err := runCheck(&buf, provs); err != nil {
			t.Fatalf("runCheck: %v", err)
		}
		var out struct {
			Revision        string `json:"revision"`
			UpdateAvailable bool   `json:"updateAvailable"`
			Offline         bool   `json:"offline"`
		}
		if err := json.Unmarshal(buf.Bytes(), &out); err != nil {
			t.Fatalf("decode: %v", err)
		}
		return out
	}

	// No baseline yet: never claim an update the user has never acknowledged.
	first := decode(provsV1)
	if first.UpdateAvailable {
		t.Fatal("no update should be flagged before any revision is seen")
	}

	// Acknowledge the current revision: check now reports no update.
	writeSeenRevision(first.Revision)
	if decode(provsV1).UpdateAvailable {
		t.Fatal("no update when the live revision equals the seen revision")
	}

	// Upstream advances past the seen revision: the dot lights.
	provsV2 := []Provider{fakeProvider{
		category: Category{ID: "rices", Name: "Rices"},
		items:    []Item{{ID: "a", Category: "rices", Version: "2"}},
	}}
	if !decode(provsV2).UpdateAvailable {
		t.Fatal("update must be flagged when the revision advances past seen")
	}
}
