package main

import (
	"bufio"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"math/rand"
	"os"
	"os/exec"
	"path/filepath"
	"sort"
	"strconv"
	"strings"
	"sync"
	"time"
)

func findHubBin() string {
	if p, err := exec.LookPath("ryoku-hub"); err == nil {
		return p
	}
	home := os.Getenv("HOME")
	for _, cand := range []string{
		filepath.Join(home, ".local", "bin", "ryoku-hub"),
		"/usr/local/bin/ryoku-hub",
		"/usr/bin/ryoku-hub",
	} {
		if _, err := os.Stat(cand); err == nil {
			return cand
		}
	}
	return "ryoku-hub"
}
func wallDir() string   { return filepath.Join(os.Getenv("HOME"), "Pictures", "Wallpapers") }
func liveDir() string   { return filepath.Join(os.Getenv("HOME"), "Pictures", "livewalls") }
func wallState() string { return filepath.Join(stateDir(), "ryoku-wallpaper") }
func wallBag() string   { return filepath.Join(stateDir(), "ryoku-wallpaper-bag") }
func wallStateJSON() string { return filepath.Join(stateDir(), "ryoku-wallpaper.json") }

// wallStateFile is the persisted per-output state (contract 08): a global default
// plus per-connector overrides.
type wallStateFile struct {
	Default string            `json:"default"`
	Outputs map[string]string `json:"outputs"`
}

// currentFor is the wallpaper a screen shows now: its override, else the default.
func (st wallStateFile) currentFor(screen string) string {
	if screen != "" {
		if p, ok := st.Outputs[screen]; ok {
			return p
		}
	}
	return st.Default
}

// readWallState loads the per-output state, migrating a legacy plain-path file
// (default = its path, no overrides) when the json is absent or unreadable.
func readWallState() wallStateFile {
	if b, err := os.ReadFile(wallStateJSON()); err == nil {
		var st wallStateFile
		if json.Unmarshal(b, &st) == nil {
			if st.Outputs == nil {
				st.Outputs = map[string]string{}
			}
			return st
		}
	}
	return wallStateFile{Default: readState(), Outputs: map[string]string{}}
}

// writeWallState persists the state as json and mirrors the default into the
// legacy plain-path file for back-compat.
func writeWallState(st wallStateFile) {
	if st.Outputs == nil {
		st.Outputs = map[string]string{}
	}
	_ = os.MkdirAll(stateDir(), 0o755)
	if b, err := json.Marshal(st); err == nil {
		_ = os.WriteFile(wallStateJSON(), b, 0o644)
	}
	_ = os.WriteFile(wallState(), []byte(st.Default+"\n"), 0o644)
}

// stateHasVideo reports whether the default or any override is a live clip.
func stateHasVideo(st wallStateFile) bool {
	if isVideo(st.Default) && isFile(st.Default) {
		return true
	}
	for _, p := range st.Outputs {
		if isVideo(p) && isFile(p) {
			return true
		}
	}
	return false
}

// connectedOutputs lists connector names of connected monitors from hyprctl. nil
// when the list can't be read, so callers fall back to global behaviour.
func connectedOutputs() []string {
	out, err := exec.Command("hyprctl", "monitors", "-j").Output()
	if err != nil {
		return nil
	}
	var mons []struct {
		Name string `json:"name"`
	}
	if json.Unmarshal(out, &mons) != nil {
		return nil
	}
	names := make([]string, 0, len(mons))
	for _, m := range mons {
		if m.Name != "" {
			names = append(names, m.Name)
		}
	}
	return names
}

// liveSlots is the set of slots a broadcast/default live wallpaper spans: every
// connected output, or the NULL slot ("") when the list can't be read (today's
// single-monitor / no-hyprctl behaviour).
func liveSlots() []string {
	if slots := connectedOutputs(); len(slots) > 0 {
		return slots
	}
	return []string{""}
}

// wallpaperApply picks a wallpaper per mode (init | set | next | random | refresh
// | repaint | live-reload) and shows it. screen "" is a broadcast (the default and
// every connected output); a connector name targets one output. Images are painted
// by the in-shell backdrop; videos play through ryoku-livewall, one player per live
// output. The slow retheme goes to coalescing workers via scheduleTheme so rapid
// Super+W stays smooth. best-effort: a missing wallpaper dir is a no-op, not error.
func (d *daemon) wallpaperApply(mode, arg, screen string) error {
	switch mode {
	case "repaint":
		// re-derive palette / borders / LEDs and re-fit in place, no reveal.
		d.scheduleTheme()
		d.wall.republish()
		return nil
	case "live-reload":
		// relaunch the live wallpapers with fresh motion opts (ryowalls fit).
		st := readWallState()
		if stateHasVideo(st) {
			d.stopLive()
			d.showSavedLive(st)
		}
		return nil
	case "init":
		d.restoreState()
		return nil
	case "refresh":
		// hotplug: re-send the full map (a new backdrop already gets the snapshot
		// on subscribe) and start a player for any newly connected live output.
		d.wall.republish()
		d.reconcileLive()
		return nil
	}

	var pic string
	switch mode {
	case "set":
		if !isFile(arg) {
			return nil
		}
		pic = arg
	case "random":
		// Super+Shift+W: a random pool wallpaper, never this screen's current one.
		pic = pickRandomImage(listPics(), readWallState().currentFor(screen))
	default: // next
		pic = popBag()
	}
	if pic == "" {
		return nil
	}
	return d.applyPick(mode, pic, screen)
}

