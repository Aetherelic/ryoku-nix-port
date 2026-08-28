package main

import "testing"

// A custom keybind with release mode on must emit the Hyprland release flag, and
// a normal (press) keybind must not carry it. The Hub writes this into
// settings.lua, so a regression would silently change when shortcuts fire.
func TestGenKeybindReleaseFlag(t *testing.T) {
	press := genKeybind(Keybind{Keys: "SUPER + M", Action: "exec", Value: "kitty"})
	if got, want := press, "hl.bind(\"SUPER + M\", hl.dsp.exec_cmd(\"kitty\"))\n"; got != want {
		t.Fatalf("press bind:\n got %q\nwant %q", got, want)
	}

	release := genKeybind(Keybind{Keys: "SUPER + M", Action: "exec", Value: "kitty", Release: true})
	if got, want := release, "hl.bind(\"SUPER + M\", hl.dsp.exec_cmd(\"kitty\"), { release = true })\n"; got != want {
		t.Fatalf("release bind:\n got %q\nwant %q", got, want)
	}
}
