package main

import (
	"os"
	"path/filepath"
	"testing"
)

func TestAsusAuraUsesPayloadDetector(t *testing.T) {
	payload := t.TempDir()
	detector := filepath.Join(payload, "system/hardware/input/ryoku-hw-asus-aura")
	if err := os.MkdirAll(filepath.Dir(detector), 0o755); err != nil {
		t.Fatal(err)
	}
	e := &engine{payload: payload}

	if err := os.WriteFile(detector, []byte("#!/bin/sh\nexit 0\n"), 0o755); err != nil {
		t.Fatal(err)
	}
	if !e.asusAura() {
		t.Fatal("a successful hardware detector must select asusctl")
	}

	if err := os.WriteFile(detector, []byte("#!/bin/sh\nexit 1\n"), 0o755); err != nil {
		t.Fatal(err)
	}
	if e.asusAura() {
		t.Fatal("a rejected machine must not select asusctl")
	}
}
