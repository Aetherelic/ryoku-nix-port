package main

import (
	"encoding/json"
	"testing"
)

const fullCaps = `{
  "activeProfile": "power-saver",
  "profiles": ["power-saver","balanced","performance"],
  "cpu": {
    "governor":        {"options":["performance","powersave"],"current":"powersave"},
    "epp":             {"options":["default","performance","balance_performance","balance_power","power"],"current":"power"},
    "maxFreqPct":      {"min":20,"max":100,"current":76},
    "platformProfile": {"options":["quiet","balanced","performance"],"current":"quiet"}
  },
  "battery": {"chargeLimit":{"min":50,"max":100,"current":80}},
  "aspm":    {"options":["default","performance","powersave","powersupersave"],"current":"default"}
}`

const noPlatformCaps = `{
  "activeProfile": "balanced",
  "profiles": ["power-saver","balanced","performance"],
  "cpu": {
    "governor":   {"options":["performance","powersave"],"current":"powersave"},
    "epp":        {"options":["default","power"],"current":"power"},
    "maxFreqPct": {"min":20,"max":100,"current":100}
  },
  "battery": {"chargeLimit":{"min":50,"max":100,"current":80}},
  "aspm":    {"options":["default","powersave"],"current":"default"}
}`

const noBatteryCaps = `{
  "activeProfile": "performance",
  "cpu": {
    "governor":   {"options":["performance","powersave"],"current":"performance"},
    "epp":        {"options":["performance","power"],"current":"performance"},
    "maxFreqPct": {"min":20,"max":100,"current":100}
  },
  "aspm": {"options":["default","powersave"],"current":"default"}
}`

const noAspmCaps = `{
  "activeProfile": "balanced",
  "cpu": {
    "governor":   {"options":["performance","powersave"],"current":"powersave"},
    "epp":        {"options":["default","power"],"current":"power"},
    "maxFreqPct": {"min":20,"max":100,"current":85}
  },
  "battery": {"chargeLimit":{"min":50,"max":100,"current":60}}
}`

func mustCaps(t *testing.T, s string) cpuCaps {
	t.Helper()
	var c cpuCaps
	if err := json.Unmarshal([]byte(s), &c); err != nil {
		t.Fatalf("unmarshal caps: %v", err)
	}
	return c
}

func byID(ts []Tunable) map[string]Tunable {
	m := make(map[string]Tunable, len(ts))
	for _, t := range ts {
		m[t.ID] = t
	}
	return m
}

func TestCpuTunablesShape(t *testing.T) {
	cases := []struct {
		name    string
		caps    string
		def     profileDef
		wantIDs []string
	}{
		{"full", fullCaps, profileDef{}, []string{"governor", "epp", "maxFreqPct", "platformProfile", "chargeLimit", "aspm"}},
		{"noPlatform", noPlatformCaps, profileDef{}, []string{"governor", "epp", "maxFreqPct", "chargeLimit", "aspm"}},
		{"noBattery", noBatteryCaps, profileDef{}, []string{"governor", "epp", "maxFreqPct", "aspm"}},
		{"noAspm", noAspmCaps, profileDef{}, []string{"governor", "epp", "maxFreqPct", "chargeLimit"}},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			got := cpuTunables(mustCaps(t, tc.caps), tc.def)
			if len(got) != len(tc.wantIDs) {
				t.Fatalf("got %d tunables, want %d: %+v", len(got), len(tc.wantIDs), got)
			}
			for i, id := range tc.wantIDs {
				if got[i].ID != id {
					t.Errorf("tunable %d: got id %q, want %q", i, got[i].ID, id)
				}
			}
		})
	}
}

func TestCpuTunablesKindsUnitsSlots(t *testing.T) {
	m := byID(cpuTunables(mustCaps(t, fullCaps), profileDef{}))

	want := map[string]struct {
		gpu, kind, unit string
	}{
		"governor":        {"cpu", "segment", ""},
		"epp":             {"cpu", "segment", ""},
		"maxFreqPct":      {"cpu", "slider", "%"},
		"platformProfile": {"cpu", "segment", ""},
		"chargeLimit":     {"battery", "slider", "%"},
		"aspm":            {"battery", "segment", ""},
	}
	for id, w := range want {
		tu, ok := m[id]
		if !ok {
			t.Fatalf("missing tunable %q", id)
		}
		if tu.GPU != w.gpu || tu.Kind != w.kind || tu.Unit != w.unit {
			t.Errorf("%s: gpu=%q kind=%q unit=%q, want gpu=%q kind=%q unit=%q",
				id, tu.GPU, tu.Kind, tu.Unit, w.gpu, w.kind, w.unit)
		}
		if tu.Risk != "safe" {
			t.Errorf("%s: risk=%q, want safe", id, tu.Risk)
		}
		if tu.Desc == "" || tu.Src == "" {
			t.Errorf("%s: desc=%q src=%q, both must be set", id, tu.Desc, tu.Src)
		}
	}

	if got := m["governor"].Options; len(got) != 2 || got[0] != "performance" || got[1] != "powersave" {
		t.Errorf("governor options = %v", got)
	}
	if got := m["aspm"].Options; len(got) != 4 || got[0] != "default" {
		t.Errorf("aspm options = %v", got)
	}
	if s := m["maxFreqPct"]; s.Min != 20 || s.Max != 100 {
		t.Errorf("maxFreqPct range = %v..%v, want 20..100", s.Min, s.Max)
	}
	if s := m["chargeLimit"]; s.Min != 50 || s.Max != 100 {
		t.Errorf("chargeLimit range = %v..%v, want 50..100", s.Min, s.Max)
	}
}

func TestStoredValueOverridesLive(t *testing.T) {
	pct := 60
	def := profileDef{Governor: "performance", MaxFreqPct: &pct}
	m := byID(cpuTunables(mustCaps(t, fullCaps), def))

	if got := m["governor"].Value; got != "performance" {
		t.Errorf("governor value = %q, want stored %q", got, "performance")
	}
	if got := m["maxFreqPct"].Current; got != 60 {
		t.Errorf("maxFreqPct current = %v, want stored 60", got)
	}
	// epp and platformProfile were not in the definition: they hold the live value.
	if got := m["epp"].Value; got != "power" {
		t.Errorf("epp value = %q, want live %q", got, "power")
	}
	if got := m["platformProfile"].Value; got != "quiet" {
		t.Errorf("platformProfile value = %q, want live %q", got, "quiet")
	}
}

func TestBatteryKnobsIgnoreProfileDef(t *testing.T) {
	// A profile definition must never change the global battery knobs.
	pct := 55
	def := profileDef{Governor: "performance", MaxFreqPct: &pct}
	m := byID(cpuTunables(mustCaps(t, fullCaps), def))
	if got := m["chargeLimit"].Current; got != 80 {
		t.Errorf("chargeLimit current = %v, want live 80", got)
	}
	if got := m["aspm"].Value; got != "default" {
		t.Errorf("aspm value = %q, want live %q", got, "default")
	}
}
