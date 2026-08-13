package main

import (
	"net"
	"os"
	"path/filepath"
	"testing"
)

// liveInstance mimics a running compositor: an instance directory whose request
// socket is backed by a real listener that accepts connections.
func liveInstance(t *testing.T, rt, sig string) {
	t.Helper()
	dir := filepath.Join(rt, "hypr", sig)
	if err := os.MkdirAll(dir, 0o755); err != nil {
		t.Fatal(err)
	}
	ln, err := net.Listen("unix", filepath.Join(dir, ".socket.sock"))
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { ln.Close() })
}

// deadInstance mimics a compositor that exited: the socket path lingers but
// refuses connections.
func deadInstance(t *testing.T, rt, sig string) {
	t.Helper()
	dir := filepath.Join(rt, "hypr", sig)
	if err := os.MkdirAll(dir, 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(dir, ".socket.sock"), nil, 0o644); err != nil {
		t.Fatal(err)
	}
}

func TestHyprSocketAlive(t *testing.T) {
	rt := t.TempDir()
	t.Setenv("XDG_RUNTIME_DIR", rt)
	liveInstance(t, rt, "live")
	deadInstance(t, rt, "dead")
	if !hyprSocketAlive("live") {
		t.Error("a listening instance must read alive")
	}
	if hyprSocketAlive("dead") {
		t.Error("a lingering socket with no listener must read dead")
	}
	if hyprSocketAlive("absent") {
		t.Error("an instance with no directory must read dead")
	}
	if hyprSocketAlive("") {
		t.Error("an empty signature must read dead")
	}
}

func TestLiveHyprSignaturePicksTheRunningOne(t *testing.T) {
	rt := t.TempDir()
	t.Setenv("XDG_RUNTIME_DIR", rt)
	deadInstance(t, rt, "old-leftover")
	liveInstance(t, rt, "current")
	if got := liveHyprSignature(); got != "current" {
		t.Fatalf("liveHyprSignature() = %q, want %q", got, "current")
	}
}

func TestLiveHyprSignatureNoneAlive(t *testing.T) {
	rt := t.TempDir()
	t.Setenv("XDG_RUNTIME_DIR", rt)
	deadInstance(t, rt, "dead")
	if got := liveHyprSignature(); got != "" {
		t.Fatalf("liveHyprSignature() = %q, want empty when nothing answers", got)
	}
}

// The stale-restart case this whole file exists for: the daemon is launched
// under a signature whose compositor is gone, so it must rebind to the live one.
func TestEnsureLiveHyprSignatureRebindsStale(t *testing.T) {
	rt := t.TempDir()
	t.Setenv("XDG_RUNTIME_DIR", rt)
	liveInstance(t, rt, "live")
	t.Setenv("HYPRLAND_INSTANCE_SIGNATURE", "stale") // no directory: dead
	ensureLiveHyprSignature()
	if got := os.Getenv("HYPRLAND_INSTANCE_SIGNATURE"); got != "live" {
		t.Fatalf("a stale signature was not rebound: got %q, want %q", got, "live")
	}
}

// A healthy inherited signature is the common case and must be left untouched,
// even when another live instance exists, so the resolver never steals a working
// session onto a different compositor.
func TestEnsureLiveHyprSignatureKeepsLive(t *testing.T) {
	rt := t.TempDir()
	t.Setenv("XDG_RUNTIME_DIR", rt)
	liveInstance(t, rt, "mine")
	liveInstance(t, rt, "other")
	t.Setenv("HYPRLAND_INSTANCE_SIGNATURE", "mine")
	ensureLiveHyprSignature()
	if got := os.Getenv("HYPRLAND_INSTANCE_SIGNATURE"); got != "mine" {
		t.Fatalf("a live signature must be left alone: got %q, want %q", got, "mine")
	}
}
