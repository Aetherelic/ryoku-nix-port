package sys

import (
	"os"
	"path/filepath"
	"sort"
	"strings"
)

// UserEditFiles lists the layable files in the overlay: regular files under
// UserEditsDir, slash-relative and sorted, skipping symlinks, .md notes (the
// guide and anything a user keeps beside their edits), and the overlay's own
// nested path. The overlay lays these over ~/.config; doctor reads the same set
// to spot forks; reset walks it to clear everything. Absent overlay -> no files.
func UserEditFiles() ([]string, error) {
	root := UserEditsDir()
	if _, err := os.Stat(root); err != nil {
		return nil, nil
	}
	var rels []string
	err := filepath.WalkDir(root, func(p string, d os.DirEntry, err error) error {
		if err != nil {
			return err
		}
		if d.IsDir() || d.Type()&os.ModeSymlink != 0 || strings.HasSuffix(d.Name(), ".md") {
			return nil
		}
		rel, err := filepath.Rel(root, p)
		if err != nil {
			return err
		}
		rel = filepath.ToSlash(rel)
		if strings.HasPrefix(rel, "ryoku/user_edits/") {
			return nil // never mirror the overlay tree into itself
		}
		rels = append(rels, rel)
		return nil
	})
	sort.Strings(rels)
	return rels, err
}

// LiveOwnedConfig are the tool's own user-include files: each is edited at its
// normal ~/.config path and loaded there directly (hyprland.lua's
// optional("user") and optional("monitors_user"); kitty.conf includes
// user.conf). Ryoku seeds user.lua once and never touches it; the other two are
// never shipped. They must NEVER live in the overlay: overlayUserEdits would
// re-lay a frozen copy over the live file on every update and silently wipe hand
// edits made afterward. The overlay is for forking a whole Ryoku file, not these.
var LiveOwnedConfig = []string{
	"hypr/user.lua",
	"hypr/monitors_user.lua",
	"kitty/user.conf",
}

// IsLiveOwnedConfig reports whether rel (a slash path relative to ~/.config) is
// one of the live-owned user files the overlay must never lay.
func IsLiveOwnedConfig(rel string) bool {
	for _, r := range LiveOwnedConfig {
		if r == rel {
			return true
		}
	}
	return false
}
