package main

import "testing"

// Only a real fullscreen hides the wallpaper. Hyprland reports a mode here:
// 0 none, 1 maximised, 2 fullscreen, and a maximised window still leaves the
// bars and the desktop edges showing.
func TestParseAnyFullscreen(t *testing.T) {
	cases := []struct {
		name string
		json string
		want bool
	}{
		{"nothing fullscreen", `[{"fullscreen":0},{"fullscreen":0}]`, false},
		{"maximised is not fullscreen", `[{"fullscreen":1}]`, false},
		{"one fullscreen", `[{"fullscreen":0},{"fullscreen":2}]`, true},
		{"older bool form", `[{"fullscreen":true}]`, true},
		{"older bool form, false", `[{"fullscreen":false}]`, false},
		{"no clients", `[]`, false},
		{"garbage keeps the wallpaper running", `not json`, false},
	}
	for _, c := range cases {
		if got := parseAnyFullscreen([]byte(c.json)); got != c.want {
			t.Errorf("%s: got %v want %v", c.name, got, c.want)
		}
	}
}

// liveShouldStop pauses the video wallpaper on a real fullscreen (pause enabled)
// or whenever Power Saver is shaping the desktop, regardless of the fullscreen
// toggle.
func TestLiveShouldStop(t *testing.T) {
	cases := []struct {
		name              string
		pauseOnFullscreen bool
		fullscreen        bool
		saver             bool
		want              bool
	}{
		{"idle desktop", true, false, false, false},
		{"fullscreen, pause on", true, true, false, true},
		{"fullscreen, pause off", false, true, false, false},
		{"power saver, no fullscreen", true, false, true, true},
		{"power saver overrides pause-off", false, false, true, true},
	}
	for _, c := range cases {
		if got := liveShouldStop(c.pauseOnFullscreen, c.fullscreen, c.saver); got != c.want {
			t.Errorf("%s: got %v want %v", c.name, got, c.want)
		}
	}
}
