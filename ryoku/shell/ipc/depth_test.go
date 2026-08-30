package main

import (
	"encoding/json"
	"os"
	"path/filepath"
	"testing"
	"time"
)

// TestDepthConfigParses pins the render-knob contract: an absent file is the
// small-CPU default, model and alphaMatting are read verbatim, and the model
// falls back to the default when the key is missing. Whether depth is on is the
// per-wall registry, not depth.json, so enabled is no longer read here.
func TestDepthConfigParses(t *testing.T) {
	cfg := filepath.Join(t.TempDir(), ".config")
	t.Setenv("XDG_CONFIG_HOME", cfg)
	dir := filepath.Join(cfg, "ryoku")
	if err := os.MkdirAll(dir, 0o755); err != nil {
		t.Fatal(err)
	}

	if got := depthConfig(); got.model != "u2netp" || got.alphaMatting {
		t.Fatalf("absent depth.json = %+v, want {u2netp false}", got)
	}
	writeFile(t, filepath.Join(dir, "depth.json"), `{"model":"birefnet-general-lite","alphaMatting":true}`)
	if got := depthConfig(); got.model != "birefnet-general-lite" || !got.alphaMatting {
		t.Fatalf("depth.json = %+v, want {birefnet-general-lite true}", got)
	}
	writeFile(t, filepath.Join(dir, "depth.json"), `{"alphaMatting":true}`)
	if got := depthConfig(); got.model != "u2netp" || !got.alphaMatting {
		t.Fatalf("model-absent depth.json = %+v, want {u2netp true}", got)
	}
}

// TestDepthOutNaming pins the discoverable, per-wallpaper name: a cutout is the
// wallpaper's stem plus -depth.png, in the Pictures/Depth folder.
func TestDepthOutNaming(t *testing.T) {
	home := t.TempDir()
	t.Setenv("HOME", home)
	want := filepath.Join(home, "Pictures", "Depth", "sunset-depth.png")
	if got := depthOut("/wallpapers/sunset.jpg"); got != want {
		t.Fatalf("depthOut = %q, want %q", got, want)
	}
}

// TestDepthReusable proves a saved cutout is reused only when it still matches
// its source and model and is no older than the source, so a wallpaper's return
// is instant but a change (model, edited image) regenerates.
func TestDepthReusable(t *testing.T) {
	dir := t.TempDir()
	source := filepath.Join(dir, "wp.png")
	out := filepath.Join(dir, "wp-depth.png")
	writeFile(t, source, "src")
	writeFile(t, out, "cut")
	// make the cutout newer than the source.
	newer := time.Now().Add(time.Hour)
	if err := os.Chtimes(out, newer, newer); err != nil {
		t.Fatal(err)
	}
	idx := map[string]depthMeta{out: {Source: source, Model: "u2netp"}}

	if !depthReusable(idx, source, "u2netp", false, out) {
		t.Fatal("a matching, fresh cutout must be reusable")
	}
	if depthReusable(idx, source, "birefnet-general-lite", false, out) {
		t.Fatal("a different model must not reuse")
	}
	if depthReusable(idx, source, "u2netp", true, out) {
		t.Fatal("a different edge setting must not reuse")
	}
	if depthReusable(idx, filepath.Join(dir, "other.png"), "u2netp", false, out) {
		t.Fatal("a different source must not reuse")
	}
	if depthReusable(map[string]depthMeta{}, source, "u2netp", false, out) {
		t.Fatal("an unindexed cutout must not reuse")
	}
	// a source edited after the cutout was made must regenerate.
	future := time.Now().Add(2 * time.Hour)
	if err := os.Chtimes(source, future, future); err != nil {
		t.Fatal(err)
	}
	if depthReusable(idx, source, "u2netp", false, out) {
		t.Fatal("a source newer than its cutout must regenerate")
	}
}

// TestDepthTargets returns the still wallpapers on screen, default plus per-
// output overrides, and skips videos.
func TestDepthTargets(t *testing.T) {
	home := t.TempDir()
	t.Setenv("HOME", home)
	t.Setenv("XDG_CONFIG_HOME", filepath.Join(home, ".config"))
	if err := os.MkdirAll(stateDir(), 0o755); err != nil {
		t.Fatal(err)
	}
	img := filepath.Join(home, "a.png")
	vid := filepath.Join(home, "b.mp4")
	writeFile(t, img, "img")
	writeFile(t, vid, "vid")
	writeWallState(wallStateFile{Default: img, Outputs: map[string]string{"DP-1": vid}})

	d := &daemon{}
	targets := d.depthTargets()
	if len(targets) != 1 || targets[0].slot != "" || targets[0].source != img {
		t.Fatalf("targets = %+v, want only the default still image", targets)
	}
}

// TestEntryJSONCarriesDepth proves the cutout path and its revision reach the
// published frame.
func TestEntryJSONCarriesDepth(t *testing.T) {
	e := wallEntry{path: "wp-1.png", revision: 1, fit: "Cover", depthPath: "/p/sunset-depth.png", depthRev: 42}
	j := entryJSON(&e)
	if j.Depth != "/p/sunset-depth.png" || j.DepthRev != 42 {
		t.Fatalf("entryJSON = {%q,%d}, want the cutout path and rev", j.Depth, j.DepthRev)
	}
}

