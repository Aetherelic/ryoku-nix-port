package main

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestIsVideo(t *testing.T) {
	cases := map[string]bool{
		"/x/a.mp4": true, "/x/a.MP4": true, "/x/a.webm": true,
		"/x/a.mkv": true, "/x/a.mov": true,
		"/x/a.jpg": false, "/x/a.png": false, "/x/a.gif": false, "/x/plain": false,
	}
	for p, want := range cases {
		if got := isVideo(p); got != want {
			t.Errorf("isVideo(%q) = %v, want %v", p, got, want)
		}
	}
}

func TestFrameOffset(t *testing.T) {
	dir := t.TempDir()
	t.Setenv("XDG_STATE_HOME", dir)
	tune := filepath.Join(dir, "ryoku-ryowalls.json")
	video := "/home/x/Pictures/livewalls/clip.mp4"

	// no tune -> the auto default
	if got := frameOffset(video); got != "1" {
		t.Fatalf("no tune: got %q want 1", got)
	}
	// a tune for this video -> its chosen second
	_ = os.WriteFile(tune, []byte(`{"image":"`+video+`","frame":3.5}`), 0o644)
	if got := frameOffset(video); got != "3.50" {
		t.Fatalf("matching tune: got %q want 3.50", got)
	}
	// a tune keyed to another video never bleeds across
	if got := frameOffset("/home/x/other.mp4"); got != "1" {
		t.Fatalf("other video: got %q want 1", got)
	}
	// frame 0 falls back to the default
	_ = os.WriteFile(tune, []byte(`{"image":"`+video+`","frame":0}`), 0o644)
	if got := frameOffset(video); got != "1" {
		t.Fatalf("zero frame: got %q want 1", got)
	}
}

// liveFps: 30 unless the Performance page's 60fps switch is on AND the clip can
// actually supply 60, so a 30fps source is never padded up into double the decode.
func TestLiveFps(t *testing.T) {
	bin := t.TempDir()
	t.Setenv("PATH", bin+string(os.PathListSeparator)+os.Getenv("PATH"))
	cfg := t.TempDir()
	t.Setenv("XDG_CONFIG_HOME", cfg)
	if err := os.MkdirAll(filepath.Join(cfg, "ryoku"), 0o755); err != nil {
		t.Fatal(err)
	}
	perf := filepath.Join(cfg, "ryoku", "performance.json")
	fakeProbe := func(out string) {
		body := "#!/bin/sh\nprintf '%s\\n' " + out + "\n"
		if err := os.WriteFile(filepath.Join(bin, "ffprobe"), []byte(body), 0o755); err != nil {
			t.Fatal(err)
		}
	}
	vid := filepath.Join(t.TempDir(), "clip.mp4")
	if err := os.WriteFile(vid, []byte("x"), 0o644); err != nil {
		t.Fatal(err)
	}

	fakeProbe("60/1")
	if err := os.WriteFile(perf, []byte(`{"liveWallpaper60":false}`), 0o644); err != nil {
		t.Fatal(err)
	}
	if got := liveFps(vid); got != "30" {
		t.Errorf("switch off: got %q want 30", got)
	}

	if err := os.WriteFile(perf, []byte(`{"liveWallpaper60":true}`), 0o644); err != nil {
		t.Fatal(err)
	}
	if got := liveFps(vid); got != "60" {
		t.Errorf("60fps source: got %q want 60", got)
	}
	fakeProbe("60000/1001") // 59.94, still a 60-class clip
	if got := liveFps(vid); got != "60" {
		t.Errorf("59.94fps source: got %q want 60", got)
	}
	fakeProbe("30/1")
	if got := liveFps(vid); got != "30" {
		t.Errorf("30fps source must not be padded to 60: got %q", got)
	}
	// an unreadable rate falls back rather than guessing
	fakeProbe("N/A")
	if got := liveFps(vid); got != "30" {
		t.Errorf("unparseable rate: got %q want 30", got)
	}
}

// livewallSource transcodes a clip once and caches it (keyed by path+mtime+cap): a
// second call reuses the cache without re-running ffmpeg.
func TestLivewallSource(t *testing.T) {
	bin := t.TempDir()
	cache := t.TempDir()
	t.Setenv("XDG_CACHE_HOME", cache)
	runs := filepath.Join(cache, "ffmpeg.runs")
	// fake ffmpeg: append a run marker, then create the output (its last arg).
	body := `printf x >> "` + runs + `"; for a in "$@"; do o="$a"; done; : > "$o"`
	if err := os.WriteFile(filepath.Join(bin, "ffmpeg"), []byte("#!/bin/sh\n"+body+"\n"), 0o755); err != nil {
		t.Fatal(err)
	}
	t.Setenv("PATH", bin+string(os.PathListSeparator)+os.Getenv("PATH"))

	vid := filepath.Join(t.TempDir(), "clip.mp4")
	if err := os.WriteFile(vid, []byte("x"), 0o644); err != nil {
		t.Fatal(err)
	}
	first := livewallSource(vid, "1280")
	if first == "" || !strings.HasSuffix(first, ".mp4") {
		t.Fatalf("first transcode returned %q", first)
	}
	if !strings.Contains(first, filepath.Join("ryoku", "livewall")) {
		t.Errorf("cache not under ryoku/livewall: %q", first)
	}
	if second := livewallSource(vid, "1280"); second != first {
		t.Errorf("cache key not stable: %q != %q", second, first)
	}
	if b, _ := os.ReadFile(runs); len(b) != 1 {
		t.Errorf("ffmpeg ran %d times, want 1 (miss then cache reuse)", len(b))
	}
}