// applyPick shows one resolved pick and persists it: a video through
// ryoku-livewall, an image through the backdrop. screen "" broadcasts (default +
// every output); a name targets one output, leaving the others running.
func (d *daemon) applyPick(mode, pic, screen string) error {
	if isVideo(pic) {
		if screen == "" {
			if err := d.showLiveWallpaper(pic); err != nil {
				return err
			}
		} else if err := d.showLiveOutput(screen, pic); err != nil {
			return err
		}
	} else if screen == "" {
		// stop every video so the backdrops are revealed, then reveal the image.
		d.stopLive()
		if err := d.wall.showFrame(pic, d.transitionFor(mode), ""); err != nil {
			return err
		}
	} else {
		d.ensureLive().stop(screen)
		if err := d.wall.showOutput(screen, pic, d.transitionFor(mode), ""); err != nil {
			return err
		}
	}
	d.saveState(pic, screen)
	d.scheduleTheme()
	return nil
}

// saveState persists the pick: a broadcast writes the default and every connected
// output; a per-output set writes one override.
func (d *daemon) saveState(pic, screen string) {
	st := readWallState()
	if screen == "" {
		st.Default = pic
		st.Outputs = map[string]string{}
		for _, name := range connectedOutputs() {
			st.Outputs[name] = pic
		}
	} else {
		if st.Outputs == nil {
			st.Outputs = map[string]string{}
		}
		st.Outputs[screen] = pic
	}
	writeWallState(st)
}

// --- live (video) wallpapers: the ryoku-livewall daemon ---------------------
//
// A video plays through ryoku-livewall, a lightweight software-decode daemon that
// paints wl_shm frames on its own wlr background surface. It maps no GPU/EGL
// driver, so it holds ~40 MB RSS on any vendor, where mpv/mpvpaper (a client GL
// pipeline) cost 300-700 MB and leak per loop, and hardware decode cannot beat it
// on NVIDIA (the CUDA/GL userspace floor alone exceeds 100 MB). The in-shell
// backdrop paints the clip's own first frame under it, so the desktop always shows
// the clip's content: livewall's video covers the backdrop; the gap before it
// paints (a one-time transcode) is the clip's still, never a stale image; and
// switching back to an image crossfades from that real frame.

const liveDaemon = "ryoku-livewall"

// liveCapWidth caps livewall's decode/render width at the widest monitor's
// logical width (physical / fractional scale), so a video wallpaper renders near
// 1:1 with its surface instead of the old fixed 1280 upscaled to a blur. Software
// decode scales with resolution, so the width is clamped to 2560 to hold
// livewall's PSS under the 100 MB budget (~47 MB at 2048, ~59 MB at 2560); a
// wider panel plays at 2560 rather than blow it. "1920" when hyprctl is absent.
func liveCapWidth() string {
	const floor, ceil = 1280, 2560
	out, err := exec.Command("hyprctl", "monitors", "-j").Output()
	if err != nil {
		return "1920"
	}
	var mons []struct {
		Width int     `json:"width"`
		Scale float64 `json:"scale"`
	}
	if json.Unmarshal(out, &mons) != nil {
		return "1920"
	}
	best := 0
	for _, m := range mons {
		w := m.Width
		if m.Scale > 0 {
			w = int(float64(m.Width)/m.Scale + 0.5)
		}
		if w > best {
			best = w
		}
	}
	if best < floor {
		best = floor
	}
	if best > ceil {
		best = ceil
	}
	return strconv.Itoa(best)
}

// liveFit reads the ryowalls Fit knob (ryowalls.json) that livewall applies when
// mapping the clip onto the screen: "fit" letterboxes the whole clip, the
// default covers. Passed to livewall as argv[3]; a missing config means cover.
func liveFit() string {
	base := os.Getenv("XDG_CONFIG_HOME")
	if base == "" {
		base = filepath.Join(os.Getenv("HOME"), ".config")
	}
	b, err := os.ReadFile(filepath.Join(base, "ryoku", "ryowalls.json"))
	if err != nil {
		return "fill"
	}
	var s struct {
		LiveFit string `json:"liveFit"`
	}
	if json.Unmarshal(b, &s) == nil && s.LiveFit == "fit" {
		return "fit"
	}
	return "fill"
}

