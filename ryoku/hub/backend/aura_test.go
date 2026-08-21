package main

import "testing"

func TestAuraDeviceJoinsOpenRGBControllers(t *testing.T) {
	motherboard := orgbDevice{Name: "G533ZM", Type: "Motherboard", Serial: "mb"}
	aura := auraDeviceView(auraState{
		Name:       "ROG Zephyrus G14 keyboard",
		Mode:       auraStatic,
		Modes:      []uint32{auraStatic, auraBreathe, auraRainbowWave},
		Brightness: 3,
	})

	got := combineLightingDevices([]orgbDevice{motherboard}, []orgbDevice{aura})
	if len(got) != 2 {
		t.Fatalf("controllers = %d, want motherboard and keyboard", len(got))
	}
	if got[0].Name != "G533ZM" || got[1].Type != "Keyboard" || got[1].Provider != auraProvider {
		t.Fatalf("controllers = %+v", got)
	}
}

func TestAuraKeyboardIdentityIgnoresDBusChildPath(t *testing.T) {
	first := auraDeviceView(auraState{
		Path:       "/xyz/ljones/aura/19b6_2_3",
		Name:       "ROG Zephyrus G14 keyboard",
		DeviceType: 0,
		Modes:      []uint32{auraStatic},
	})
	moved := auraDeviceView(auraState{
		Path:       "/xyz/ljones/aura/19b6_4_7",
		Name:       first.Name,
		DeviceType: 0,
		Modes:      []uint32{auraStatic},
	})
	if deviceKey(first) != deviceKey(moved) {
		t.Fatalf("identity moved from %q to %q", deviceKey(first), deviceKey(moved))
	}
}

func TestAuraReplacesOpenRGBAsusLaptopAlias(t *testing.T) {
	alias := orgbDevice{
		Name:        "G533ZM",
		Type:        "Laptop",
		Vendor:      "Asus",
		Description: "ASUSTek Computer Inc. N-KEY Device",
	}
	aura := auraDeviceView(auraState{
		Name:  "ROG Zephyrus G14 keyboard",
		Mode:  auraStatic,
		Modes: []uint32{auraStatic},
	})

	got := combineLightingDevices([]orgbDevice{alias}, []orgbDevice{aura})
	if len(got) != 1 || got[0].Provider != auraProvider {
		t.Fatalf("controllers = %+v, want only the native Aura provider", got)
	}
}

func TestAuraCarriesOpenRGBAliasSettingsForward(t *testing.T) {
	t.Setenv("XDG_CONFIG_HOME", t.TempDir())
	alias := orgbDevice{
		Name:        "G533ZM",
		Type:        "Laptop",
		Vendor:      "Asus",
		Description: "ASUSTek Computer Inc. N-KEY Device",
	}
	aura := auraDeviceView(auraState{
		Name:  "ROG Zephyrus G14 keyboard",
		Mode:  auraStatic,
		Modes: []uint32{auraStatic, auraBreathe},
	})
	oldKey := deviceKey(alias)
	if err := saveLighting(lightingState{Enabled: true, Devices: map[string]*lightingSettings{
		oldKey: {
			Name:       alias.Name,
			Managed:    true,
			Mode:       "Breathing",
			Source:     "accent",
			Brightness: 90,
			Speed:      60,
			Restore:    "Static",
		},
	}}); err != nil {
		t.Fatal(err)
	}

	live := combineLightingDevices([]orgbDevice{alias}, []orgbDevice{aura})
	got := rememberFirstSight(live)
	settings := got.Devices[deviceKey(aura)]
	if settings == nil || !settings.Managed || settings.Source != "accent" || settings.Brightness != 90 {
		t.Fatalf("Aura settings = %+v", settings)
	}
	if settings.Name != aura.Name {
		t.Fatalf("Aura name = %q, want %q", settings.Name, aura.Name)
	}
	if settings.Mode != "Breathe" {
		t.Fatalf("Aura mode = %q, want Breathe", settings.Mode)
	}
	if got.Devices[oldKey] != nil {
		t.Fatalf("obsolete OpenRGB alias %q was kept", oldKey)
	}
}

func TestPaletteApplyMigratesOpenRGBAliasBeforeWriting(t *testing.T) {
	t.Setenv("XDG_CONFIG_HOME", t.TempDir())
	alias := orgbDevice{
		Name:        "G533ZM",
		Type:        "Laptop",
		Vendor:      "Asus",
		Description: "ASUSTek Computer Inc. N-KEY Device",
	}
	aura := auraDeviceView(auraState{
		Path:       "/xyz/ljones/aura/19b6_2_3",
		Name:       "ROG Zephyrus G14 keyboard",
		Mode:       auraStatic,
		Modes:      []uint32{auraStatic},
		Brightness: 3,
	})
	oldKey := deviceKey(alias)
	if err := saveLighting(lightingState{Enabled: true, Devices: map[string]*lightingSettings{
		oldKey: {
			Name:       alias.Name,
			Managed:    true,
			Mode:       "Direct",
			Effect:     "solid",
			Source:     "accent",
			Brightness: 90,
			Speed:      -1,
			Restore:    "Direct",
		},
	}}); err != nil {
		t.Fatal(err)
	}

	oldWrite := auraWrite
	defer func() { auraWrite = oldWrite }()
	var gotPath string
	auraWrite = func(path string, _ auraEffect, _ int) error {
		gotPath = path
		return nil
	}

	got := applyLiveSettings(nil, combineLightingDevices([]orgbDevice{alias}, []orgbDevice{aura}), "#112233")
	if gotPath != aura.ProviderPath {
		t.Fatalf("write path = %q, want %q", gotPath, aura.ProviderPath)
	}
	settings := got.Devices[deviceKey(aura)]
	if settings == nil {
		t.Fatalf("native Aura settings missing: %+v", got.Devices)
	}
	if settings.Effect != "" || settings.Mode != "Static" || settings.Restore != "Static" {
		t.Fatalf("native Aura effect migration = %+v", settings)
	}
	if got.Devices[oldKey] != nil {
		t.Fatalf("obsolete OpenRGB alias %q was kept", oldKey)
	}
}

