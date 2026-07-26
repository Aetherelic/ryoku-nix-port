package main

import (
	"encoding/json"
	"os"
	"testing"
	"time"

	"github.com/godbus/dbus/v5"
)

// apSecurity derives the reference SecurityType from the NetworkManager AP flag
// triple. WPA3 (SAE) and Enterprise (802.1X) win over the plain RSN/WPA/WEP/open
// ladder, and each flag family is checked against the right bit.
func TestApSecurity(t *testing.T) {
	const (
		privacy = 0x1
		psk     = 0x100
		km8021x = 0x200
		sae     = 0x400
	)
	cases := []struct {
		name             string
		flags, wpa, rsn  uint32
		want             string
	}{
		{"open", 0, 0, 0, "None"},
		{"wep", privacy, 0, 0, "Wep"},
		{"wpa only", privacy, psk, 0, "Wpa"},
		{"wpa2 rsn", privacy, 0, psk, "Wpa2"},
		{"wpa2 measured", 0x1, 392, 392, "Wpa2"}, // the live "M" network
		{"wpa3 sae in rsn", privacy, 0, sae, "Wpa3"},
		{"wpa3 sae in wpa", privacy, sae, 0, "Wpa3"},
		{"enterprise rsn", privacy, 0, km8021x, "Enterprise"},
		{"enterprise beats wpa2", privacy, 0, km8021x | psk, "Enterprise"},
	}
	for _, c := range cases {
		if got := apSecurity(c.flags, c.wpa, c.rsn); got != c.want {
			t.Errorf("%s: apSecurity(%#x,%#x,%#x) = %q, want %q", c.name, c.flags, c.wpa, c.rsn, got, c.want)
		}
	}
}

// connectivityFromState maps the NMDeviceState to the three-state reveal label:
// only 100 is Connected, the 40..90 activation range is Connecting, everything
// else Disconnected.
func TestConnectivityFromState(t *testing.T) {
	cases := []struct {
		state uint32
		want  string
	}{
		{100, "Connected"},
		{40, "Connecting"}, {60, "Connecting"}, {90, "Connecting"},
		{30, "Disconnected"}, {20, "Disconnected"}, {0, "Disconnected"},
		{120, "Disconnected"}, // failed
	}
	for _, c := range cases {
		if got := connectivityFromState(c.state); got != c.want {
			t.Errorf("connectivityFromState(%d) = %q, want %q", c.state, got, c.want)
		}
	}
}

// wifiConnectSettings omits the security block for an open network and adds a
// WPA-PSK block with the passphrase when one is supplied.
func TestWifiConnectSettings(t *testing.T) {
	open := wifiConnectSettings("cafe", "")
	if _, ok := open["802-11-wireless-security"]; ok {
		t.Error("open network got a security block")
	}
	if ssid, _ := open["802-11-wireless"]["ssid"].Value().([]byte); string(ssid) != "cafe" {
		t.Errorf("ssid = %q, want cafe", ssid)
	}
	if typ, _ := open["connection"]["type"].Value().(string); typ != "802-11-wireless" {
		t.Errorf("type = %q, want 802-11-wireless", typ)
	}

	secured := wifiConnectSettings("home", "hunter2")
	sec := secured["802-11-wireless-security"]
	if sec == nil {
		t.Fatal("secured network missing security block")
	}
	if km, _ := sec["key-mgmt"].Value().(string); km != "wpa-psk" {
		t.Errorf("key-mgmt = %q, want wpa-psk", km)
	}
	if psk, _ := sec["psk"].Value().(string); psk != "hunter2" {
		t.Errorf("psk = %q, want hunter2", psk)
	}
}

// ssidSaved matches only stored wifi profiles with an equal SSID, ignoring
// non-wifi profiles that happen to share the string.
func TestSsidSaved(t *testing.T) {
	saved := []savedConn{
		{typ: "802-11-wireless", ssid: "home"},
		{typ: "wireguard", id: "vpn", ssid: ""},
		{typ: "802-3-ethernet", ssid: "cafe"}, // wrong type, same string
	}
	if !ssidSaved("home", saved) {
		t.Error("home should be saved")
	}
	if ssidSaved("cafe", saved) {
		t.Error("cafe is ethernet, not a saved wifi profile")
	}
	if ssidSaved("unknown", saved) {
		t.Error("unknown should not be saved")
	}
}

// apFrame carries every field the reveal binds to.
func TestApFrame(t *testing.T) {
	f := apFrame(&apInfo{Ssid: "M", Strength: 50, Security: "Wpa2", Bssid: "D6:31:27:89:88:78", Frequency: 5280, Saved: true, Active: true})
	for _, k := range []string{"ssid", "strength", "security", "bssid", "frequency", "saved", "active"} {
		if _, ok := f[k]; !ok {
			t.Errorf("apFrame missing key %q", k)
		}
	}
	if f["ssid"] != "M" || f["strength"] != 50 || f["active"] != true {
		t.Errorf("apFrame values wrong: %+v", f)
	}
}

// TestLiveNetworkFrame exercises the real snapshot path against the running
// NetworkManager and prints the frame, as evidence the topic renders live data.
// Gated so the default `go test` stays deterministic and bus-free.
func TestLiveNetworkFrame(t *testing.T) {
	if os.Getenv("RYOKU_LIVE_DBUS") == "" {
		t.Skip("set RYOKU_LIVE_DBUS=1 to run the live NetworkManager integration")
	}
	conn, err := dbus.ConnectSystemBus()
	if err != nil {
		t.Skipf("no system bus: %v", err)
	}
	defer conn.Close()
	n := &networkState{conn: conn, topic: newStateTopic()}
	ch := n.topic.subscribe()
	n.publish()
	select {
	case frame := <-ch:
		t.Logf("network frame: %s", frame)
		var m map[string]any
		if err := json.Unmarshal(frame, &m); err != nil {
			t.Fatalf("frame is not valid JSON: %v", err)
		}
		for _, k := range []string{"wifi", "wired", "accessPoints", "wireguard"} {
			if _, ok := m[k]; !ok {
				t.Errorf("frame missing key %q", k)
			}
		}
	case <-time.After(3 * time.Second):
		t.Fatal("no network frame published")
	}
}
