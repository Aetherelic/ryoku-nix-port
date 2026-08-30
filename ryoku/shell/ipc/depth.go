package main

import (
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
)

// depth is the wallpaper foreground effect (docs/depth.md): the subject of the
// current wallpaper, cut out into a transparent PNG and drawn in front of the
// desktop widgets. Generation is slow, so it runs on a coalescing worker off the
// wallpaper hot path (mirroring scheduleTheme/paintWorker), and the cutout path
// rides the existing wallpaper topic as the entry's `depth` field.

// depthSettings is what the shell asks for, read live from depth.json (the same
// GUI-managed file the desktop Config singleton writes).
type depthSettings struct {
	enabled bool
	model   string
}

// depthConfig reads enabled/model from ~/.config/ryoku/depth.json per pass, so a
// coalesced burst always acts on the latest intent. A missing file, key or
// unreadable value leaves depth off with the small CPU default model.
func depthConfig() depthSettings {
	def := depthSettings{enabled: false, model: "u2netp"}
	dir := ryokuConfigDir()
	if dir == "" {
		return def
	}
	b, err := os.ReadFile(filepath.Join(dir, "depth.json"))
	if err != nil {
		return def
	}
	var m struct {
		Enabled bool   `json:"enabled"`
		Model   string `json:"model"`
	}
	if json.Unmarshal(b, &m) != nil {
		return def
	}
	out := def
	out.enabled = m.Enabled
	if m.Model != "" {
		out.model = m.Model
	}
	return out
}

// depthBin resolves the ryoku-depth helper the way the desktop resolves its
// placement tool: a dev run points RYOKU_SHELL_DIR at the shell tree where the
// script is not on PATH; a packaged install ships it to /usr/bin, where the bare
// name resolves.
func depthBin() string {
	if dir := os.Getenv("RYOKU_SHELL_DIR"); dir != "" {
		p := filepath.Join(dir, "scripts", "ryoku-depth")
		if isFile(p) {
			return p
		}
	}
	return "ryoku-depth"
}

// depthEngineAvailable reports whether the opt-in segmentation engine is
// installed and carries a model, so the worker never blocks on a missing backend.
func depthEngineAvailable() bool {
	return exec.Command(depthBin(), "check").Run() == nil
}

// depthFile is the cutout path for a wallpaper cache file: named off it so the
// cutout is revision- and content-keyed and pruned alongside its wallpaper.
func depthFile(p string) string {
	if p == "" {
		return ""
	}
	return p + "-depth.png"
}

// scheduleDepth: nudge the depth worker, non-blocking. The buffered channel
// coalesces a burst of wallpaper switches into one regeneration of the final one.
func (d *daemon) scheduleDepth() {
	select {
	case d.depthSig <- struct{}{}:
	default:
	}
}

// depthWorker regenerates the cutout for whatever is on screen. It reads intent
// every pass, so a coalesced burst acts on the final wallpaper. When depth is off
// or the engine is absent it clears any published cutout so the overlay
// disappears. Runs for the life of the daemon.
func (d *daemon) depthWorker() {
	for range d.depthSig {
		if d.wall == nil {
			continue
		}
		cfg := depthConfig()
		if !cfg.enabled || !depthEngineAvailable() {
			d.wall.clearDepth()
			continue
		}
		d.generateDepth(cfg.model)
	}
}

// generateDepth runs the helper for each still entry that has no cutout yet, then
// republishes with the cutout path. The slow helper runs off the surface lock; a
// stale result (the entry moved on to another image) is dropped by setDepth.
func (d *daemon) generateDepth(model string) {
	for _, t := range d.wall.depthTargets() {
		out := depthFile(t.path)
		if err := exec.Command(depthBin(), "cutout", t.path, out, "--model", model).Run(); err != nil {
			fmt.Fprintf(os.Stderr, "depthWorker cutout: %v\n", err)
			continue
		}
		d.wall.setDepth(t.slot, t.path, out)
	}
}

// depthTarget is one entry to segment: its slot ("" = default) and the wallpaper
// cache file the cutout is made from.
type depthTarget struct {
	slot string
	path string
}

// depthTargets snapshots the still entries that still need a cutout, under the
// surface lock, so the slow helper can run unlocked.
func (w *wallSurface) depthTargets() []depthTarget {
	if w == nil {
		return nil
	}
	w.mu.Lock()
	defer w.mu.Unlock()
	var out []depthTarget
	if w.def.path != "" && !w.def.live && w.def.depthPath == "" {
		out = append(out, depthTarget{"", w.def.path})
	}
	for name, e := range w.outputs {
		if e.path != "" && !e.live && e.depthPath == "" {
			out = append(out, depthTarget{name, e.path})
		}
	}
	return out
}

// setDepth points an entry at its finished cutout and republishes, but only if
// the entry still shows the image that was segmented (a wallpaper switch mid-
// generation supersedes it).
func (w *wallSurface) setDepth(slot, srcPath, depthPath string) {
	if w == nil {
		return
	}
	w.mu.Lock()
	defer w.mu.Unlock()
	e := &w.def
	if slot != "" {
		e = w.outputs[slot]
		if e == nil {
			return
		}
	}
	if e.path != srcPath {
		return
	}
	e.depthPath = depthPath
	w.publishLocked()
}

// clearDepth drops every published cutout and republishes if anything changed,
// so turning depth off (or losing the engine) removes the overlay at once.
func (w *wallSurface) clearDepth() {
	if w == nil {
		return
	}
	w.mu.Lock()
	defer w.mu.Unlock()
	changed := false
	if w.def.depthPath != "" {
		w.def.depthPath = ""
		changed = true
	}
	for _, e := range w.outputs {
		if e.depthPath != "" {
			e.depthPath = ""
			changed = true
		}
	}
	if changed {
		w.publishLocked()
	}
}
