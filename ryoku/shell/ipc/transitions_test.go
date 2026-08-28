package main

import (
	"encoding/json"
	"os"
	"path/filepath"
	"testing"
)

// presetIndexByName is the table lookup the tests use to validate picked names.
func presetIndexByName(name string) int {
	for i, p := range transitionPresets {
		if p.name == name {
			return i
		}
	}
	return -1
}

// TestTransitionPresetTable pins the full 22-preset set (the recovered 13 plus the
// nine ii expressive ports): every name is present exactly once, and each preset's
// args are well-formed for the reveal shader (a known kind, a bezier in range, a
// sane feathered edge, a wave amplitude iff the kind is wave, an angle only on the
// kinds that use one (wipe / wave / stripes), a pos anchor only on grow, and an
// origin that always resolves into the surface).
func TestTransitionPresetTable(t *testing.T) {
	want := []string{
		"silk_fade", "diagonal_silk", "dream_curtain", "liquid_ribbon",
		"iris_open", "corner_bloom", "spotlight_rise", "wander_iris",
		"vignette_close", "celeste_veil", "comet_streak", "aurora_ripple",
		"starfall_bloom",
		"mosaic_swell", "ember_burn", "pond_wake", "glass_scatter", "signal_tear",
		"cathode_wink", "shutter_sweep", "wax_descent", "page_turn",
	}
	if len(transitionPresets) != len(want) {
		t.Fatalf("preset count = %d, want %d", len(transitionPresets), len(want))
	}
	byName := map[string]transitionPreset{}
	for _, p := range transitionPresets {
		if _, dup := byName[p.name]; dup {
			t.Fatalf("duplicate preset name %q", p.name)
		}
		byName[p.name] = p
	}
	for _, n := range want {
		if _, ok := byName[n]; !ok {
			t.Fatalf("missing preset %q", n)
		}
	}

	for _, p := range transitionPresets {
		if !transitionKinds[p.kind] {
			t.Errorf("%s: kind %q not in the known set", p.name, p.kind)
		}
		for i, b := range p.bezier {
			if b < 0 || b > 1 {
				t.Errorf("%s: bezier[%d] = %v out of [0,1]", p.name, i, b)
			}
		}
		if p.edgeSoftness < 0 || p.edgeSoftness > 0.5 {
			t.Errorf("%s: edgeSoftness %v out of [0,0.5]", p.name, p.edgeSoftness)
		}
		if (p.waveAmp > 0) != (p.kind == "wave") {
			t.Errorf("%s: waveAmp %v inconsistent with kind %q", p.name, p.waveAmp, p.kind)
		}
		if p.kind != "wipe" && p.kind != "wave" && p.kind != "stripes" && p.angle != 0 {
			t.Errorf("%s: angle %v set on non-directional kind %q", p.name, p.angle, p.kind)
		}
		if p.kind == "grow" && p.pos == "" {
			t.Errorf("%s: grow preset has no pos anchor", p.name)
		}
		if p.kind != "grow" && p.pos != "" {
			t.Errorf("%s: pos %q set on non-grow kind %q", p.name, p.pos, p.kind)
		}
		if p.kind == "fade" && p.edgeSoftness != 0 {
			t.Errorf("%s: fade ignores edge softness, got %v", p.name, p.edgeSoftness)
		}
		if ox, oy := originForPreset(p); ox < 0 || ox > 1 || oy < 0 || oy > 1 {
			t.Errorf("%s: origin (%v,%v) out of [0,1]", p.name, ox, oy)
		}
	}
}

// TestPickTransitionNeverRepeats is the recovered picker contract: over 200 draws
// no pick ever equals the immediately previous one, and every pick is a known
// preset resolved with the shared duration and an in-surface origin.
func TestPickTransitionNeverRepeats(t *testing.T) {
	d := &daemon{lastTransition: -1}
	prev := ""
	for i := range 200 {
		tr := d.pickTransition()
		if tr == nil {
			t.Fatalf("draw %d: pickTransition returned nil", i)
		}
		if tr.Name == prev {
			t.Fatalf("draw %d repeated the previous pick %q", i, tr.Name)
		}
		if presetIndexByName(tr.Name) < 0 {
			t.Fatalf("draw %d: unknown preset %q", i, tr.Name)
		}
		if tr.DurationMs != transitionDurationMs {
			t.Fatalf("draw %d: duration = %d, want %d", i, tr.DurationMs, transitionDurationMs)
		}
		if tr.OriginX < 0 || tr.OriginX > 1 || tr.OriginY < 0 || tr.OriginY > 1 {
			t.Fatalf("draw %d: origin (%v,%v) out of [0,1]", i, tr.OriginX, tr.OriginY)
		}
		prev = tr.Name
	}
}