// liveContentFit is liveFit() in the backdrop's vocabulary: the fillMode the clip's
// still must be painted in so the reveal is framed exactly like the video that
// replaces it. livewall's "fit" letterboxes the whole clip (Contain); its default
// covers the screen (Cover).
func liveContentFit() string {
	if liveFit() == "fit" {
		return "Contain"
	}
	return "Cover"
}

// liveManager runs at most one ryoku-livewall process per live output. The slot
// key is a connector name, or "" for the NULL-output / global fallback used when
// the output list can't be read (today's single-monitor behaviour). Each slot's
// generation serializes its async transcode+launch: a bump cancels an in-flight
// transcode so a clip the user already switched away from never paints.
type liveManager struct {
	mu    sync.Mutex
	slots map[string]*liveSlot
}

type liveSlot struct {
	gen int64
	cmd *exec.Cmd // running player, nil if none
}

func newLiveManager() *liveManager { return &liveManager{slots: map[string]*liveSlot{}} }

func (d *daemon) ensureLive() *liveManager {
	d.liveMu.Lock()
	defer d.liveMu.Unlock()
	if d.live == nil {
		d.live = newLiveManager()
	}
	return d.live
}

func (m *liveManager) slot(name string) *liveSlot {
	s := m.slots[name]
	if s == nil {
		s = &liveSlot{}
		m.slots[name] = s
	}
	return s
}

// begin bumps a slot's generation (cancelling any in-flight transcode), kills its
// current player, and returns the new generation for the caller to launch under.
func (m *liveManager) begin(name string) int64 {
	m.mu.Lock()
	defer m.mu.Unlock()
	s := m.slot(name)
	s.gen++
	killProc(s.cmd)
	s.cmd = nil
	return s.gen
}

func (m *liveManager) stale(name string, gen int64) bool {
	m.mu.Lock()
	defer m.mu.Unlock()
	return m.slot(name).gen != gen
}

// attach records a launched player if the slot is still current; false (stale)
// tells the caller to kill the process it just started.
func (m *liveManager) attach(name string, gen int64, cmd *exec.Cmd) bool {
	m.mu.Lock()
	defer m.mu.Unlock()
	s := m.slot(name)
	if s.gen != gen {
		return false
	}
	s.cmd = cmd
	return true
}

// done clears a player that has exited, if it is still the current one.
func (m *liveManager) done(name string, gen int64, cmd *exec.Cmd) {
	m.mu.Lock()
	defer m.mu.Unlock()
	s := m.slot(name)
	if s.gen == gen && s.cmd == cmd {
		s.cmd = nil
	}
}

// stop kills one slot's player and cancels its in-flight transcode.
func (m *liveManager) stop(name string) { m.begin(name) }

// stopAll kills every slot's player.
func (m *liveManager) stopAll() {
	m.mu.Lock()
	defer m.mu.Unlock()
	for _, s := range m.slots {
		s.gen++
		killProc(s.cmd)
		s.cmd = nil
	}
}

func (m *liveManager) running(name string) bool {
	m.mu.Lock()
	defer m.mu.Unlock()
	return m.slots[name] != nil && m.slots[name].cmd != nil
}

// liveNames returns the slots with a running player.
func (m *liveManager) liveNames() []string {
	m.mu.Lock()
	defer m.mu.Unlock()
	var out []string
	for name, s := range m.slots {
		if s.cmd != nil {
			out = append(out, name)
		}
	}
	return out
}

func killProc(cmd *exec.Cmd) {
	if cmd != nil && cmd.Process != nil {
		_ = cmd.Process.Kill()
	}
}

func isVideo(p string) bool {
	switch strings.ToLower(filepath.Ext(p)) {
	case ".mp4", ".webm", ".mkv", ".mov":
		return true
	}
	return false
}

func liveAlive() bool { return exec.Command("pgrep", "-x", liveDaemon).Run() == nil }

// legacyLiveDaemons: video backends previous releases shipped (mpvpaper through
// beta 16, phonto in the interim GPU-picked era). an update swaps the daemon
// binary but not the detached player the old daemon left running, and that
// orphan's background surface stacks ABOVE awww's, so every static set paints
// invisibly under the old clip ("the wallpaper won't change"). nothing else
// manages them anymore, so killLegacyLive reaps them where the daemon takes
// ownership of the wallpaper stack: once at bootstrap (wallInit), and in the
// updater's quiesce. NOT in killLive: an orphan cannot appear mid-session (no
// old daemon is left to spawn one), and a user may legitimately run a legacy
// backend on a monitor Ryoku does not drive -- reaping on every wallpaper change
// would kill that setup over and over.
var legacyLiveDaemons = []string{"mpvpaper", "phonto"}

