package main

import (
	"fmt"
	"os/exec"
	"time"
)

var storeSections = map[string]struct{}{
	"discover": {}, "library": {}, "rices": {}, "lockscreens": {},
	"barstyles": {}, "fastfetch": {}, "plugins": {}, "bundles": {}, "decors": {}, "launcher-images": {},
}

func storeSection(section string) bool {
	_, ok := storeSections[section]
	return ok
}

func settingsSection(category string) (string, bool) {
	section, ok := map[string]string{
		"rices":       "appearance",
		"lockscreens": "lockscreen",
		"plugins":     "addons",
		"bundles":     "addons",
		"barstyles":   "bar-studio",
		"fastfetch":   "fastfetch",
	}[category]
	return section, ok
}

func runOpen(args []string) error {
	if len(args) != 1 || !storeSection(args[0]) {
		return fmt.Errorf("open needs a valid section")
	}
	return openConfig("ryostore", "/tmp/ryostore.lock", args[0])
}

func runSettings(args []string) error {
	if len(args) < 1 || len(args) > 2 {
		return fmt.Errorf("settings needs <category> [id]")
	}
	section, ok := settingsSection(args[0])
	if !ok {
		return fmt.Errorf("unknown settings category %q", args[0])
	}
	return openConfig("hub", "/tmp/ryoku-hub.lock", section)
}

func openConfig(config, lock, section string) error {
	start := exec.Command("flock", "-n", "-o", lock, "qs", "-c", config)
	if err := start.Start(); err != nil {
		return fmt.Errorf("start %s: %w", config, err)
	}
	_ = start.Process.Release()

	var last error
	for attempt := 0; attempt < 30; attempt++ {
		call := exec.Command("qs", "-c", config, "ipc", "call", "nav", "open", section)
		if err := call.Run(); err == nil {
			return nil
		} else {
			last = err
		}
		time.Sleep(100 * time.Millisecond)
	}
	return fmt.Errorf("open %s section %q: %w", config, section, last)
}
