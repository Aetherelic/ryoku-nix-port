package main

import "testing"

// route = the single source of truth for which panel a keybind toggles; a wrong
// entry silently opens the wrong surface, so pin every command.
func TestRoute(t *testing.T) {
	cases := []struct {
		cmd, config, target, fn string
	}{
		{"launcher", "launcher", "launcher", "toggle"},
		{"overview", "overview", "overview", "toggle"},
		{"ryolayer", "ryolayer", "ryolayer", "toggle"},
		{"power", "pill", "pill", "power"},
	}
	for _, c := range cases {
		config, target, fn, ok := route(c.cmd)
		if !ok {
			t.Fatalf("route(%q) not ok", c.cmd)
		}
		if config != c.config || target != c.target || fn != c.fn {
			t.Fatalf("route(%q) = (%s,%s,%s), want (%s,%s,%s)", c.cmd, config, target, fn, c.config, c.target, c.fn)
		}
	}
	for _, cmd := range []string{"clipboard", "link", "inbox", "mixer", "calendar", "battery", "stash", "toolkit", "utilities", "system", "workspaces", "sysinfo", "peek", "hide", "voice", "lock", "wallpaper", "wallpaper-switcher", "reload", "status", "ping", "quit", "bogus", ""} {
		if _, _, _, ok := route(cmd); ok {
			t.Fatalf("route(%q) should not be a single IPC call", cmd)
		}
	}
}
