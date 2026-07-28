package doctor

import (
	"encoding/json"
	"os"
	"path/filepath"
	"ryoku-cli/internal/sys"
)

// The screenshot capture UI moved from an in-band frame menu (the capture menu)
// to a floating card surface, so shell.json no longer defines
// menus.screenshot_menu. A machine upgrading from a release that persisted it
// still carries that object under the menus namespace, where nothing reads it any
// more. This strips the one leaf and leaves every other menu (and every other
// key) untouched. Surgical and idempotent: a store already free of it is left
// alone.
func reconcileCaptureMenu(checkOnly bool) recResult {
	path := filepath.Join(sys.ConfigHome(), "ryoku", "shell.json")
	raw, err := os.ReadFile(path)
	if err != nil {
		return okRes("no shell.json yet (seeded on first shell run)")
	}
	migrated, changed, err := stripCaptureMenu(raw)
	if err != nil {
		return warnRes("shell.json does not parse (%v); the shell falls back to defaults", err).
			withFix("delete %s to re-seed it", path)
	}
	if !changed {
		return okRes("shell.json carries no retired capture menu")
	}
	if checkOnly {
		return wouldRes("shell.json still carries the retired menus.screenshot_menu").
			withFix("ryoku doctor strips it in place")
	}
	tmp := path + ".ryoku-tmp"
	if err := os.WriteFile(tmp, migrated, 0o644); err != nil {
		return failRes("could not write %s: %v", tmp, err)
	}
	if err := os.Rename(tmp, path); err != nil {
		os.Remove(tmp)
		return failRes("could not replace %s: %v", path, err)
	}
	return fixedRes("stripped the retired menus.screenshot_menu from shell.json")
}

// stripCaptureMenu removes menus.screenshot_menu from a shell store, keeping
// every other key (and every sibling menu) as its own raw bytes. An absent menus
// namespace or an absent screenshot_menu leaf is a no-op, so a store already free
// of it comes back unchanged.
func stripCaptureMenu(raw []byte) ([]byte, bool, error) {
	var top map[string]json.RawMessage
	if err := json.Unmarshal(raw, &top); err != nil {
		return nil, false, err
	}
	menusRaw, ok := top["menus"]
	if !ok {
		return nil, false, nil
	}
	var menus map[string]json.RawMessage
	if err := json.Unmarshal(menusRaw, &menus); err != nil {
		return nil, false, err
	}
	if _, ok := menus["screenshot_menu"]; !ok {
		return nil, false, nil
	}
	delete(menus, "screenshot_menu")
	repacked, err := json.Marshal(menus)
	if err != nil {
		return nil, false, err
	}
	top["menus"] = repacked
	out, err := json.MarshalIndent(top, "", "  ")
	if err != nil {
		return nil, false, err
	}
	return append(out, '\n'), true, nil
}