func killLegacyLive() {
	for _, name := range legacyLiveDaemons {
		_ = exec.Command("pkill", "-x", name).Run()
	}
}

// wallInit is the daemon's first wallpaper pass, under wallMu in bootstrap.
// the legacy reap must precede the init apply: with a static state and awww
// alive, init returns without reaching any kill path, and the orphan would
// keep occluding the desktop until the user's next wallpaper change.
func (d *daemon) wallInit() {
	killLegacyLive()
	_ = d.wallpaperApply("init", "", "")
}

// killLive terminates every livewall instance and waits for it to exit, so a
// following awww image or a fresh instance is never raced by a lingering one.
func killLive() {
	if exec.Command("pkill", "-x", liveDaemon).Run() != nil {
		return
	}
	for range 40 {
		if !liveAlive() {
			return
		}
		time.Sleep(25 * time.Millisecond)
	}
	_ = exec.Command("pkill", "-9", "-x", liveDaemon).Run()
}

// stopLive stops every live player (all outputs), cancels in-flight transcodes,
// and hands the pixels back to the backdrops. Used by an image broadcast and by
// the fullscreen / power gate.
func (d *daemon) stopLive() {
	d.ensureLive().stopAll()
	killLive()
	d.wall.setLiveAll(false)
}

// showLiveWallpaper plays a clip as the broadcast (default) wallpaper: it paints
// the clip's still on every backdrop, then launches one ryoku-livewall per
// connected output (each bound to its output), stepping each backdrop aside once
// its player has painted (READY). Falls back to a single NULL-output player when
// the output list can't be read (today's single-monitor behaviour).
func (d *daemon) showLiveWallpaper(pic string) error {
	mgr := d.ensureLive()
	cfit := liveContentFit()
	still := liveFrame(pic)
	if still != "" {
		_ = d.wall.showFrame(still, nil, cfit)
	}
	mgr.stopAll()
	killLive()
	slots := connectedOutputs()
	if len(slots) == 0 {
		d.launchLive("", pic)
		return nil
	}
	for _, name := range slots {
		if still != "" {
			_ = d.wall.showOutput(name, still, nil, cfit)
		}
		d.launchLive(name, pic)
	}
	return nil
}

// showLiveOutput plays a clip on one output only: its still on that backdrop, a
// player bound to that output launched over it. Other outputs are untouched.
func (d *daemon) showLiveOutput(screen, pic string) error {
	mgr := d.ensureLive()
	if still := liveFrame(pic); still != "" {
		_ = d.wall.showOutput(screen, still, nil, liveContentFit())
	}
	mgr.stop(screen)
	d.launchLive(screen, pic)
	return nil
}

// launchLive transcodes pic (off the hot path) and runs one ryoku-livewall bound
// to slot ("" = NULL/primary), stepping that backdrop aside on READY and back once
// the player exits. The slot's generation guards the async launch so a clip the
// user switched away from never paints.
func (d *daemon) launchLive(slot, pic string) {
	mgr := d.ensureLive()
	gen := mgr.begin(slot)
	if _, err := exec.LookPath(liveDaemon); err != nil {
		log.Printf("live wallpaper: %s not on PATH (build it with ryoku/shell/livewall/build.sh); showing the clip's still frame", liveDaemon)
		return
	}
	go func() {
		capW := liveCapWidth()
		src := livewallSource(pic, capW)
		if src == "" || mgr.stale(slot, gen) {
			return
		}
		args := []string{src, capW, liveFit()}
		if slot != "" {
			args = append(args, slot) // bind the player to this output
		}
		cmd := exec.Command(liveDaemon, args...)
		stdout, err := cmd.StdoutPipe()
		if err != nil || cmd.Start() != nil {
			return
		}
		if !mgr.attach(slot, gen, cmd) {
			killProc(cmd)
			_ = cmd.Wait()
			return
		}
		// Step the backdrop aside only once the player has painted (READY); until
		// then the still holds the frame, so the hand-off shows no black seam. The
		// liveAlive guard keeps a player that died first on the still, not a hole.
		go func() {
			liveReady(stdout, 6*time.Second)
			if !mgr.stale(slot, gen) && liveAlive() {
				d.wall.setLiveSlot(slot, true)
			}
		}()
		_ = cmd.Wait()
		mgr.done(slot, gen, cmd)
		if !mgr.stale(slot, gen) {
			d.wall.setLiveSlot(slot, false)
		}
	}()
}

