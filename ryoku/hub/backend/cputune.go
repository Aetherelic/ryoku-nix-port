package main

// cputune.go: `ryoku-hub cpu ...`, the Machine page's CPU power-profile and
// battery surface. Unlike gputune.go it probes no hardware itself: ryoku-power
// is the single source of truth for the knob set, so this only shells out to
// `ryoku-power capabilities --json` / `profile get` and reshapes the result
// into the []Tunable the page already renders. cpuTunables is the pure reshape
// and is unit-tested without executing ryoku-power.

import (
	"encoding/json"
	"fmt"
	"os/exec"
)

const ryokuPowerBin = "ryoku-power"

// cpuCaps mirrors `ryoku-power capabilities --json`. Every knob is a pointer so
// an absent capability key drops its Tunable rather than rendering an empty row.
type cpuCaps struct {
	ActiveProfile string      `json:"activeProfile"`
	Profiles      []string    `json:"profiles"`
	CPU           cpuKnobCaps `json:"cpu"`
	Battery       *struct {
		ChargeLimit *sliderCap `json:"chargeLimit"`
	} `json:"battery"`
	ASPM *segmentCap `json:"aspm"`
}

type cpuKnobCaps struct {
	Governor        *segmentCap `json:"governor"`
	EPP             *segmentCap `json:"epp"`
	MaxFreqPct      *sliderCap  `json:"maxFreqPct"`
	PlatformProfile *segmentCap `json:"platformProfile"`
}

type segmentCap struct {
	Options []string `json:"options"`
	Current string   `json:"current"`
}

type sliderCap struct {
	Min     float64 `json:"min"`
	Max     float64 `json:"max"`
	Current float64 `json:"current"`
}

// profileDef is one profile's stored definition from `ryoku-power profile get`.
// A missing key means "unset": the reshape falls back to the live capability
// value, never a forced default.
type profileDef struct {
	Governor        string `json:"governor"`
	EPP             string `json:"epp"`
	MaxFreqPct      *int   `json:"maxFreqPct"`
	PlatformProfile string `json:"platformProfile"`
}

func runCpu(args []string) error {
	if len(args) == 0 {
		return fmt.Errorf("cpu needs caps|active|set")
	}
	switch args[0] {
	case "caps":
		profile := ""
		if len(args) > 1 {
			profile = args[1]
		}
		return cpuCapsReport(profile)
	case "active":
		return cpuActiveReport()
	case "set":
		if len(args) < 4 {
			return fmt.Errorf("cpu set needs <scope> <id> <value>")
		}
		return cpuSet(args[1], args[2], args[3])
	default:
		return fmt.Errorf("cpu needs caps|active|set")
	}
}

func cpuCapsReport(profile string) error {
	caps, err := readCapabilities()
	if err != nil {
		return err
	}
	if profile == "" {
		profile = caps.ActiveProfile
	}
	return printJSON(cpuTunables(caps, readProfileDef(profile)))
}

// cpuActiveReport gives the page the live profile name and the list to edit;
// caps stays a bare []Tunable, which has no room for these.
func cpuActiveReport() error {
	caps, err := readCapabilities()
	if err != nil {
		return err
	}
	return printJSON(struct {
		ActiveProfile string   `json:"activeProfile"`
		Profiles      []string `json:"profiles"`
	}{caps.ActiveProfile, caps.Profiles})
}

func readCapabilities() (cpuCaps, error) {
	var caps cpuCaps
	out, err := exec.Command(ryokuPowerBin, "capabilities", "--json").Output()
	if err != nil {
		return caps, fmt.Errorf("ryoku-power capabilities: %w", err)
	}
	if err := json.Unmarshal(out, &caps); err != nil {
		return caps, fmt.Errorf("parse capabilities: %w", err)
	}
	return caps, nil
}

// readProfileDef returns the stored definition, or an empty def when the profile
// has none yet: an undefined profile is not an error, its knobs show live values.
func readProfileDef(profile string) profileDef {
	var def profileDef
	if profile == "" {
		return def
	}
	out, err := exec.Command(ryokuPowerBin, "profile", "get", profile).Output()
	if err != nil {
		return def
	}
	_ = json.Unmarshal(out, &def)
	return def
}

// cpuTunables is the pure reshape: capabilities plus one profile's definition
// into the knob list the page renders. Stored definition wins over the live
// current; an absent capability key omits its knob entirely.
func cpuTunables(caps cpuCaps, def profileDef) []Tunable {
	const cpuDesc = "Persists · re-applies on profile switch"
	const batDesc = "Persists · re-applies at login"
	var out []Tunable

	if c := caps.CPU.Governor; c != nil {
		out = append(out, Tunable{
			GPU: "cpu", ID: "governor", Label: "Governor",
			Kind: "segment", Options: c.Options,
			Value: firstNonEmpty(def.Governor, c.Current),
			Risk:  "safe", Src: "scaling_governor", Desc: cpuDesc,
		})
	}
	if c := caps.CPU.EPP; c != nil {
		out = append(out, Tunable{
			GPU: "cpu", ID: "epp", Label: "Energy preference",
			Kind: "segment", Options: c.Options,
			Value: firstNonEmpty(def.EPP, c.Current),
			Risk:  "safe", Src: "energy_performance_preference", Desc: cpuDesc,
		})
	}
	if c := caps.CPU.MaxFreqPct; c != nil {
		cur := c.Current
		if def.MaxFreqPct != nil {
			cur = float64(*def.MaxFreqPct)
		}
		out = append(out, Tunable{
			GPU: "cpu", ID: "maxFreqPct", Label: "Max frequency",
			Kind: "slider", Unit: "%",
			Min: c.Min, Max: c.Max, Current: cur,
			Risk: "safe", Src: "scaling_max_freq", Desc: cpuDesc,
		})
	}
	if c := caps.CPU.PlatformProfile; c != nil {
		out = append(out, Tunable{
			GPU: "cpu", ID: "platformProfile", Label: "Thermal profile",
			Kind: "segment", Options: c.Options,
			Value: firstNonEmpty(def.PlatformProfile, c.Current),
			Risk:  "safe", Src: "platform_profile", Desc: cpuDesc,
		})
	}
	if caps.Battery != nil && caps.Battery.ChargeLimit != nil {
		cl := caps.Battery.ChargeLimit
		out = append(out, Tunable{
			GPU: "battery", ID: "chargeLimit", Label: "Charge limit",
			Kind: "slider", Unit: "%",
			Min: cl.Min, Max: cl.Max, Current: cl.Current,
			Risk: "safe", Src: "charge_control_end_threshold", Desc: batDesc,
		})
	}
	if caps.ASPM != nil {
		out = append(out, Tunable{
			GPU: "battery", ID: "aspm", Label: "PCIe ASPM",
			Kind: "segment", Options: caps.ASPM.Options,
			Value: caps.ASPM.Current,
			Risk:  "safe", Src: "pcie_aspm/parameters/policy", Desc: batDesc,
		})
	}
	return out
}

func cpuSet(scope, id, value string) error {
	if scope == "battery" {
		switch id {
		case "chargeLimit":
			return ttyRun(ryokuPowerBin, "charge-limit", "set", value)
		case "aspm":
			return ttyRun(ryokuPowerBin, "aspm", "set", value)
		default:
			return fmt.Errorf("unknown battery knob: %s", id)
		}
	}
	return ttyRun(ryokuPowerBin, "profile", "set", scope, id, value)
}
