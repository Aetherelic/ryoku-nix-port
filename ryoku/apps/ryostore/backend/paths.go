package main

import (
	"os"
	"path/filepath"
	"strings"
)

// The extras catalogue lives in the ryoku-extras repo, fetched from raw GitHub.
// RYOKU_EXTRAS_BASE overrides the base for a fork or a local tree under test.
const defaultExtrasBase = "https://raw.githubusercontent.com/neur0map/ryoku-extras/main"

func extrasBase() string {
	if b := os.Getenv("RYOKU_EXTRAS_BASE"); b != "" {
		return strings.TrimRight(b, "/")
	}
	return defaultExtrasBase
}

// extrasCacheDir is where fetched registries and assets are cached so the
// catalogue still renders offline: ${XDG_CACHE_HOME:-~/.cache}/ryoku/extras.
func extrasCacheDir() string {
	base := os.Getenv("XDG_CACHE_HOME")
	if base == "" {
		base = filepath.Join(os.Getenv("HOME"), ".cache")
	}
	return filepath.Join(base, "ryoku", "extras")
}
