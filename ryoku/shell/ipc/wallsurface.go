package main

import (
	"encoding/json"
	"io"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"sync"
)

// wallSurface is the in-shell desktop wallpaper. Bringing the wallpaper in-shell
// (contract 08 sec 1, 2.6, 3.1) replaces the external image daemon: the daemon
// copies the chosen image into a revision-stamped cache file, bumps a revision,
// and streams a full per-output frame on the `wallpaper` topic. Every backdrop
// window (one per monitor) subscribes and crossfades to each new revision, so
// wallpaper state, the colour scheme, and the shell all live in one process.
//
// The frame is {default: ENTRY, outputs: {connector: ENTRY}}. A backdrop paints
// outputs[its screen] or, absent an override, the default (contract 08 sec 7).
// A broadcast set writes the default and clears the overrides; a per-output set
// writes one override.
type wallEntry struct {
	revision   int               // cache-busting revision; also names the cache file
	path       string            // current cache file ("" = none)
	fit        string            // content fit -> QML Image.fillMode
	fitPin     string            // pins this frame's fit; "" follows the user's setting
	live       bool              // the video player owns this output's pixels
	transition *pickedTransition // reveal preset (nil = plain crossfade)
	depthPath  string            // foreground cutout PNG ("" = none / not yet generated)
	depthRev   int               // cutout cache-buster (its mtime); 0 = none
}

type wallSurface struct {
	topic    *stateTopic
	cacheDir string

	mu      sync.Mutex
	seq     int                   // monotonic cache-file counter (unique filenames)
	def     wallEntry             // default entry: unspecified / hotplugged outputs
	outputs map[string]*wallEntry // per-output overrides ("" is never a key)
	prev    string                // last outgoing cache file, kept one extra reveal
}

// wallSurfaceCacheDir is where the chosen image is copied (contract 08 sec 3.1).
// Files are revision-stamped so each swap is a distinct url the surface reloads
// without a stale pixmap-cache hit.
func wallSurfaceCacheDir() string {
	base := os.Getenv("XDG_CACHE_HOME")
	if base == "" {
		base = filepath.Join(os.Getenv("HOME"), ".cache")
	}
	return filepath.Join(base, "ryoku", "wallpaper")
}

// contentFitModes are the four fits the backdrop maps to Image.fillMode
// (contract 08 sec 3.3); Cover is the default.
var contentFitModes = map[string]bool{"Contain": true, "Cover": true, "Fill": true, "ScaleDown": true}

// wallpaperContentFit reads wallpaper.content_fit from shell.json, defaulting to
// Cover. The Go settings owner (settings.go) formalises this key; until a live
// change arrives the surface reads it per apply so a wallpaper set already honours
// the stored fit. An unknown or absent value is Cover, matching the schema
// default (contract 08 sec 8).
func wallpaperContentFit() string {
	const def = "Cover"
	dir := ryokuConfigDir()
	if dir == "" {
		return def
	}
	b, err := os.ReadFile(filepath.Join(dir, "shell.json"))
	if err != nil {
		return def
	}
	var m struct {
		Wallpaper struct {
			ContentFit string `json:"content_fit"`
		} `json:"wallpaper"`
	}
	if json.Unmarshal(b, &m) != nil {
		return def
	}
	if contentFitModes[m.Wallpaper.ContentFit] {
		return m.Wallpaper.ContentFit
	}
	return def
}

// startWallpaper registers the wallpaper topic and publishes the empty snapshot,
// so a backdrop that subscribes before the first image sees a defined frame.
func (d *daemon) startWallpaper() {
	dir := wallSurfaceCacheDir()
	_ = os.MkdirAll(dir, 0o755)
	d.wall = &wallSurface{
		topic:    d.registerTopic("wallpaper"),
		cacheDir: dir,
		outputs:  map[string]*wallEntry{},
		def:      wallEntry{fit: wallpaperContentFit()},
	}
	d.wall.mu.Lock()
	d.wall.publishLocked()
	d.wall.mu.Unlock()
}