// showSavedLive paints the still and (re)launches a player for every live output
// described by st, following the current motion opts. Used by live-reload.
func (d *daemon) showSavedLive(st wallStateFile) {
	d.ensureLive()
	cfit := liveContentFit()
	if isVideo(st.Default) && isFile(st.Default) {
		if still := liveFrame(st.Default); still != "" {
			_ = d.wall.showFrame(still, nil, cfit)
		}
		for _, s := range liveSlots() {
			if _, ov := st.Outputs[s]; ov {
				continue
			}
			if s != "" {
				if still := liveFrame(st.Default); still != "" {
					_ = d.wall.showOutput(s, still, nil, cfit)
				}
			}
			d.launchLive(s, st.Default)
		}
	}
	for name, p := range st.Outputs {
		if name == "" || !(isVideo(p) && isFile(p)) {
			continue
		}
		if still := liveFrame(p); still != "" {
			_ = d.wall.showOutput(name, still, nil, cfit)
		}
		d.launchLive(name, p)
	}
}

// restoreState is the daemon's first wallpaper pass (init): it repaints every
// output from the saved per-output state. A surviving player (KillMode=process
// orphans it on a restart) is adopted -- the still is republished and the backdrop
// marked live so it never covers a still-playing video -- rather than relaunched.
// With no saved default it falls back to a bag pick (today's first-run behaviour).
func (d *daemon) restoreState() {
	d.ensureLive()
	st := readWallState()
	if st.Default == "" || !isFile(st.Default) {
		if pic := popBag(); pic != "" {
			_ = d.applyPick("init", pic, "")
		}
		return
	}
	adopt := stateHasVideo(st) && liveAlive()
	cfit := liveContentFit()
	if isVideo(st.Default) {
		if still := liveFrame(st.Default); still != "" {
			_ = d.wall.showFrame(still, nil, cfit)
		}
		for _, s := range liveSlots() {
			if _, ov := st.Outputs[s]; ov {
				continue
			}
			if s != "" {
				if still := liveFrame(st.Default); still != "" {
					_ = d.wall.showOutput(s, still, nil, cfit)
				}
			}
			if adopt {
				d.wall.setLiveSlot(s, true)
			} else {
				d.launchLive(s, st.Default)
			}
		}
	} else {
		_ = d.wall.showFrame(st.Default, nil, "") // no reveal on a login
	}
	for name, p := range st.Outputs {
		if name == "" || !isFile(p) {
			continue
		}
		if isVideo(p) {
			if still := liveFrame(p); still != "" {
				_ = d.wall.showOutput(name, still, nil, cfit)
			}
			if adopt {
				d.wall.setLiveOutput(name, true)
			} else {
				d.launchLive(name, p)
			}
		} else {
			_ = d.wall.showOutput(name, p, nil, "")
		}
	}
	if adopt {
		d.adoptWatch()
	}
	d.scheduleTheme()
}

// adoptWatch drops every live flag once no ryoku-livewall survives, for players
// the previous daemon left running. Until then the adopted stills + live flags
// keep the backdrops standing aside so the videos show.
func (d *daemon) adoptWatch() {
	go func() {
		for {
			select {
			case <-d.quit:
				return
			case <-time.After(2 * time.Second):
			}
			if !liveAlive() {
				d.wall.setLiveAll(false)
				return
			}
		}
	}()
}

// reconcileLive brings the running players in line with the connected outputs
// after a hotplug: it starts a player for any connected live output missing one
// (a monitor plugged in under a broadcast/live wallpaper) and stops players for
// outputs that vanished. A no-op when nothing live is configured or the output
// list can't be read.
func (d *daemon) reconcileLive() {
	mgr := d.ensureLive()
	st := readWallState()
	if !stateHasVideo(st) {
		return
	}
	slots := connectedOutputs()
	if len(slots) == 0 {
		return
	}
	cfit := liveContentFit()
	connected := map[string]bool{}
	for _, s := range slots {
		connected[s] = true
		p := st.currentFor(s)
		if !(isVideo(p) && isFile(p)) || mgr.running(s) {
			continue
		}
		if still := liveFrame(p); still != "" {
			_ = d.wall.showOutput(s, still, nil, cfit)
		}
		d.launchLive(s, p)
	}
	for _, s := range mgr.liveNames() {
		if s != "" && !connected[s] {
			mgr.stop(s)
			d.wall.setLiveOutput(s, false)
		}
	}
}

// liveReady blocks until the player prints READY (its first painted frame), its
// stdout closes, or the timeout elapses, reporting whether READY was seen. It
// drains the pipe so the player never blocks on stdout.
func liveReady(stdout io.ReadCloser, timeout time.Duration) bool {
	seen := make(chan bool, 1)
	go func() {
		r := bufio.NewReader(stdout)
		got := false
		for {
			line, err := r.ReadString('\n')
			if !got && strings.TrimSpace(line) == "READY" {
				got = true
				seen <- true
			}
			if err != nil {
				if !got {
					seen <- false
				}
				return
			}
		}
	}()
	select {
	case ok := <-seen:
		return ok
	case <-time.After(timeout):
		return false
	}
}