// transitionFor is the one rule both backends share: a user-driven switch reveals,
// the two re-apply paths do not. Pinned because a preset on init would animate the
// wallpaper at every login, and a preset on live-reload would re-reveal the clip
// already on screen after a settings change.
func TestTransitionForMode(t *testing.T) {
	d := &daemon{lastTransition: -1}
	for _, mode := range []string{"init", "live-reload"} {
		if tr := d.transitionFor(mode); tr != nil {
			t.Errorf("mode %q revealed with %q, want no preset", mode, tr.Name)
		}
	}
	for _, mode := range []string{"set", "next", "random"} {
		tr := d.transitionFor(mode)
		if tr == nil {
			t.Fatalf("mode %q got no preset, want a random one", mode)
		}
		if presetIndexByName(tr.Name) < 0 {
			t.Errorf("mode %q: unknown preset %q", mode, tr.Name)
		}
	}
}

// TestPickRandomImage covers the `wallpaper random` image draw: it never returns
// the current wallpaper, always returns a pool member, returns "" only when no
// other image exists, and never mutates the caller's slice.
func TestPickRandomImage(t *testing.T) {
	imgs := []string{"a.png", "b.png", "c.png"}
	for i := range 200 {
		got := pickRandomImage(imgs, "b.png")
		if got == "b.png" {
			t.Fatalf("draw %d returned the current image", i)
		}
		if got != "a.png" && got != "c.png" {
			t.Fatalf("draw %d returned %q, not from the pool", i, got)
		}
	}
	if got := pickRandomImage(imgs, "z.png"); presetIndexOfImage(imgs, got) < 0 {
		t.Fatalf("cur-not-in-pool returned %q, not from the pool", got)
	}
	if got := pickRandomImage([]string{"b.png"}, "b.png"); got != "" {
		t.Fatalf("single-current pool returned %q, want empty", got)
	}
	if got := pickRandomImage(nil, "b.png"); got != "" {
		t.Fatalf("empty pool returned %q, want empty", got)
	}
	orig := []string{"a.png", "b.png", "c.png"}
	_ = pickRandomImage(orig, "b.png")
	for i, w := range []string{"a.png", "b.png", "c.png"} {
		if orig[i] != w {
			t.Fatalf("input slice mutated at %d: %q", i, orig[i])
		}
	}
}

func presetIndexOfImage(imgs []string, p string) int {
	for i, x := range imgs {
		if x == p {
			return i
		}
	}
	return -1
}

// TestWallpaperRandomRevealsRandomImageWithTransition drives the real
// wallpaperApply("random") end to end in an isolated HOME (pkill / pgrep shimmed
// so stopLive never touches the desktop). It proves the mode picks a pool image
// that is never the current one and that the picked transition reaches the
// backdrop through the wallpaper state channel (the published frame carries a
// well-formed transition), mirroring the live acceptance path off-session.
func TestWallpaperRandomRevealsRandomImageWithTransition(t *testing.T) {
	home := t.TempDir()
	t.Setenv("HOME", home)
	t.Setenv("XDG_CONFIG_HOME", filepath.Join(home, ".config"))
	t.Setenv("XDG_CACHE_HOME", filepath.Join(home, ".cache"))
	t.Setenv("XDG_STATE_HOME", filepath.Join(home, ".local", "state"))

	bin := t.TempDir()
	t.Setenv("PATH", bin+string(os.PathListSeparator)+os.Getenv("PATH"))
	writeShim(t, filepath.Join(bin, "pkill"), "exit 1") // no live wallpaper to stop
	writeShim(t, filepath.Join(bin, "pgrep"), "exit 1")

	wallpapers := filepath.Join(home, "Pictures", "Wallpapers")
	if err := os.MkdirAll(wallpapers, 0o755); err != nil {
		t.Fatal(err)
	}
	var pics []string
	for _, n := range []string{"a.png", "b.png", "c.png"} {
		p := filepath.Join(wallpapers, n)
		writeFile(t, p, "fake-"+n) // the daemon only copies bytes; content is irrelevant here
		pics = append(pics, p)
	}
	cur := pics[0]
	if err := os.MkdirAll(stateDir(), 0o755); err != nil {
		t.Fatal(err)
	}
	writeFile(t, wallState(), cur+"\n")

	d := &daemon{lastTransition: -1}
	d.startWallpaper()

	if err := d.wallpaperApply("random", "", ""); err != nil {
		t.Fatalf("wallpaperApply(random) = %v", err)
	}

	got := readState()
	if got == cur {
		t.Fatalf("random re-picked the current wallpaper %q", cur)
	}
	if got != pics[1] && got != pics[2] {
		t.Fatalf("random picked %q, not from the pool", got)
	}

	var f struct {
		Default struct {
			Path       string            `json:"path"`
			Revision   int               `json:"revision"`
			Transition *pickedTransition `json:"transition"`
		} `json:"default"`
	}
	sub := d.wall.topic.subscribe()
	defer d.wall.topic.unsubscribe(sub)
	frame := <-sub.frames
	if err := json.Unmarshal(frame, &f); err != nil {
		t.Fatalf("published frame not JSON: %v", err)
	}
	if f.Default.Revision != 1 {
		t.Fatalf("first image revision = %d, want 1", f.Default.Revision)
	}
	tr := f.Default.Transition
	if tr == nil {
		t.Fatal("published frame carried no transition")
	}
	if presetIndexByName(tr.Name) < 0 {
		t.Fatalf("transition name %q is not a recovered preset", tr.Name)
	}
	if !transitionKinds[tr.Kind] {
		t.Fatalf("transition kind %q not in the known set", tr.Kind)
	}
	if tr.DurationMs != transitionDurationMs {
		t.Fatalf("transition duration = %d, want %d", tr.DurationMs, transitionDurationMs)
	}
	if tr.OriginX < 0 || tr.OriginX > 1 || tr.OriginY < 0 || tr.OriginY > 1 {
		t.Fatalf("transition origin (%v,%v) out of [0,1]", tr.OriginX, tr.OriginY)
	}
}

