package main

import (
	"crypto/sha256"
	"encoding/hex"
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

func xdgCacheHome() string {
	if b := os.Getenv("XDG_CACHE_HOME"); b != "" {
		return b
	}
	return filepath.Join(os.Getenv("HOME"), ".cache")
}

// extrasCacheDir is where fetched registries and assets are cached so the
// catalogue still renders offline. The default source keeps the legacy
// ${XDG_CACHE_HOME:-~/.cache}/ryoku/extras location for upgrade and offline
// continuity; an explicit RYOKU_EXTRAS_BASE override caches under a stable
// per-source subdirectory so a fork or local tree never serves its bytes as the
// default source's archive.
func extrasCacheDir() string {
	root := filepath.Join(xdgCacheHome(), "ryoku", "extras")
	if os.Getenv("RYOKU_EXTRAS_BASE") == "" {
		return root
	}
	sum := sha256.Sum256([]byte(extrasBase()))
	return filepath.Join(root, "sources", hex.EncodeToString(sum[:8]))
}