// show sets the default entry with no reveal preset (plain crossfade). Used by
// init and by a live clip's still-frame.
func (w *wallSurface) show(pic string) error {
	return w.showTransition(pic, nil)
}

// showTransition sets the default entry following the user's content fit, with
// tr's reveal preset (nil = plain crossfade).
func (w *wallSurface) showTransition(pic string, tr *pickedTransition) error {
	return w.showFrame(pic, tr, "")
}

// showFrame sets the default entry (a broadcast set) and clears every per-output
// override, so every backdrop follows the new default. fit "" follows the user's
// wallpaper fit; any other value pins this frame's geometry until it is replaced
// (a clip's still is pinned to the fit livewall paints the VIDEO in, a separate
// knob from the image fit, so the wallpaper does not jump scale when the clip
// takes over).
func (w *wallSurface) showFrame(pic string, tr *pickedTransition, fit string) error {
	if w == nil {
		return nil
	}
	w.mu.Lock()
	defer w.mu.Unlock()
	if err := w.fillLocked(&w.def, pic, tr, fit); err != nil {
		return err
	}
	w.outputs = map[string]*wallEntry{}
	w.publishLocked()
	w.prune()
	return nil
}

// showOutput sets one output's override, leaving the default and the other
// overrides untouched. Used by per-output sets and per-output live stills.
func (w *wallSurface) showOutput(name, pic string, tr *pickedTransition, fit string) error {
	if w == nil || name == "" {
		return nil
	}
	w.mu.Lock()
	defer w.mu.Unlock()
	if w.outputs == nil {
		w.outputs = map[string]*wallEntry{}
	}
	e := w.outputs[name]
	if e == nil {
		e = &wallEntry{}
		w.outputs[name] = e
	}
	if err := w.fillLocked(e, pic, tr, fit); err != nil {
		return err
	}
	w.publishLocked()
	w.prune()
	return nil
}

// fillLocked copies pic into a fresh cache file and points entry e at it, keeping
// the outgoing file for one more reveal. The caller holds w.mu.
func (w *wallSurface) fillLocked(e *wallEntry, pic string, tr *pickedTransition, fit string) error {
	w.seq++
	rev := w.seq
	dst := filepath.Join(w.cacheDir, "wp-"+strconv.Itoa(rev)+strings.ToLower(filepath.Ext(pic)))
	if err := os.MkdirAll(w.cacheDir, 0o755); err != nil {
		return err
	}
	if err := copyFile(pic, dst); err != nil {
		return err
	}
	w.prev = e.path
	e.revision = rev
	e.path = dst
	e.fitPin = fit
	e.fit = fitFor(fit)
	// A fresh frame is the backdrop's to paint until a player claims it again.
	e.live = false
	e.transition = tr
	// A fresh wallpaper needs a fresh cutout; the depth worker regenerates it.
	e.depthPath = ""
	e.depthRev = 0
	return nil
}

// fitFor is the pinned fit when set, else the user's wallpaper fit.
func fitFor(pin string) string {
	if pin != "" {
		return pin
	}
	return wallpaperContentFit()
}

// republish re-reads the content fit for every entry (dropping to the user's fit
// where no pin is set) and republishes without advancing revisions, so a live
// content-fit change re-fits in place with no crossfade. A byte-identical frame
// is suppressed by the topic.
func (w *wallSurface) republish() {
	if w == nil {
		return
	}
	w.mu.Lock()
	defer w.mu.Unlock()
	w.def.fit = fitFor(w.def.fitPin)
	for _, e := range w.outputs {
		e.fit = fitFor(e.fitPin)
	}
	w.publishLocked()
}

// setLive marks whether the video player owns the default entry's pixels. The
// backdrop steps aside (paints nothing) while true, so a reloaded backdrop never
// covers a running video with its frozen first frame.
func (w *wallSurface) setLive(on bool) {
	if w == nil {
		return
	}
	w.mu.Lock()
	defer w.mu.Unlock()
	if w.def.live == on {
		return
	}
	w.def.live = on
	w.publishLocked()
}

