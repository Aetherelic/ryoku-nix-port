package main

import (
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
)

// Wallpaper depth: the current wallpaper's subject, cut out to a transparent PNG
// and drawn in front of the desktop widgets (docs/depth.md). Generation is slow,
// so it runs on a coalescing worker off the wallpaper hot path. Cutouts are the
// user's, kept in ~/Pictures/Depth and reused, not a hidden cache.

type depthSettings struct {
	enabled      bool
	model        string
	alphaMatting bool
}

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
		Enabled      bool   `json:"enabled"`
		Model        string `json:"model"`
		AlphaMatting bool   `json:"alphaMatting"`
	}
	if json.Unmarshal(b, &m) != nil {
		return def
	}
	out := def
	out.enabled = m.Enabled
	out.alphaMatting = m.AlphaMatting
	if m.Model != "" {
		out.model = m.Model
	}
	return out
}

// depthBin: on PATH once packaged, but a dev run must reach it under
// RYOKU_SHELL_DIR where it is not.
func depthBin() string {
	if dir := os.Getenv("RYOKU_SHELL_DIR"); dir != "" {
		p := filepath.Join(dir, "scripts", "ryoku-depth")
		if isFile(p) {
			return p
		}
	}
	return "ryoku-depth"
}

func depthEngineAvailable() bool {
	return exec.Command(depthBin(), "check").Run() == nil
}

func depthDir() string { return filepath.Join(os.Getenv("HOME"), "Pictures", "Depth") }

func depthOut(source string) string {
	base := filepath.Base(source)
	stem := strings.TrimSuffix(base, filepath.Ext(base))
	return filepath.Join(depthDir(), stem+"-depth.png")
}

// depthMeta keeps reuse correct: a cutout is reused only for the same source,
// model, and edge setting, so returning to a wallpaper never shows a stale cut.
type depthMeta struct {
	Source       string `json:"source"`
	Model        string `json:"model"`
	AlphaMatting bool   `json:"alphaMatting"`
}

func depthIndexPath() string { return filepath.Join(depthDir(), ".index.json") }

func loadDepthIndex() map[string]depthMeta {
	out := map[string]depthMeta{}
	if b, err := os.ReadFile(depthIndexPath()); err == nil {
		_ = json.Unmarshal(b, &out)
	}
	return out
}

func saveDepthIndex(idx map[string]depthMeta) {
	if b, err := json.MarshalIndent(idx, "", "  "); err == nil {
		_ = os.WriteFile(depthIndexPath(), b, 0o644)
	}
}

func fileModTime(p string) int64 {
	if st, err := os.Stat(p); err == nil {
		return st.ModTime().Unix()
	}
	return 0
}

func depthReusable(idx map[string]depthMeta, source, model string, matting bool, out string) bool {
	m, ok := idx[out]
	if !ok || m.Source != source || m.Model != model || m.AlphaMatting != matting {
		return false
	}
	ot := fileModTime(out)
	return ot > 0 && ot >= fileModTime(source)
}

// scheduleDepth coalesces a burst of switches into one regeneration.
func (d *daemon) scheduleDepth() {
	select {
	case d.depthSig <- struct{}{}:
	default:
	}
}

func (d *daemon) depthWorker() {
	for range d.depthSig {
		if d.wall == nil {
			continue
		}
		force := d.depthForce.Swap(false)
		cfg := depthConfig()
		if !cfg.enabled || !depthEngineAvailable() {
			d.wall.clearDepth()
			continue
		}
		d.generateDepth(cfg.model, cfg.alphaMatting, force)
	}
}

// generateDepth reuses each on-screen wallpaper's saved cutout or regenerates it,
// then publishes. The slow helper runs off the surface lock.
func (d *daemon) generateDepth(model string, matting bool, force bool) {
	targets := d.depthTargets()
	if len(targets) == 0 {
		return
	}
	if err := os.MkdirAll(depthDir(), 0o755); err != nil {
		fmt.Fprintf(os.Stderr, "depthWorker: %v\n", err)
		return
	}
	idx := loadDepthIndex()
	changed := false
	for _, t := range targets {
		out := depthOut(t.source)
		if force || !depthReusable(idx, t.source, model, matting, out) {
			args := []string{"cutout", t.source, out, "--model", model}
			if matting {
				args = append(args, "--alpha-matting")
			}
			if err := exec.Command(depthBin(), args...).Run(); err != nil {
				fmt.Fprintf(os.Stderr, "depthWorker cutout: %v\n", err)
				continue
			}
			idx[out] = depthMeta{Source: t.source, Model: model, AlphaMatting: matting}
			changed = true
		}
		d.wall.setDepth(t.slot, t.source, out)
	}
	if changed {
		saveDepthIndex(idx)
	}
}

// depthTarget pairs an output ("" = default) with the ORIGINAL wallpaper path, so
// the cutout is named after the wallpaper and reused when it returns.
type depthTarget struct {
	slot   string
	source string
}

func (d *daemon) depthTargets() []depthTarget {
	st := readWallState()
	var out []depthTarget
	if st.Default != "" && !isVideo(st.Default) && isFile(st.Default) {
		out = append(out, depthTarget{"", st.Default})
	}
	for name, p := range st.Outputs {
		if p != "" && !isVideo(p) && isFile(p) {
			out = append(out, depthTarget{name, p})
		}
	}
	return out
}

// setDepth publishes a slot's cutout unless a switch mid-generation already moved
// it to another wallpaper. The revision is the cutout's mtime, so a regenerated
// file at the same path still busts the image cache.
func (w *wallSurface) setDepth(slot, source, out string) {
	if w == nil {
		return
	}
	if readWallState().currentFor(slot) != source {
		return
	}
	rev := int(fileModTime(out))
	w.mu.Lock()
	defer w.mu.Unlock()
	e := &w.def
	if slot != "" {
		e = w.outputs[slot]
		if e == nil {
			return
		}
	}
	e.depthPath = out
	e.depthRev = rev
	w.publishLocked()
}

func (w *wallSurface) clearDepth() {
	if w == nil {
		return
	}
	w.mu.Lock()
	defer w.mu.Unlock()
	changed := false
	if w.def.depthPath != "" {
		w.def.depthPath = ""
		w.def.depthRev = 0
		changed = true
	}
	for _, e := range w.outputs {
		if e.depthPath != "" {
			e.depthPath = ""
			e.depthRev = 0
			changed = true
		}
	}
	if changed {
		w.publishLocked()
	}
}