// liveFrame: one still from the video, for the backdrop to hold while livewall
// starts and for matugen to read. Cached per clip, mtime and offset like the
// transcode is, and renamed into place. It used to be one shared file, so a
// ryowalls preview of another clip handed the daemon that clip's frame: the
// desktop showed the wrong video and took its light/dark from it. "" on failure,
// so the palette keeps its previous value.
func liveFrame(video string) string {
	st, err := os.Stat(video)
	if err != nil {
		return ""
	}
	off := frameOffset(video)
	dir := filepath.Join(stateDir(), "ryoku-live-frames")
	name := strings.TrimSuffix(filepath.Base(video), filepath.Ext(video))
	out := filepath.Join(dir, name+"-"+strconv.FormatInt(st.ModTime().Unix(), 10)+"-"+off+".png")
	if isFile(out) {
		return out
	}
	if os.MkdirAll(dir, 0o755) != nil {
		return ""
	}
	tmp := out + ".tmp." + strconv.Itoa(os.Getpid()) + "-" + strconv.FormatInt(time.Now().UnixNano(), 10) + ".png"
	// -update says "one image, not a sequence": without it ffmpeg 8 warns, and a
	// warning here is an error in the next release.
	err = exec.Command("ffmpeg", "-y", "-ss", off, "-i", video,
		"-frames:v", "1", "-update", "1", tmp).Run()
	if err != nil || !isFile(tmp) {
		_ = os.Remove(tmp)
		return ""
	}
	if os.Rename(tmp, out) != nil {
		_ = os.Remove(tmp)
		return ""
	}
	pruneLiveFrames(dir)
	return out
}

// pruneLiveFrames bounds the still cache: a 4K frame is a couple of MB and a
// wallpaper library grows.
const liveFrameKeep = 24

func pruneLiveFrames(dir string) {
	// the one shared still this cache replaced, on a box that still carries it
	_ = os.Remove(filepath.Join(stateDir(), "ryoku-live-frame.png"))
	ents, err := os.ReadDir(dir)
	if err != nil || len(ents) <= liveFrameKeep {
		return
	}
	type still struct {
		path string
		mod  time.Time
	}
	var stills []still
	for _, e := range ents {
		info, err := e.Info()
		if err != nil || e.IsDir() {
			continue
		}
		stills = append(stills, still{filepath.Join(dir, e.Name()), info.ModTime()})
	}
	if len(stills) <= liveFrameKeep {
		return
	}
	sort.Slice(stills, func(i, j int) bool { return stills[i].mod.After(stills[j].mod) })
	for _, s := range stills[liveFrameKeep:] {
		_ = os.Remove(s.path)
	}
}

// frameOffset: seconds into the video that matugen samples, from the per-video
// sticky tune; "1" by default.
func frameOffset(video string) string {
	b, err := os.ReadFile(ryowallsTune())
	if err != nil {
		return "1"
	}
	var t struct {
		Image string  `json:"image"`
		Frame float64 `json:"frame"`
	}
	if json.Unmarshal(b, &t) == nil && t.Image == video && t.Frame > 0 {
		return strconv.FormatFloat(t.Frame, 'f', 2, 64)
	}
	return "1"
}

// liveEncRev marks the transcode flags a cached clip was produced with. Bump it
// whenever they change, so old clips are re-encoded instead of being replayed
// with settings livewall no longer expects.
const liveEncRev = "2"

// liveFps: the rate a clip is transcoded to, and so the rate livewall decodes it
// at (the daemon paces off the stream's own frame rate). 30 keeps software decode
// affordable on any machine; the Performance page's 60fps switch roughly doubles
// that cost for hardware with the headroom. A source that cannot supply 60 stays
// at 30 rather than being padded with duplicate frames livewall would decode for
// nothing.
func liveFps(pic string) string {
	if !perfFlag("liveWallpaper60") {
		return "30"
	}
	out, err := exec.Command("ffprobe", "-v", "error", "-select_streams", "v:0",
		"-show_entries", "stream=r_frame_rate", "-of", "default=nw=1:nk=1", pic).Output()
	if err != nil {
		return "30"
	}
	// r_frame_rate is a rational: "60/1", or "60000/1001" for NTSC rates.
	num, den, _ := strings.Cut(strings.TrimSpace(string(out)), "/")
	n, err := strconv.ParseFloat(num, 64)
	if err != nil {
		return "30"
	}
	d, err := strconv.ParseFloat(den, 64)
	if err != nil || d <= 0 {
		d = 1
	}
	if n/d < 50 {
		return "30"
	}
	return "60"
}

