package main

import (
	"encoding/json"
	"os"
	"path/filepath"
	"testing"
)

// TestDepthConfigParses pins the live-intent contract: an absent file is off with
// the small CPU default, and enabled/model are read verbatim with the model
// falling back to the default when the key is missing.
func TestDepthConfigParses(t *testing.T) {
	cfg := filepath.Join(t.TempDir(), ".config")
	t.Setenv("XDG_CONFIG_HOME", cfg)
	dir := filepath.Join(cfg, "ryoku")
	if err := os.MkdirAll(dir, 0o755); err != nil {
		t.Fatal(err)
	}

	if got := depthConfig(); got.enabled || got.model != "u2netp" {
		t.Fatalf("absent depth.json = %+v, want {false u2netp}", got)
	}
	writeFile(t, filepath.Join(dir, "depth.json"), `{"enabled":true,"model":"birefnet-general-lite"}`)
	if got := depthConfig(); !got.enabled || got.model != "birefnet-general-lite" {
		t.Fatalf("depth.json = %+v, want {true birefnet-general-lite}", got)
	}
	writeFile(t, filepath.Join(dir, "depth.json"), `{"enabled":true}`)
	if got := depthConfig(); !got.enabled || got.model != "u2netp" {
		t.Fatalf("model-absent depth.json = %+v, want {true u2netp}", got)
	}
}

// TestEntryJSONCarriesDepth proves the cutout path reaches the published frame.
func TestEntryJSONCarriesDepth(t *testing.T) {
	e := wallEntry{path: "wp-1.png", revision: 1, fit: "Cover", depthPath: "wp-1.png-depth.png"}
	if j := entryJSON(&e); j.Depth != "wp-1.png-depth.png" {
		t.Fatalf("entryJSON depth = %q, want the cutout path", j.Depth)
	}
}

// TestDepthSetClearAndStale drives the worker's surface API: a finished cutout
// lands on the entry and republishes, a result for a superseded image is dropped,
// and clearing removes the overlay.
func TestDepthSetClearAndStale(t *testing.T) {
	home := t.TempDir()
	t.Setenv("HOME", home)
	t.Setenv("XDG_CONFIG_HOME", filepath.Join(home, ".config"))
	t.Setenv("XDG_CACHE_HOME", filepath.Join(home, ".cache"))

	src := filepath.Join(home, "wp.png")
	writeFile(t, src, "fake-png")

	d := &daemon{lastTransition: -1}
	d.startWallpaper()
	if err := d.wall.show(src); err != nil {
		t.Fatalf("show: %v", err)
	}
	if d.wall.def.path == "" {
		t.Fatal("show set no default path")
	}

	d.wall.setDepth("", d.wall.def.path, "cutout.png")
	if d.wall.def.depthPath != "cutout.png" {
		t.Fatalf("setDepth: depthPath = %q, want cutout.png", d.wall.def.depthPath)
	}

	var f struct {
		Default struct {
			Depth string `json:"depth"`
		} `json:"default"`
	}
	sub := d.wall.topic.subscribe()
	defer d.wall.topic.unsubscribe(sub)
	if err := json.Unmarshal(<-sub.frames, &f); err != nil {
		t.Fatalf("published frame not JSON: %v", err)
	}
	if f.Default.Depth != "cutout.png" {
		t.Fatalf("published depth = %q, want cutout.png", f.Default.Depth)
	}

	d.wall.setDepth("", "nonesuch", "other.png")
	if d.wall.def.depthPath != "cutout.png" {
		t.Fatalf("stale setDepth overwrote depthPath = %q", d.wall.def.depthPath)
	}

	d.wall.clearDepth()
	if d.wall.def.depthPath != "" {
		t.Fatalf("clearDepth left depthPath = %q", d.wall.def.depthPath)
	}
}
