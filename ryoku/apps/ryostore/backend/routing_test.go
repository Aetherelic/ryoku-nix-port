package main

import "testing"

func TestSettingsSectionRoutesStoreCategories(t *testing.T) {
	cases := map[string]string{
		"rices":       "appearance",
		"lockscreens": "lockscreen",
		"plugins":     "addons",
		"bundles":     "addons",
		"barstyles":   "bar-studio",
		"fastfetch":   "fastfetch",
	}
	for category, want := range cases {
		got, ok := settingsSection(category)
		if !ok || got != want {
			t.Fatalf("settingsSection(%q) = %q, %v; want %q, true", category, got, ok, want)
		}
	}
	if _, ok := settingsSection("today"); ok {
		t.Fatal("Today incorrectly maps to a Settings page")
	}
}

func TestStoreSectionIncludesShowroomRoutesAndEveryCategory(t *testing.T) {
	for _, section := range []string{"discover", "library", "rices", "lockscreens", "barstyles", "fastfetch", "plugins", "bundles"} {
		if !storeSection(section) {
			t.Fatalf("storeSection(%q) = false", section)
		}
	}
	for _, section := range []string{"today", "installed", "unknown"} {
		if storeSection(section) {
			t.Fatalf("storeSection(%q) = true", section)
		}
	}
}
