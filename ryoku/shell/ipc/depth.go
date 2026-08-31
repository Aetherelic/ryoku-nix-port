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

// depthSettings are the shell-owned render knobs from depth.json. Whether depth
// is effective for a wallpaper is the daemon's per-wall registry, not this file.
type depthSettings struct {
	model        string
	alphaMatting bool
}

func depthConfig() depthSettings {
	def := depthSettings{model: "u2netp"}
	dir := ryokuConfigDir()
	if dir == "" {
		return def
	}
	b, err := os.ReadFile(filepath.Join(dir, "depth.json"))
	if err != nil {
		return def
	}
	var m struct {
		Model        string `json:"model"`
		AlphaMatting bool   `json:"alphaMatting"`
	}
	if json.Unmarshal(b, &m) != nil {
		return def
	}
	out := def
	out.alphaMatting = m.AlphaMatting
	if m.Model != "" {
		out.model = m.Model
	}
	return out
}

// Per-wall depth registry (daemon-owned, persisted at ~/.local/state/ryoku/
// depth-walls.json): depth is opt-in per wallpaper, keyed by the wallpaper's
// path, and remembered across reboots. A wallpaper never enabled is "untagged" --
// switching to it generates nothing, so a new image never spins the panel on
// "Cutting out". `current` is true when every visible, eligible static wallpaper
// is enabled; video outputs are ignored.
type depthWalls struct {
	Current bool            `json:"current"`
	Walls   map[string]bool `json:"walls"`
}

func depthWallsPath() string { return filepath.Join(stateDir(), "ryoku", "depth-walls.json") }

func loadDepthWalls() depthWalls {
	w := depthWalls{Walls: map[string]bool{}}
	if b, err := os.ReadFile(depthWallsPath()); err == nil {
		_ = json.Unmarshal(b, &w)
		if w.Walls == nil {
			w.Walls = map[string]bool{}
		}
	}
	return w
}

func saveDepthWalls(w depthWalls) {
	if w.Walls == nil {
		w.Walls = map[string]bool{}
	}
	_ = os.MkdirAll(filepath.Dir(depthWallsPath()), 0o755)
	if b, err := json.MarshalIndent(w, "", "  "); err == nil {
		_ = os.WriteFile(depthWallsPath(), b, 0o644)
	}
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

// depthStatusJSON reports generation state and the current default cutout to the
// UI: busy drives the progress bar, path drives the preview thumbnail.
func depthStatusJSON(busy bool) string {
	path := ""

	// Preview a cutout belonging to a wallpaper that is actually visible on a
	// connected output. The legacy default may be stale when every monitor has
	// its own override.
	for _, t := range depthTargetsForState(readWallState(), connectedOutputs()) {
		if p := depthOut(t.source); isFile(p) {
			path = p
			break
		}
	}

	b, _ := json.Marshal(struct {
		Busy bool   `json:"busy"`
		Path string `json:"path"`
	}{busy, path})
	return string(b)
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
		d.reconcileDepth(d.depthForce.Swap(false), d.depthGen.Swap(false))
	}
}

// reconcileDepth resolves depth for the wallpaper on screen now from the per-wall
// registry: it publishes the effective-enabled flag the shell reads, then reuses,
// regenerates, or clears the overlay. An untagged/disabled wallpaper, or a video,
// generates nothing and never sets the busy flag, so a switch never sticks the
// panel on "Cutting out".
func (d *daemon) reconcileDepth(force, gen bool) {
	targets := d.depthTargets()
	reg := loadDepthWalls()

	changed := pruneDepthVideoEntries(&reg)
	effective := depthTargetsAllEnabled(targets, reg)

	if reg.Current != effective {
		reg.Current = effective
		changed = true
	}

	if changed || !isFile(depthWallsPath()) {
		saveDepthWalls(reg)
	}

	enabled := enabledDepthTargets(targets, reg)
	if len(enabled) == 0 || !depthEngineAvailable() {
		d.wall.clearDepth()
		return
	}

	cfg := depthConfig()

	// force (a detail change / refresh) regenerates; gen (an enable) reuses a
	// saved cutout when one matches and only generates when it is missing. A
	// plain switch reuses only, so changing wallpaper never starts the model.
	switch {
	case force:
		d.generateDepth(enabled, cfg.model, cfg.alphaMatting, true)
	case gen:
		d.generateDepth(enabled, cfg.model, cfg.alphaMatting, false)
	default:
		d.reuseDepth(enabled, cfg.model, cfg.alphaMatting)
	}
}