// livewallSource: the cached H.264 that livewall decodes, transcoded once per
// clip + cap width (keyed by path, mtime, cap, fps and encoder rev). Software-decoding
// the 4K source directly would blow the RAM budget; downscaling to the screen's
// width keeps livewall bounded while matching the panel, so the video is not
// upscaled to a blur. B-frames are off: they buy compression this cache does not
// need, and each one the decoder holds for reordering is a full frame of RAM
// (~3.5 MB at 2048x1152) charged against livewall's budget for the clip's life.
// "" if ffmpeg fails, so the caller keeps the clip's still frame.
func livewallSource(pic, capW string) string {
	st, err := os.Stat(pic)
	if err != nil {
		return ""
	}
	base := os.Getenv("XDG_CACHE_HOME")
	if base == "" {
		base = filepath.Join(os.Getenv("HOME"), ".cache")
	}
	dir := filepath.Join(base, "ryoku", "livewall")
	name := strings.TrimSuffix(filepath.Base(pic), filepath.Ext(pic))
	fps := liveFps(pic)
	out := filepath.Join(dir, name+"-"+strconv.FormatInt(st.ModTime().Unix(), 10)+"-"+capW+"-"+fps+"-r"+liveEncRev+".mp4")
	if isFile(out) {
		return out
	}
	if os.MkdirAll(dir, 0o755) != nil {
		return ""
	}
	// pid-unique tmp: two rapid sets of the same clip transcode concurrently
	// (the generation guard drops the launch, not the encode); a shared tmp
	// would interleave both writers into a corrupt cached video.
	tmp := out + ".tmp." + strconv.Itoa(os.Getpid()) + "-" + strconv.FormatInt(time.Now().UnixNano(), 10) + ".mp4"
	err = exec.Command("ffmpeg", "-y", "-i", pic,
		"-vf", "scale='min("+capW+",iw)':-2:flags=bicubic", "-r", fps,
		"-c:v", "libx264", "-preset", "veryfast", "-bf", "0", "-pix_fmt", "yuv420p", "-an", tmp).Run()
	if err != nil || !isFile(tmp) {
		_ = os.Remove(tmp)
		return ""
	}
	if os.Rename(tmp, out) != nil {
		_ = os.Remove(tmp)
		return ""
	}
	return out
}

// scheduleTheme: nudge the palette/border worker, non-blocking. buffered channel
// coalesces a burst into the latest, so theming runs once the presses settle.
func (d *daemon) scheduleTheme() {
	select {
	case d.paintSig <- struct{}{}:
	default:
	}
}

// paintWorker: regen the palette for whatever is on screen, reload hypr
// (config-only, monitors untouched), wake the LED worker. matugenApply extracts
// the palette to ~/.cache/ryoku/colors.json (the desktop visualiser live-
// watches it, so its spectrum retunes too) and fans that one palette into every
// app config. reads state every pass, so a coalesced burst themes the final
// wallpaper. runs for the life of the daemon.
func (d *daemon) paintWorker() {
	for range d.paintSig {
		// Self-heal a stale signature before any hyprctl fork: if Hyprland
		// restarted under this persisted daemon, re-bind so the border reload
		// and the cursor recolour reach the live compositor (see hyprsig.go).
		ensureLiveHyprSignature()
		// Before deciding who owns the palette: the surfaces floating on the
		// picture need its luminance map either way, named theme or not.
		writeWallpaperTone(readState())
		// A fixed named theme owns the palette: fan its curated palette into the
		// same app templates the wallpaper path renders, then reload, so apps
		// follow the shell rail's master instead of the last wallpaper render. No
		// wallpaper is needed, so this runs before the wallpaper-file guard below.
		if staticThemeActive() {
			if name := staticThemeName(); name != "" {
				if err := d.matugenApplyStatic(name); err != nil {
					fmt.Fprintf(os.Stderr, "paintWorker matugen static: %v\n", err)
				} else {
					_ = exec.Command("hyprctl", "reload", "config-only").Run()
					select {
					case d.ledsSig <- struct{}{}:
					default:
					}
				}
			}
			continue
		}
		pic := readState()
		if pic == "" || !isFile(pic) {
			continue
		}
		// The dynamic pipeline owns the palette only while Match wallpaper is on
		// and no fixed named theme is selected; otherwise it idles so it never
		// fights the theme daemon's static palette.
		if !matugenFollows() {
			continue
		}
		// matugen reads a still image, so a video is themed off one extracted frame.
		src := pic
		if isVideo(pic) {
			if src = liveFrame(pic); src == "" {
				continue
			}
		}
		if err := d.matugenApply(src); err != nil {
			fmt.Fprintf(os.Stderr, "paintWorker matugen: %v\n", err)
		}
		_ = exec.Command("hyprctl", "reload", "config-only").Run()
		select {
		case d.ledsSig <- struct{}{}:
		default:
		}
	}
}