// transitionFor honours wallpaper.transition_preset: a known name is resolved
// verbatim on every user-driven switch, the "random" sentinel and an unknown
// name both fall back to the no-repeat picker, and the init / live-reload rule
// (no reveal on a re-apply path) still holds whatever the preference.
func TestTransitionForRespectsPreference(t *testing.T) {
	cfg := filepath.Join(t.TempDir(), ".config")
	t.Setenv("XDG_CONFIG_HOME", cfg)
	dir := filepath.Join(cfg, "ryoku")
	if err := os.MkdirAll(dir, 0o755); err != nil {
		t.Fatal(err)
	}
	shellJSON := filepath.Join(dir, "shell.json")
	setPref := func(v string) {
		b, err := json.Marshal(map[string]any{"wallpaper": map[string]any{"transition_preset": v}})
		if err != nil {
			t.Fatal(err)
		}
		if err := os.WriteFile(shellJSON, b, 0o644); err != nil {
			t.Fatal(err)
		}
	}

	d := &daemon{lastTransition: -1}

	// A named preset is honoured verbatim. Over many draws every switch reveals
	// with exactly it; the no-repeat picker never would, so this also proves the
	// picker is bypassed.
	want := "wander_iris"
	if presetIndexByName(want) < 0 {
		t.Fatalf("test fixture preset %q is not in the table", want)
	}
	setPref(want)
	for _, mode := range []string{"set", "next", "random"} {
		for i := range 50 {
			tr := d.transitionFor(mode)
			if tr == nil || tr.Name != want {
				t.Fatalf("mode %q draw %d: got %v, want honoured preset %q", mode, i, tr, want)
			}
		}
	}

	// The re-apply paths never animate, even with a named preference set.
	for _, mode := range []string{"init", "live-reload"} {
		if tr := d.transitionFor(mode); tr != nil {
			t.Errorf("mode %q with a preference revealed with %q, want no preset", mode, tr.Name)
		}
	}

	// An unknown name falls back to the picker rather than erroring or resolving a
	// bogus preset: every draw is still a known table entry.
	setPref("not_a_real_preset")
	for i := range 50 {
		tr := d.transitionFor("set")
		if tr == nil {
			t.Fatalf("unknown preference draw %d got no preset, want a random fallback", i)
		}
		if presetIndexByName(tr.Name) < 0 {
			t.Fatalf("unknown preference draw %d fell back to unknown preset %q", i, tr.Name)
		}
	}

	// The explicit "random" sentinel is the picker too.
	setPref(transitionRandom)
	if tr := d.transitionFor("set"); tr == nil || presetIndexByName(tr.Name) < 0 {
		t.Fatalf("random sentinel got %v, want a known preset", tr)
	}
}