// liveFrame caches one still per clip + mtime + offset. The still used to be a
// single shared file, which is how a preview of one clip could hand the daemon
// another clip's frame.
func TestLiveFramePerClip(t *testing.T) {
	state := t.TempDir()
	t.Setenv("XDG_STATE_HOME", state)
	bin := t.TempDir()
	runs := filepath.Join(state, "ffmpeg.runs")
	body := `printf x >> "` + runs + `"; for a in "$@"; do o="$a"; done; : > "$o"`
	if err := os.WriteFile(filepath.Join(bin, "ffmpeg"), []byte("#!/bin/sh\n"+body+"\n"), 0o755); err != nil {
		t.Fatal(err)
	}
	t.Setenv("PATH", bin+string(os.PathListSeparator)+os.Getenv("PATH"))

	clips := t.TempDir()
	one := filepath.Join(clips, "one.mp4")
	two := filepath.Join(clips, "two.mp4")
	for _, c := range []string{one, two} {
		if err := os.WriteFile(c, []byte("x"), 0o644); err != nil {
			t.Fatal(err)
		}
	}

	first := liveFrame(one)
	if first == "" || !strings.Contains(first, "ryoku-live-frames") {
		t.Fatalf("still for one.mp4 = %q, want a file under ryoku-live-frames", first)
	}
	if again := liveFrame(one); again != first {
		t.Errorf("second call = %q, want the cached %q", again, first)
	}
	if b, _ := os.ReadFile(runs); len(b) != 1 {
		t.Errorf("ffmpeg ran %d times for one clip, want 1", len(b))
	}
	if other := liveFrame(two); other == first {
		t.Errorf("two.mp4 reused one.mp4's still (%q): a shared still is the bug", other)
	}

	// The ryowalls frame slider picks a different second: that is a different
	// still, not an overwrite of the one already on screen.
	tune := filepath.Join(state, "ryoku-ryowalls.json")
	if err := os.WriteFile(tune, []byte(`{"image":"`+one+`","frame":4}`), 0o644); err != nil {
		t.Fatal(err)
	}
	if moved := liveFrame(one); moved == first {
		t.Errorf("offset 4 reused the offset 1 still (%q)", moved)
	}
}

// A clip's still is revealed in the geometry livewall will paint the VIDEO in, not
// the user's image fit: the two are separate knobs, and framing the still by the
// image fit made the wallpaper jump scale the instant the clip took over. Pins the
// pin: showFrame carries it, republish keeps it, and the next image switch drops it.
func TestLiveStillPinsTheVideoFit(t *testing.T) {
	t.Setenv("XDG_CONFIG_HOME", t.TempDir()) // no shell.json -> image fit is Cover
	dir := t.TempDir()
	src := filepath.Join(dir, "frame.png")
	if err := os.WriteFile(src, []byte("x"), 0o644); err != nil {
		t.Fatal(err)
	}
	w := &wallSurface{cacheDir: filepath.Join(dir, "cache")}

	if err := w.showFrame(src, nil, "Contain"); err != nil {
		t.Fatalf("showFrame: %v", err)
	}
	if w.def.fit != "Contain" {
		t.Errorf("pinned fit = %q, want Contain", w.def.fit)
	}
	w.republish()
	if w.def.fit != "Contain" {
		t.Errorf("republish dropped the pin: fit = %q, want Contain", w.def.fit)
	}
	if err := w.showTransition(src, nil); err != nil {
		t.Fatalf("showTransition: %v", err)
	}
	if w.def.fit != "Cover" {
		t.Errorf("image switch kept the pin: fit = %q, want the user's Cover", w.def.fit)
	}
}

// liveContentFit speaks the backdrop's fillMode names, so a letterboxed clip is
// revealed letterboxed and a covering clip is revealed covering.
func TestLiveContentFit(t *testing.T) {
	home := t.TempDir()
	t.Setenv("XDG_CONFIG_HOME", home)
	if err := os.MkdirAll(filepath.Join(home, "ryoku"), 0o755); err != nil {
		t.Fatal(err)
	}
	cfg := filepath.Join(home, "ryoku", "ryowalls.json")
	for _, c := range []struct{ json, want string }{
		{`{"liveFit":"fit"}`, "Contain"},
		{`{"liveFit":"fill"}`, "Cover"},
		{`{}`, "Cover"},
	} {
		if err := os.WriteFile(cfg, []byte(c.json), 0o644); err != nil {
			t.Fatal(err)
		}
		if got := liveContentFit(); got != c.want {
			t.Errorf("liveContentFit() with %s = %q, want %q", c.json, got, c.want)
		}
	}
}