// reuseDepth publishes each on-screen wallpaper's saved cutout when one already
// matches, and clears otherwise. It never runs the helper, so switching to a
// wallpaper reuses a cut instantly but never auto-recuts a new one.
func (d *daemon) reuseDepth(targets []depthTarget, model string, matting bool) {
	idx := loadDepthIndex()

	// Clear first so a wallpaper that is no longer eligible cannot retain a
	// subject overlay from the previous per-output state.
	d.wall.clearDepth()

	for _, t := range targets {
		out := depthOut(t.source)
		if depthReusable(idx, t.source, model, matting, out) {
			d.wall.setDepth(t.slot, t.source, out)
		}
	}
}

// depthSetEnabled records the user's opt-in for the current wallpaper (persisted,
// restored when the wallpaper returns) and schedules a reconcile. Enabling reuses
// a saved cutout when one exists and only generates when it is missing, so turning
// depth back on is instant; disabling clears the overlay. The registry write is
// synchronous so the shell's toggle reflects at once.
func (d *daemon) depthSetEnabled(on bool) {
	targets := d.depthTargets()
	reg := loadDepthWalls()

	pruneDepthVideoEntries(&reg)
	setDepthTargetsEnabled(&reg, targets, on)

	// The UI has one toggle, so Current means every visible, eligible static
	// wallpaper is opted in. A mixed registry remains valid; its enabled outputs
	// still render independently.
	reg.Current = depthTargetsAllEnabled(targets, reg)
	saveDepthWalls(reg)

	if on && len(targets) > 0 {
		d.depthGen.Store(true)
	}

	d.scheduleDepth()
}

// generateDepth reuses each on-screen wallpaper's saved cutout or regenerates it,
// then publishes. The slow helper runs off the surface lock.
func (d *daemon) generateDepth(targets []depthTarget, model string, matting bool, force bool) {
	if len(targets) == 0 {
		return
	}

	d.depthBusy.Store(true)
	defer d.depthBusy.Store(false)

	if err := os.MkdirAll(depthDir(), 0o755); err != nil {
		fmt.Fprintf(os.Stderr, "depthWorker: %v\n", err)
		return
	}

	// Remove overlays for outputs that are no longer enabled before publishing
	// this generation's target set.
	d.wall.clearDepth()

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

			idx[out] = depthMeta{
				Source:       t.source,
				Model:        model,
				AlphaMatting: matting,
			}
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

// depthTargetsForState resolves the static wallpapers actually visible on the
// connected outputs. A connector override wins over the global default. When
// Hyprland's output list is unavailable, retain the old default-plus-overrides
// fallback so startup and non-Hyprland test environments remain best-effort.
func depthTargetsForState(st wallStateFile, outputs []string) []depthTarget {
	var targets []depthTarget

	if len(outputs) > 0 {
		for _, name := range outputs {
			p := st.currentFor(name)
			if p == "" || isVideo(p) || !isFile(p) {
				continue
			}
			targets = append(targets, depthTarget{
				slot:   name,
				source: p,
			})
		}
		return targets
	}

	if st.Default != "" && !isVideo(st.Default) && isFile(st.Default) {
		targets = append(targets, depthTarget{
			slot:   "",
			source: st.Default,
		})
	}

	for name, p := range st.Outputs {
		if p == "" || isVideo(p) || !isFile(p) {
			continue
		}
		targets = append(targets, depthTarget{
			slot:   name,
			source: p,
		})
	}

	return targets
}

// depthTargetsAllEnabled is the aggregate state represented by the single UI
// toggle. Zero eligible static wallpapers is always off.
func depthTargetsAllEnabled(targets []depthTarget, reg depthWalls) bool {
	if len(targets) == 0 {
		return false
	}

	for _, t := range targets {
		if !reg.Walls[t.source] {
			return false
		}
	}

	return true
}

func enabledDepthTargets(targets []depthTarget, reg depthWalls) []depthTarget {
	out := make([]depthTarget, 0, len(targets))

	for _, t := range targets {
		if reg.Walls[t.source] {
			out = append(out, t)
		}
	}

	return out
}

func setDepthTargetsEnabled(reg *depthWalls, targets []depthTarget, on bool) {
	if reg.Walls == nil {
		reg.Walls = map[string]bool{}
	}

	for _, t := range targets {
		if on {
			reg.Walls[t.source] = true
		} else {
			delete(reg.Walls, t.source)
		}
	}
}

// Older multi-monitor logic could accidentally tag a video as depth-enabled.
// Videos can never have a cutout, so discard only those impossible entries while
// retaining static wallpapers that are currently off-screen.
func pruneDepthVideoEntries(reg *depthWalls) bool {
	changed := false

	for wall := range reg.Walls {
		if isVideo(wall) {
			delete(reg.Walls, wall)
			changed = true
		}
	}

	return changed
}

func (d *daemon) depthTargets() []depthTarget {
	return depthTargetsForState(readWallState(), connectedOutputs())
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
