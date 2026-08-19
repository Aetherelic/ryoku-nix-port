package main

// Undo a config import: restore every file the import touched from its backup,
// or remove it when the backup is empty (the import created it). The manifest is
// the pure restore truth, so this reverts the marked blocks, the ingested hub
// Overrides, and the generated settings.lua in one pass.

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"sort"
)

func undoImport(ts string) (undoResult, error) {
	base := backupsDir()
	if ts == "" {
		latest, err := latestImport(base)
		if err != nil {
			return undoResult{}, err
		}
		ts = latest
	}
	dir := filepath.Join(base, ts)
	mb, err := os.ReadFile(filepath.Join(dir, "manifest.json"))
	if err != nil {
		return undoResult{}, fmt.Errorf("no import to undo for %q: %w", ts, err)
	}
	var man importManifest
	if err := json.Unmarshal(mb, &man); err != nil {
		return undoResult{}, fmt.Errorf("parse manifest: %w", err)
	}

	var restored []string
	for _, f := range man.Files {
		if f.Backup != "" {
			data, err := os.ReadFile(f.Backup)
			if err != nil {
				return undoResult{}, fmt.Errorf("read backup %s: %w", f.Backup, err)
			}
			if err := atomicWrite(f.Path, data, 0o644); err != nil {
				return undoResult{}, err
			}
		} else if err := os.Remove(f.Path); err != nil && !os.IsNotExist(err) {
			return undoResult{}, fmt.Errorf("remove %s: %w", f.Path, err)
		}
		restored = append(restored, f.Path)
	}
	return undoResult{Ts: man.Ts, Restored: relPaths(restored)}, nil
}

// latestImport returns the newest import timestamp that still has a manifest.
// The 20060102-150405 stamp sorts chronologically, so lexical max is newest.
func latestImport(base string) (string, error) {
	entries, err := os.ReadDir(base)
	if err != nil {
		return "", fmt.Errorf("no imports to undo")
	}
	var stamps []string
	for _, e := range entries {
		if !e.IsDir() {
			continue
		}
		if _, err := os.Stat(filepath.Join(base, e.Name(), "manifest.json")); err == nil {
			stamps = append(stamps, e.Name())
		}
	}
	if len(stamps) == 0 {
		return "", fmt.Errorf("no imports to undo")
	}
	sort.Strings(stamps)
	return stamps[len(stamps)-1], nil
}