// themeAppsEnabled reports whether the palette should reach GTK / GUI apps.
// Mirrors the hub control plane: a theme.json without the key reads as on, so
// existing installs keep the themed apps they already had.
func themeAppsEnabled() bool {
	base := os.Getenv("XDG_CONFIG_HOME")
	if base == "" {
		base = filepath.Join(os.Getenv("HOME"), ".config")
	}
	b, err := os.ReadFile(filepath.Join(base, "ryoku", "theme.json"))
	if err != nil {
		return true
	}
	var s struct {
		ThemeApps *bool `json:"themeApps"`
	}
	if json.Unmarshal(b, &s) != nil || s.ThemeApps == nil {
		return true
	}
	return *s.ThemeApps
}

// blankGtk drops the Ryoku palette from the generated GTK stylesheets, so GTK /
// libadwaita apps fall back to their own stock colours when app theming is off.
func blankGtk(cfgBase string) {
	const off = "/* Ryoku: app theming is off; apps use their own colours. */\n"
	for _, rel := range []string{"gtk-3.0/gtk.css", "gtk-4.0/gtk.css"} {
		p := filepath.Join(cfgBase, rel)
		_ = os.MkdirAll(filepath.Dir(p), 0o755)
		_ = os.WriteFile(p, []byte(off), 0o644)
	}
}

// ryowallsTune: the ryowalls per-image tune (ryoku-ryowalls.json). frameOffset
// reads the sampled frame second for a video wallpaper from it.
func ryowallsTune() string { return filepath.Join(stateDir(), "ryoku-ryowalls.json") }

// ledsWorker: push the new accent at the lighting devices the user put under
// Ryoku's control. `ryoku-hub lighting accent` returns without touching anything
// while lighting is off or no device is adopted, so an untouched install never
// talks to a keyboard. Reaching hardware is slow (seconds on first use), so it
// lives on its own coalescing worker and never touches the wallpaper hot path.
// Runs for the life of the daemon.
func (d *daemon) ledsWorker() {
	for range d.ledsSig {
		_ = exec.Command(findHubBin(), "lighting", "accent").Run()
	}
}

// listPics: the Super+W pool. images from ~/Pictures/Wallpapers and videos from
// ~/Pictures/livewalls, so the switcher cycles both the same way.
func listPics() []string {
	var pics []string
	for _, root := range []string{wallDir(), liveDir()} {
		if resolved, err := filepath.EvalSymlinks(root); err == nil {
			root = resolved
		}
		_ = filepath.WalkDir(root, func(p string, info os.DirEntry, err error) error {
			if err != nil || info.IsDir() {
				return nil
			}
			switch strings.ToLower(filepath.Ext(p)) {
			case ".jpg", ".jpeg", ".png", ".webp", ".mp4", ".webm", ".mkv", ".mov":
				pics = append(pics, p)
			}
			return nil
		})
	}
	return pics
}

// popBag: next wallpaper out of a shuffled bag. refills + reshuffles when empty
// so every wallpaper shows once per cycle.
func popBag() string {
	for refilled := false; ; {
		lines := readLines(wallBag())
		if len(lines) == 0 {
			if refilled {
				return ""
			}
			refillBag()
			refilled = true
			continue
		}
		pic := lines[0]
		writeLines(wallBag(), lines[1:])
		if isFile(pic) {
			return pic
		}
	}
}

func refillBag() {
	pics := listPics()
	if len(pics) == 0 {
		return
	}
	rand.Shuffle(len(pics), func(i, j int) { pics[i], pics[j] = pics[j], pics[i] })
	if cur := readState(); cur != "" && len(pics) > 1 && pics[0] == cur {
		pics = append(pics[1:], cur)
	}
	_ = os.MkdirAll(stateDir(), 0o755)
	writeLines(wallBag(), pics)
}

func readState() string {
	b, err := os.ReadFile(wallState())
	if err != nil {
		return ""
	}
	return strings.TrimSpace(string(b))
}

func readLines(path string) []string {
	b, err := os.ReadFile(path)
	if err != nil {
		return nil
	}
	var out []string
	for _, l := range strings.Split(string(b), "\n") {
		if l = strings.TrimSpace(l); l != "" {
			out = append(out, l)
		}
	}
	return out
}

func writeLines(path string, lines []string) {
	data := ""
	if len(lines) > 0 {
		data = strings.Join(lines, "\n") + "\n"
	}
	_ = os.WriteFile(path, []byte(data), 0o644)
}

func isFile(p string) bool {
	st, err := os.Stat(p)
	return err == nil && !st.IsDir()
}
