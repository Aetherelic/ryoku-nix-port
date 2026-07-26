package main

import (
	"bufio"
	"fmt"
	"net"
	"strings"
	"testing"
	"time"
)

// route = the single source of truth for which panel a keybind toggles; a wrong
// entry silently opens the wrong surface, so pin every command.
func TestRoute(t *testing.T) {
	cases := []struct {
		cmd, config, target, fn string
	}{
		{"launcher", "launcher", "launcher", "toggle"},
		{"overview", "overview", "overview", "toggle"},
		{"ryolayer", "ryolayer", "ryolayer", "toggle"},
		{"power", "pill", "pill", "openSurface"},
		{"menu quick-settings", "pill", "pill", "openSurface"},
		{"menu clock", "pill", "pill", "openSurface"},
		{"menu app-launcher", "pill", "pill", "openSurface"},
		{"menu clipboard", "pill", "pill", "openSurface"},
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
	for _, cmd := range []string{"menu", "menu bogus", "menu clock extra", "bar", "bar left", "bar left toggle"} {
		if _, _, _, ok := route(cmd); ok {
			t.Fatalf("route(%q) should not be a single IPC call", cmd)
		}
	}
}

func TestDispatchFrameSurface(t *testing.T) {
	t.Setenv("XDG_RUNTIME_DIR", t.TempDir())
	listener, err := net.Listen("unix", pillSockPath())
	if err != nil {
		t.Fatal(err)
	}
	defer listener.Close()

	calls := make(chan string, len(frameBarMenuIDs)+2)
	go func() {
		n := len(frameBarMenuIDs) + 2
		for range n {
			conn, err := listener.Accept()
			if err != nil {
				return
			}
			line, _ := bufio.NewReader(conn).ReadString('\n')
			calls <- strings.TrimSpace(line)
			_, _ = fmt.Fprintln(conn, "ok")
			conn.Close()
		}
	}()

	d := &daemon{sup: map[string]bool{"pill": true}, activeMon: "DP-1"}
	for id := range frameBarMenuIDs {
		if got := d.dispatch("menu " + id); got != "ok" {
			t.Errorf("dispatch(menu %s) = %q, want ok", id, got)
			continue
		}
		if got := <-calls; got != "openSurface DP-1 "+id {
			t.Errorf("pill IPC = %q, want %q", got, "openSurface DP-1 "+id)
		}
	}
	// menu close and bar edge toggles map to the reference close-all and the
	// per-edge bar operations, each on its own pill function.
	if got := d.dispatch("menu close"); got != "ok" {
		t.Errorf("dispatch(menu close) = %q, want ok", got)
	} else if got := <-calls; got != "closeAllMenus DP-1" {
		t.Errorf("menu close pill IPC = %q, want %q", got, "closeAllMenus DP-1")
	}
	if got := d.dispatch("bar left toggle"); got != "ok" {
		t.Errorf("dispatch(bar left toggle) = %q, want ok", got)
	} else if got := <-calls; got != "setBar DP-1 left toggle" {
		t.Errorf("bar toggle pill IPC = %q, want %q", got, "setBar DP-1 left toggle")
	}
	for _, command := range []string{"bar", "bar left", "bar sideways toggle", "bar left sideways", "menu", "menu bogus", "menu clock extra"} {
		if got := d.dispatch(command); got == "ok" {
			t.Errorf("dispatch(%q) = ok, want rejection", command)
		}
	}
}

func TestDispatchSurfaceSocketContracts(t *testing.T) {
	t.Setenv("XDG_RUNTIME_DIR", t.TempDir())
	t.Setenv("PATH", t.TempDir())
	listener, err := net.ListenUnix("unix", &net.UnixAddr{Name: pillSockPath(), Net: "unix"})
	if err != nil {
		t.Fatal(err)
	}
	defer listener.Close()

	d := &daemon{sup: map[string]bool{"pill": true}, activeMon: "DP-1"}
	for _, command := range []string{"bar", "bar left", "bar sideways toggle", "menu", "menu bogus"} {
		if got := d.dispatch(command); got == "ok" {
			t.Errorf("dispatch(%q) = ok, want rejection", command)
		}
	}
	if err := listener.SetDeadline(time.Now().Add(50 * time.Millisecond)); err != nil {
		t.Fatal(err)
	}
	if conn, err := listener.Accept(); err == nil {
		conn.Close()
		t.Fatal("rejected bar input sent pill IPC")
	} else if !strings.Contains(err.Error(), "i/o timeout") {
		t.Fatalf("Accept after rejected bar input = %v", err)
	}
	if err := listener.SetDeadline(time.Time{}); err != nil {
		t.Fatal(err)
	}
	calls := make(chan string, 2)
	go func() {
		for range 2 {
			conn, err := listener.Accept()
			if err != nil {
				return
			}
			line, _ := bufio.NewReader(conn).ReadString('\n')
			calls <- strings.TrimSpace(line)
			_, _ = fmt.Fprintln(conn, "ok")
			conn.Close()
		}
	}()

	if got := d.dispatch("power"); got != "ok" {
		t.Fatalf("dispatch(power) = %q, want ok", got)
	}
	if got := <-calls; got != "openSurface DP-1 power" {
		t.Fatalf("power pill IPC = %q", got)
	}
	if got := d.dispatch("voice"); got != "ok" {
		t.Fatalf("dispatch(voice) = %q, want ok", got)
	}
	if got := <-calls; got != "openSurface DP-1 voice-off" {
		t.Fatalf("voice pill IPC = %q", got)
	}
}
