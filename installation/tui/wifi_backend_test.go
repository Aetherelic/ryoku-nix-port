package main

import (
	"os"
	"path/filepath"
	"testing"
)

func TestOtherWifiBackend(t *testing.T) {
	if got := otherWifiBackend("iwd"); got != "wpa_supplicant" {
		t.Errorf("otherWifiBackend(iwd) = %q, want wpa_supplicant", got)
	}
	if got := otherWifiBackend("wpa_supplicant"); got != "iwd" {
		t.Errorf("otherWifiBackend(wpa_supplicant) = %q, want iwd", got)
	}
	// An unknown/empty value is treated as "not wpa_supplicant", so the fallback
	// target is wpa_supplicant (the compatibility superset).
	if got := otherWifiBackend(""); got != "wpa_supplicant" {
		t.Errorf("otherWifiBackend(\"\") = %q, want wpa_supplicant", got)
	}
}

func TestActiveWifiBackend(t *testing.T) {
	dir := t.TempDir()
	p := filepath.Join(dir, "wifi-backend.conf")
	old := wifiBackendConf
	wifiBackendConf = p
	t.Cleanup(func() { wifiBackendConf = old })

	if got := activeWifiBackend(); got != "iwd" {
		t.Errorf("no drop-in must default to iwd, got %q", got)
	}
	if err := os.WriteFile(p, []byte("[device]\nwifi.backend=iwd\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	if got := activeWifiBackend(); got != "iwd" {
		t.Errorf("iwd pin, got %q, want iwd", got)
	}
	if err := os.WriteFile(p, []byte("[device]\n  wifi.backend = wpa_supplicant\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	if got := activeWifiBackend(); got != "wpa_supplicant" {
		t.Errorf("wpa_supplicant pin (spaced) must be detected, got %q", got)
	}
}
