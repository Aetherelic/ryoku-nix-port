package doctor

import (
	"encoding/json"
	"os"
	"path/filepath"
	"ryoku-cli/internal/sys"
)

// The Depth tab is a quick-settings module. New installs get it from the catalog
// default, but a machine that persisted the pre-depth rail
// [home, notifications, weather, capture] would never see it. This appends
// "depth" to exactly that rail; a customized rail (or one already carrying depth)
// is left alone. Runs after reconcileCaptureModule so a rail two releases behind
// gains capture first, then depth.
func reconcileDepthModule(checkOnly bool) recResult {
	path := filepath.Join(sys.ConfigHome(), "ryoku", "shell.json")
	raw, err := os.ReadFile(path)
	if err != nil {
		return okRes("no shell.json yet (seeded on first shell run)")
	}
	migrated, changed, err := addDepthModule(raw)
	if err != nil {
		return warnRes("shell.json does not parse (%v); the shell falls back to defaults", err).
			withFix("delete %s to re-seed it", path)
	}
	if !changed {
		return okRes("quick-settings rail carries the depth tab (or a custom module list)")
	}
	if checkOnly {
		return wouldRes("quick-settings rail predates the Depth tab").
			withFix("ryoku doctor adds it after Capture")
	}
	tmp := path + ".ryoku-tmp"
	if err := os.WriteFile(tmp, migrated, 0o644); err != nil {
		return failRes("could not write %s: %v", tmp, err)
	}
	if err := os.Rename(tmp, path); err != nil {
		os.Remove(tmp)
		return failRes("could not replace %s: %v", path, err)
	}
	return fixedRes("added the depth tab to the quick-settings rail after Capture")
}

// addDepthModule appends "depth" to a shell store whose quick-settings module
// rail is exactly [home, notifications, weather, capture], preserving every other
// key as its own raw bytes.
func addDepthModule(raw []byte) ([]byte, bool, error) {
	var top map[string]json.RawMessage
	if err := json.Unmarshal(raw, &top); err != nil {
		return nil, false, err
	}
	frameRaw, ok := top["frameBars"]
	if !ok {
		return nil, false, nil
	}
	var frame map[string]json.RawMessage
	if err := json.Unmarshal(frameRaw, &frame); err != nil {
		return nil, false, err
	}
	menusRaw, ok := frame["menus"]
	if !ok {
		return nil, false, nil
	}
	var menus map[string]json.RawMessage
	if err := json.Unmarshal(menusRaw, &menus); err != nil {
		return nil, false, err
	}
	qsRaw, ok := menus["quick-settings"]
	if !ok {
		return nil, false, nil
	}
	var qs map[string]json.RawMessage
	if err := json.Unmarshal(qsRaw, &qs); err != nil {
		return nil, false, err
	}
	var modules []string
	if err := json.Unmarshal(qs["modules"], &modules); err != nil {
		return nil, false, nil
	}
	want := []string{"home", "notifications", "weather", "capture"}
	if len(modules) != len(want) {
		return nil, false, nil
	}
	for i := range want {
		if modules[i] != want[i] {
			return nil, false, nil
		}
	}
	next, err := json.Marshal(append(want, "depth"))
	if err != nil {
		return nil, false, err
	}
	qs["modules"] = next
	qsBytes, err := json.Marshal(qs)
	if err != nil {
		return nil, false, err
	}
	menus["quick-settings"] = qsBytes
	menusBytes, err := json.Marshal(menus)
	if err != nil {
		return nil, false, err
	}
	frame["menus"] = menusBytes
	frameBytes, err := json.Marshal(frame)
	if err != nil {
		return nil, false, err
	}
	top["frameBars"] = frameBytes
	out, err := json.MarshalIndent(top, "", "  ")
	if err != nil {
		return nil, false, err
	}
	return append(out, '\n'), true, nil
}