func TestAuraPaintedEffectsChooseFirmwareModes(t *testing.T) {
	device := auraDeviceView(auraState{
		Modes: []uint32{
			auraStatic, auraBreathe, auraRainbowCycle, auraRainbowWave,
			auraPulse, auraComet, auraLaser,
		},
	})
	for effect, want := range map[string]string{
		"solid":    "Static",
		"breathe":  "Breathe",
		"pulse":    "Pulse",
		"spectrum": "RainbowCycle",
		"wave":     "RainbowWave",
		"comet":    "Comet",
		"scanner":  "Laser",
		"unknown":  "Static",
	} {
		if got := auraModeForEffect(effect, device); got != want {
			t.Errorf("%s mapped to %s, want %s", effect, got, want)
		}
	}
}

func TestOpenRGBFirmwareModesMapToAura(t *testing.T) {
	device := auraDeviceView(auraState{
		Modes: []uint32{
			auraStatic, auraBreathe, auraRainbowCycle, auraRainbowWave,
			auraStars, auraRain, auraHighlight, auraLaser, auraRipple,
			auraPulse, auraComet, auraFlash,
		},
	})
	for legacy, want := range map[string]string{
		"Direct":            "Static",
		"Static":            "Static",
		"Breathing":         "Breathe",
		"Flashing":          "Pulse",
		"Spectrum Cycle":    "RainbowCycle",
		"Rainbow Wave":      "RainbowWave",
		"Starry Night":      "Stars",
		"Rain":              "Rain",
		"Reactive - Fade":   "Highlight",
		"Reactive - Laser":  "Laser",
		"Reactive - Ripple": "Ripple",
		"Comet":             "Comet",
		"Flash N Dash":      "Flash",
		"Keystone":          "Static",
		"Off":               "Static",
	} {
		if got := auraModeForLegacyMode(legacy, device); got != want {
			t.Errorf("%s mapped to %s, want %s", legacy, got, want)
		}
	}
}

func TestAuraAccentModeUsesWallpaperColour(t *testing.T) {
	d := auraDeviceView(auraState{
		Name:       "ROG Zephyrus G14 keyboard",
		Mode:       auraStatic,
		Modes:      []uint32{auraStatic},
		Brightness: 3,
	})
	key := deviceKey(d)
	settings := &lightingSettings{
		Managed:    true,
		Mode:       "Static",
		Source:     "accent",
		Brightness: 67,
		Speed:      -1,
	}

	oldWrite := auraWrite
	defer func() { auraWrite = oldWrite }()
	var got auraEffect
	var gotPath string
	gotBrightness := -1
	auraWrite = func(path string, effect auraEffect, brightness int) error {
		gotPath = path
		got = effect
		gotBrightness = brightness
		return nil
	}

	if err := applyOne(nil, []orgbDevice{d}, key, settings, "#F25623"); err != nil {
		t.Fatal(err)
	}
	if gotPath != d.ProviderPath {
		t.Fatalf("path = %q, want %q", gotPath, d.ProviderPath)
	}
	if got.Mode != auraStatic || got.Colour1 != (auraColour{R: 0xF2, G: 0x56, B: 0x23}) {
		t.Fatalf("effect = %+v", got)
	}
	if gotBrightness != 67 {
		t.Fatalf("brightness = %d, want 67", gotBrightness)
	}
}

func TestAuraModeUsesItsStoredTunables(t *testing.T) {
	state := auraState{
		Mode: auraStatic,
		ModeData: map[uint32]auraEffect{
			auraRainbowWave: {
				Mode:      auraRainbowWave,
				Colour1:   auraColour{R: 0x44, G: 0x55, B: 0x66},
				Speed:     "High",
				Direction: "Left",
			},
		},
	}

	got := auraModeView(auraRainbowWave, state)
	if got.Speed != 100 || auraDirectionName(got.Direction) != "Left" {
		t.Fatalf("RainbowWave tunables = speed %d, direction %s", got.Speed, auraDirectionName(got.Direction))
	}
	if len(got.Colors) != 1 || got.Colors[0] != 0x665544 {
		t.Fatalf("RainbowWave colours = %#v", got.Colors)
	}
}