// TestDepthSetClearAndStale drives the worker's surface API: a finished cutout
// lands on the slot showing its source and republishes, a result for a
// superseded wallpaper is dropped, and clearing removes the overlay.
func TestDepthSetClearAndStale(t *testing.T) {
	home := t.TempDir()
	t.Setenv("HOME", home)
	t.Setenv("XDG_CONFIG_HOME", filepath.Join(home, ".config"))
	t.Setenv("XDG_CACHE_HOME", filepath.Join(home, ".cache"))

	src := filepath.Join(home, "wp.png")
	writeFile(t, src, "fake-png")
	if err := os.MkdirAll(stateDir(), 0o755); err != nil {
		t.Fatal(err)
	}
	writeFile(t, wallState(), src+"\n") // the slot currently shows src

	d := &daemon{lastTransition: -1}
	d.startWallpaper()
	if err := d.wall.show(src); err != nil {
		t.Fatalf("show: %v", err)
	}

	out := filepath.Join(home, "wp-depth.png")
	writeFile(t, out, "cutout")
	d.wall.setDepth("", src, out)
	if d.wall.def.depthPath != out || d.wall.def.depthRev == 0 {
		t.Fatalf("setDepth: {%q,%d}, want the cutout path and a nonzero rev", d.wall.def.depthPath, d.wall.def.depthRev)
	}

	var f struct {
		Default struct {
			Depth    string `json:"depth"`
			DepthRev int    `json:"depthRev"`
		} `json:"default"`
	}
	sub := d.wall.topic.subscribe()
	defer d.wall.topic.unsubscribe(sub)
	if err := json.Unmarshal(<-sub.frames, &f); err != nil {
		t.Fatalf("published frame not JSON: %v", err)
	}
	if f.Default.Depth != out || f.Default.DepthRev == 0 {
		t.Fatalf("published depth = {%q,%d}, want the cutout and a rev", f.Default.Depth, f.Default.DepthRev)
	}

	d.wall.setDepth("", filepath.Join(home, "other.png"), filepath.Join(home, "other-depth.png"))
	if d.wall.def.depthPath != out {
		t.Fatalf("a cutout for a superseded wallpaper was applied: %q", d.wall.def.depthPath)
	}

	d.wall.clearDepth()
	if d.wall.def.depthPath != "" || d.wall.def.depthRev != 0 {
		t.Fatalf("clearDepth left {%q,%d}", d.wall.def.depthPath, d.wall.def.depthRev)
	}
}

// TestDepthPerWallRegistry pins the per-wall opt-in: an untagged wallpaper is off
// and generates nothing (busy never sticks -- the switch-stuck fix), enabling
// tags the wallpaper, and switching away and back restores it from the persisted
// registry, which a fresh daemon reads on boot. The engine is forced absent so
// the effective flag and busy state are exercised without a real cutout.
func TestDepthPerWallRegistry(t *testing.T) {
	home := t.TempDir()
	t.Setenv("HOME", home)
	t.Setenv("XDG_STATE_HOME", filepath.Join(home, ".local", "state"))
	t.Setenv("XDG_CONFIG_HOME", filepath.Join(home, ".config"))
	t.Setenv("XDG_CACHE_HOME", filepath.Join(home, ".cache"))
	t.Setenv("PATH", t.TempDir()) // no ryoku-depth: engine reads as absent

	wx := filepath.Join(home, "x.png")
	wy := filepath.Join(home, "y.png")
	writeFile(t, wx, "x")
	writeFile(t, wy, "y")
	if err := os.MkdirAll(stateDir(), 0o755); err != nil {
		t.Fatal(err)
	}

	show := func(d *daemon, pic string) {
		writeWallState(wallStateFile{Default: pic})
		if err := d.wall.show(pic); err != nil {
			t.Fatalf("show: %v", err)
		}
	}

	d := &daemon{lastTransition: -1}
	d.startWallpaper()

	// Untagged wallpaper: off, no generation, busy never set, and the overlay is
	// cleared -- the switch never sticks on "Cutting out".
	show(d, wx)
	d.reconcileDepth(false, false)
	if loadDepthWalls().Current {
		t.Fatal("untagged wallpaper reported effective-enabled")
	}
	if d.depthBusy.Load() {
		t.Fatal("busy stuck true for an untagged wallpaper")
	}
	if !isFile(depthWallsPath()) {
		t.Fatal("registry not ensured on boot")
	}

	// Enable on X: tagged and effective immediately.
	d.depthSetEnabled(true)
	if reg := loadDepthWalls(); !reg.Current || !reg.Walls[wx] {
		t.Fatalf("after enable X = %+v, want current+tagged", reg)
	}

	// Switch to an untagged Y: off, busy clear, X's tag persists.
	show(d, wy)
	d.reconcileDepth(false, false)
	if loadDepthWalls().Current {
		t.Fatal("Y (never enabled) reported effective-enabled")
	}
	if d.depthBusy.Load() {
		t.Fatal("busy stuck true switching to an untagged wallpaper")
	}
	if !loadDepthWalls().Walls[wx] {
		t.Fatal("X's opt-in was lost when switching away")
	}

	// Switch back to X: depth restored from the registry.
	show(d, wx)
	d.reconcileDepth(false, false)
	if !loadDepthWalls().Current {
		t.Fatal("returning to X did not restore depth")
	}

	// Persisted across a daemon restart: a fresh daemon reads the same registry.
	d2 := &daemon{lastTransition: -1}
	d2.startWallpaper()
	d2.reconcileDepth(false, false)
	if !loadDepthWalls().Current {
		t.Fatal("depth opt-in did not survive a daemon restart")
	}

	// Disable on X: untagged again, off.
	d.depthSetEnabled(false)
	if reg := loadDepthWalls(); reg.Current || reg.Walls[wx] {
		t.Fatalf("after disable X = %+v, want off+untagged", reg)
	}
}
