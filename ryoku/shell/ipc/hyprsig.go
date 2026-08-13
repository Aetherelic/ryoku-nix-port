package main

import (
	"net"
	"os"
	"path/filepath"
	"time"
)

// The daemon forks `hyprctl` for its compositor-facing work: the border reload
// after a palette change (wallpaper.go), the pointer recolour's `setcursor` (via
// the matugen post_hook), monitor/workspace queries, and its event-socket
// watcher (hyprwatch.go). Every one of those reads HYPRLAND_INSTANCE_SIGNATURE
// to find the live socket. The daemon is a systemd user service with
// Restart=always, so a mid-session restart (an OOM, a crash) is launched from
// the user manager's environment -- which lags the last
// dbus-update-activation-environment and can still name a compositor that exited
// days ago. hyprctl then dials a dead socket and every call silently no-ops:
// the window border keeps the previous wallpaper's colour and the cursor never
// re-tints, even though the palette files on disk are correct. Resolving the
// live signature once, into this process's own environment, fixes every consumer
// at once, since forked children inherit it and the watcher re-reads it on each
// reconnect.

// hyprRunDir is the per-user directory Hyprland drops each instance's sockets in
// ($XDG_RUNTIME_DIR/hypr/<signature>/), with the same /tmp fallback the older
// layout uses in hyprSocket2Path.
func hyprRunDir() string {
	if rt := os.Getenv("XDG_RUNTIME_DIR"); rt != "" {
		return filepath.Join(rt, "hypr")
	}
	return filepath.Join("/tmp", "hypr")
}

// hyprSocketAlive reports whether the instance with this signature is the running
// compositor: its request socket must accept a connection. A signature whose
// socket file lingers after the instance exited refuses the dial and reads dead.
func hyprSocketAlive(sig string) bool {
	if sig == "" {
		return false
	}
	c, err := net.DialTimeout("unix", filepath.Join(hyprRunDir(), sig, ".socket.sock"), 200*time.Millisecond)
	if err != nil {
		return false
	}
	_ = c.Close()
	return true
}

// liveHyprSignature discovers the running compositor's signature: the newest
// instance directory (by socket mtime, so the current login wins over stale
// leftovers) whose request socket answers. It returns "" when none answer -- no
// Hyprland, or a login-time race before the socket lands -- so the caller leaves
// the inherited value alone rather than guessing.
func liveHyprSignature() string {
	entries, err := os.ReadDir(hyprRunDir())
	if err != nil {
		return ""
	}
	best := ""
	var bestMod time.Time
	for _, e := range entries {
		if !e.IsDir() {
			continue
		}
		sig := e.Name()
		fi, err := os.Stat(filepath.Join(hyprRunDir(), sig, ".socket.sock"))
		if err != nil {
			continue
		}
		if !hyprSocketAlive(sig) {
			continue
		}
		if best == "" || fi.ModTime().After(bestMod) {
			best, bestMod = sig, fi.ModTime()
		}
	}
	return best
}

// ensureLiveHyprSignature rebinds HYPRLAND_INSTANCE_SIGNATURE to the running
// compositor when the inherited value is dead, leaving a live one untouched. It
// mutates this process's environment so every hyprctl fork and the event watcher
// pick up the correction with no per-call-site plumbing. Idempotent and cheap:
// the common (alive) case is a single local-socket dial that returns at once.
func ensureLiveHyprSignature() {
	if hyprSocketAlive(os.Getenv("HYPRLAND_INSTANCE_SIGNATURE")) {
		return
	}
	if live := liveHyprSignature(); live != "" {
		_ = os.Setenv("HYPRLAND_INSTANCE_SIGNATURE", live)
	}
}