// setLiveOutput is setLive for one output's override.
func (w *wallSurface) setLiveOutput(name string, on bool) {
	if w == nil || name == "" {
		return
	}
	w.mu.Lock()
	defer w.mu.Unlock()
	e := w.outputs[name]
	if e == nil || e.live == on {
		return
	}
	e.live = on
	w.publishLocked()
}

// setLiveSlot routes to the default ("") or one output.
func (w *wallSurface) setLiveSlot(slot string, on bool) {
	if slot == "" {
		w.setLive(on)
		return
	}
	w.setLiveOutput(slot, on)
}

// setLiveAll clears (or sets) every live flag in one publish. Used when the
// fullscreen/power gate stops every player at once.
func (w *wallSurface) setLiveAll(on bool) {
	if w == nil {
		return
	}
	w.mu.Lock()
	defer w.mu.Unlock()
	changed := w.def.live != on
	w.def.live = on
	for _, e := range w.outputs {
		if e.live != on {
			changed = true
		}
		e.live = on
	}
	if changed {
		w.publishLocked()
	}
}

// wallFrameEntry is one ENTRY in the published frame (contract 08 sec 3).
type wallFrameEntry struct {
	Path       string            `json:"path"`
	Revision   int               `json:"revision"`
	Fit        string            `json:"fit"`
	Live       bool              `json:"live"`
	Transition *pickedTransition `json:"transition"`
	Depth      string            `json:"depth"`
	DepthRev   int               `json:"depthRev"`
}

// wallFrame is the coalesced full-state frame: a default plus per-output
// overrides. A backdrop applies outputs[its screen] || default.
type wallFrame struct {
	Default wallFrameEntry            `json:"default"`
	Outputs map[string]wallFrameEntry `json:"outputs"`
}

func entryJSON(e *wallEntry) wallFrameEntry {
	return wallFrameEntry{e.path, e.revision, e.fit, e.live, e.transition, e.depthPath, e.depthRev}
}

// publishLocked marshals and ships the full per-output frame. The caller holds
// w.mu.
func (w *wallSurface) publishLocked() {
	if w.topic == nil {
		return
	}
	outs := make(map[string]wallFrameEntry, len(w.outputs))
	for name, e := range w.outputs {
		outs[name] = entryJSON(e)
	}
	frame, err := json.Marshal(wallFrame{Default: entryJSON(&w.def), Outputs: outs})
	if err != nil {
		return
	}
	w.topic.publish(frame)
}

// prune drops cache files not referenced by any current entry. The most recently
// replaced file (w.prev) is kept so an in-flight crossfade still has its outgoing
// image. The caller holds w.mu.
func (w *wallSurface) prune() {
	keep := map[string]bool{}
	for _, p := range append([]string{w.def.path, w.prev}, w.outputPathsLocked()...) {
		if p != "" {
			keep[filepath.Base(p)] = true
		}
	}
	entries, err := os.ReadDir(w.cacheDir)
	if err != nil {
		return
	}
	for _, e := range entries {
		name := e.Name()
		if !strings.HasPrefix(name, "wp-") || keep[name] {
			continue
		}
		_ = os.Remove(filepath.Join(w.cacheDir, name))
	}
}

// outputPathsLocked lists every override's cache file. The caller holds w.mu.
func (w *wallSurface) outputPathsLocked() []string {
	out := make([]string, 0, len(w.outputs))
	for _, e := range w.outputs {
		out = append(out, e.path)
	}
	return out
}

// copyFile copies src to dst byte for byte, replacing dst if it exists.
func copyFile(src, dst string) error {
	in, err := os.Open(src)
	if err != nil {
		return err
	}
	defer in.Close()
	out, err := os.Create(dst)
	if err != nil {
		return err
	}
	if _, err := io.Copy(out, in); err != nil {
		_ = out.Close()
		return err
	}
	return out.Close()
}
