// Guest asset primitives: the install/remove operations Ryostore performs on
// the machine for a plugin, a bundle script installer, or a Nautilus pack. They
// write to the runtime's own data directories (never the browse cache) and are
// reached through the `internal install-guest`/`remove-guest`/`installer`
// commands the extras actuator calls. Every write lands atomically and, for a
// plugin, manifest-last inside a staging directory renamed into place only once
// complete, so an aborted fetch never leaves a half-installed guest the runtime
// would try to mount. Removal is symlink-safe: a dev guest symlinked into a
// checkout is unlinked, never recursed into.
package main

import (
	"context"
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
)

var renamePath = os.Rename

func validComponent(name string) bool {
	return name != "" && name != "." && !strings.HasPrefix(name, ".ryostore-") && filepath.IsLocal(name) && filepath.Clean(name) == name && filepath.Base(name) == name
}

func validLocalPath(name string) bool {
	return name != "" && name != "." && filepath.IsLocal(name) && filepath.Clean(name) == name
}

func rejectSymlinkPath(root, rel string) error {
	current := root
	for _, part := range strings.Split(rel, string(filepath.Separator)) {
		current = filepath.Join(current, part)
		fi, err := os.Lstat(current)
		if err != nil {
			if os.IsNotExist(err) {
				continue
			}
			return err
		}
		if fi.Mode()&os.ModeSymlink != 0 {
			return fmt.Errorf("%s is a symlink", current)
		}
	}
	return nil
}

func backupTreePath(dst string) string {
	return filepath.Join(filepath.Dir(dst), ".ryostore-backup-"+filepath.Base(dst))
}

func recoverTree(dst string) error {
	backup := backupTreePath(dst)
	if _, err := os.Lstat(backup); err != nil {
		if os.IsNotExist(err) {
			return nil
		}
		return err
	}
	if _, err := os.Lstat(dst); err == nil {
		return os.RemoveAll(backup)
	} else if !os.IsNotExist(err) {
		return err
	}
	return renamePath(backup, dst)
}

func replaceTree(stage, dst string, finalize func() error) error {
	if err := recoverTree(dst); err != nil {
		return fmt.Errorf("recover prior install: %w", err)
	}
	backup := backupTreePath(dst)
	hadPrior := false
	if _, err := os.Lstat(dst); err == nil {
		if err := renamePath(dst, backup); err != nil {
			return err
		}
		hadPrior = true
	} else if !os.IsNotExist(err) {
		return err
	}

	restore := func(cause error) error {
		_ = os.RemoveAll(dst)
		if hadPrior {
			if err := renamePath(backup, dst); err != nil {
				return fmt.Errorf("%w; restore prior install: %v", cause, err)
			}
		}
		return cause
	}
	if err := renamePath(stage, dst); err != nil {
		return restore(err)
	}
	if finalize != nil {
		if err := finalize(); err != nil {
			return restore(err)
		}
	}
	if hadPrior {
		return os.RemoveAll(backup)
	}
	return nil
}

func dataHome() string {
	if b := os.Getenv("XDG_DATA_HOME"); b != "" {
		return b
	}
	return filepath.Join(os.Getenv("HOME"), ".local", "share")
}

// atomicWrite writes b to path via a same-directory temp file and rename, so a
// reader never sees a half-written file.
func atomicWrite(path string, b []byte, mode os.FileMode) error {
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		return err
	}
	f, err := os.CreateTemp(filepath.Dir(path), ".tmp-*")
	if err != nil {
		return err
	}
	tmp := f.Name()
	if _, err := f.Write(b); err != nil {
		f.Close()
		os.Remove(tmp)
		return err
	}
	if err := f.Chmod(mode); err != nil {
		f.Close()
		os.Remove(tmp)
		return err
	}
	if err := f.Close(); err != nil {
		os.Remove(tmp)
		return err
	}
	return os.Rename(tmp, path)
}

// installGuest routes an internal install-guest call to the primitive for its
// kind. Both kinds place the guest without activating it.
func installGuest(kind, id string) error {
	switch kind {
	case "plugins":
		_, err := ensurePlugin(id)
		return err
	case "nautilus":
		_, err := ensureNautilusPack(id)
		return err
	default:
		return fmt.Errorf("unknown guest kind %q", kind)
	}
}

// removeGuest routes an internal remove-guest call to the primitive for its
// kind. Both removals are symlink-safe.
func removeGuest(kind, id string) error {
	switch kind {
	case "plugins":
		return removePlugin(id)
	case "nautilus":
		return removeNautilusPack(id)
	default:
		return fmt.Errorf("unknown guest kind %q", kind)
	}
}

// pluginDataDir is where an installed plugin's source lives; the shell runtime
// and Ryoku Settings both read it. Mirrors plugin_dir() in ryoku-extras-install.
func pluginDataDir(id string) string {
	return filepath.Join(dataHome(), "ryoku", "plugins", id)
}

// ensurePlugin pulls a plugin's full source tree from the catalogue
// (plugins/<id>/) into a staging directory and renames it into the data dir only
// once every manifest-declared file has arrived. The manifest is read to know
// which files to grab (entryPoints + commands + files); README and the preview
// are cosmetic and skip on a miss. It seeds the plugin's preset block into
// plugins.json but never enables it: installing must not activate placement.
func ensurePlugin(id string) (string, error) {
	if !validComponent(id) {
		return "", fmt.Errorf("invalid plugin id %q", id)
	}
	c := newCache()
	ctx := context.Background()
	rel := "plugins/" + id
	manRaw, err := c.get(ctx, rel+"/manifest.json")
	if err != nil {
		return "", fmt.Errorf("plugin %q not found in the catalogue: %w", id, err)
	}
	var man struct {
		EntryPoints map[string]string `json:"entryPoints"`
		Commands    []string          `json:"commands"`
		Files       []string          `json:"files"`
	}
	if err := json.Unmarshal(manRaw, &man); err != nil {
		return "", fmt.Errorf("plugin %q manifest: %w", id, err)
	}

	optional := map[string]bool{"README.md": true, "assets/preview.gif": true}
	files := []string{"README.md", "assets/preview.gif"}
	for _, f := range man.EntryPoints {
		files = append(files, f)
	}
	files = append(files, man.Commands...)
	files = append(files, man.Files...)
	for _, f := range files {
		if !validLocalPath(f) {
			return "", fmt.Errorf("plugin %q has invalid file path %q", id, f)
		}
	}

	dst := pluginDataDir(id)
	if err := os.MkdirAll(filepath.Dir(dst), 0o755); err != nil {
		return "", err
	}
	if err := recoverTree(dst); err != nil {
		return "", fmt.Errorf("recover plugin %q: %w", id, err)
	}
	_, priorErr := os.ReadFile(filepath.Join(dst, "manifest.json"))
	priorInstalled := priorErr == nil
	if priorErr != nil && !os.IsNotExist(priorErr) {
		return "", priorErr
	}
	stage, err := os.MkdirTemp(filepath.Dir(dst), ".stage-*")
	if err != nil {
		return "", err
	}
	defer os.RemoveAll(stage)

	for _, f := range files {
		b, err := c.get(ctx, rel+"/"+f)
		if err != nil {
			if optional[f] {
				continue
			}
			return "", fmt.Errorf("plugin %q: could not fetch %s: %w", id, f, err)
		}
		mode := os.FileMode(0o644)
		if strings.HasPrefix(f, "bin/") {
			mode = 0o755
		}
		if err := atomicWrite(filepath.Join(stage, f), b, mode); err != nil {
			return "", err
		}
	}
	if err := atomicWrite(filepath.Join(stage, "manifest.json"), manRaw, 0o644); err != nil {
		return "", err
	}

	if !priorInstalled {
		if err := exec.Command("ryoku-plugins-place", id, "enabled", "false").Run(); err != nil {
			return "", fmt.Errorf("disable plugin placement before install: %w", err)
		}
	}
	if err := replaceTree(stage, dst, func() error {
		if err := exec.Command("ryoku-plugins-place", id, "seed").Run(); err != nil {
			return fmt.Errorf("seed plugin settings: %w", err)
		}
		return nil
	}); err != nil {
		return "", err
	}
	return dst, nil
}

// removePlugin removes only the installed source tree. Placement and settings
// survive bundle removal; Settings explicitly forgets them for a full uninstall.
// Symlink-safe: a dev source link is unlinked, never traversed.
func removePlugin(id string) error {
	if !validComponent(id) {
		return fmt.Errorf("invalid plugin id %q", id)
	}
	dir := pluginDataDir(id)
	fi, err := os.Lstat(dir)
	if err != nil {
		if os.IsNotExist(err) {
			return nil
		}
		return err
	}
	if fi.Mode()&os.ModeSymlink != 0 {
		return os.Remove(dir)
	}
	return os.RemoveAll(dir)
}

// ensureInstaller pulls a fresh copy of installers/<name>.sh into the cache and
// returns its path, falling back to the cached copy when the source is offline.
func ensureInstaller(name string) (string, error) {
	if !validComponent(name) {
		return "", fmt.Errorf("invalid installer name %q", name)
	}
	rel := "installers/" + name + ".sh"
	if _, _, err := newCache().Fetch(context.Background(), rel, true); err != nil {
		return "", fmt.Errorf("installer %q not found in the catalogue: %w", name, err)
	}
	return filepath.Join(extrasCacheDir(), rel), nil
}

type nautilusPack struct {
	ID     string `json:"id"`
	Name   string `json:"name"`
	Path   string `json:"path,omitempty"`
	Subdir string `json:"subdir,omitempty"`
}

type nautilusRegistry struct {
	Version int            `json:"version"`
	Packs   []nautilusPack `json:"packs"`
}

// nautilusScriptsDir is where Nautilus reads user scripts. nautilusTrackDir is
// our per-pack record of what we installed, so removal is exact.
func nautilusScriptsDir() string { return filepath.Join(dataHome(), "nautilus", "scripts") }
func nautilusTrackDir(id string) string {
	return filepath.Join(dataHome(), "ryoku", "nautilus", id)
}

// ensureNautilusPack fetches a pack's scripts into the Nautilus scripts dir
// under its subdir (0755, live-rescanned), recording the file list for a clean
// removal. The scripts ARE the pack, so a failed fetch aborts rather than
// landing a pack with missing right-click actions that still reports installed.
func ensureNautilusPack(id string) (string, error) {
	if !validComponent(id) {
		return "", fmt.Errorf("invalid nautilus pack id %q", id)
	}
	c := newCache()
	ctx := context.Background()
	raw, err := c.get(ctx, "nautilus/registry.json")
	if err != nil {
		return "", fmt.Errorf("nautilus catalogue not found: %w", err)
	}
	var reg nautilusRegistry
	if err := json.Unmarshal(raw, &reg); err != nil {
		return "", fmt.Errorf("nautilus/registry.json: %w", err)
	}
	var pk *nautilusPack
	for i := range reg.Packs {
		if reg.Packs[i].ID == id {
			pk = &reg.Packs[i]
			break
		}
	}
	if pk == nil {
		return "", fmt.Errorf("nautilus pack %q not in the catalogue", id)
	}
	path := pk.Path
	if path == "" {
		path = "nautilus/" + id
	}
	if !validLocalPath(path) {
		return "", fmt.Errorf("nautilus pack %q has invalid source path %q", id, path)
	}
	manRaw, err := c.get(ctx, path+"/manifest.json")
	if err != nil {
		return "", fmt.Errorf("nautilus pack %q manifest: %w", id, err)
	}
	var man struct {
		Subdir  string   `json:"subdir"`
		Scripts []string `json:"scripts"`
	}
	if err := json.Unmarshal(manRaw, &man); err != nil {
		return "", fmt.Errorf("nautilus pack %q manifest: %w", id, err)
	}
	subdir := man.Subdir
	if subdir == "" {
		subdir = pk.Subdir
	}
	if subdir == "" {
		subdir = pk.Name
	}
	if subdir == "" {
		subdir = id
	}
	if !validLocalPath(subdir) {
		return "", fmt.Errorf("nautilus pack %q has invalid subdir %q", id, subdir)
	}
	track := nautilusTrackDir(id)
	if oldRaw, err := os.ReadFile(filepath.Join(track, "manifest.json")); err == nil {
		var old struct {
			Subdir string `json:"subdir"`
		}
		if err := json.Unmarshal(oldRaw, &old); err != nil {
			return "", fmt.Errorf("nautilus tracking manifest: %w", err)
		}
		if old.Subdir != subdir {
			return "", fmt.Errorf("nautilus pack %q cannot change subdir from %q to %q", id, old.Subdir, subdir)
		}
	} else if !os.IsNotExist(err) {
		return "", err
	}
	for _, script := range man.Scripts {
		if !validLocalPath(script) {
			return "", fmt.Errorf("nautilus pack %q has invalid script path %q", id, script)
		}
	}

	scriptsRoot := nautilusScriptsDir()
	if err := rejectSymlinkPath(scriptsRoot, subdir); err != nil {
		return "", err
	}
	root := filepath.Join(scriptsRoot, subdir)
	if err := os.MkdirAll(filepath.Dir(root), 0o755); err != nil {
		return "", err
	}
	stage, err := os.MkdirTemp(filepath.Dir(root), ".stage-*")
	if err != nil {
		return "", err
	}
	defer os.RemoveAll(stage)
	for _, script := range man.Scripts {
		b, err := c.get(ctx, path+"/scripts/"+script)
		if err != nil {
			return "", fmt.Errorf("nautilus pack %q: could not fetch %s: %w", id, script, err)
		}
		if err := atomicWrite(filepath.Join(stage, script), b, 0o755); err != nil {
			return "", err
		}
	}

	rec, err := json.Marshal(map[string]any{"id": id, "subdir": subdir, "scripts": man.Scripts})
	if err != nil {
		return "", err
	}
	// The tracking tree is prepared before publication; its manifest is renamed
	// last by the replace transaction below.
	if fi, err := os.Lstat(track); err == nil && fi.Mode()&os.ModeSymlink != 0 {
		return "", fmt.Errorf("%s is a symlink", track)
	} else if err != nil && !os.IsNotExist(err) {
		return "", err
	}
	if err := os.MkdirAll(track, 0o755); err != nil {
		return "", err
	}
	pending, err := os.CreateTemp(track, ".manifest-*")
	if err != nil {
		return "", err
	}
	pendingName := pending.Name()
	defer os.Remove(pendingName)
	if _, err := pending.Write(rec); err != nil {
		pending.Close()
		return "", err
	}
	if err := pending.Chmod(0o644); err != nil {
		pending.Close()
		return "", err
	}
	if err := pending.Close(); err != nil {
		return "", err
	}

	if err := replaceTree(stage, root, func() error {
		return renamePath(pendingName, filepath.Join(track, "manifest.json"))
	}); err != nil {
		return "", err
	}
	return root, nil
}

// removeNautilusPack deletes a pack's installed scripts (its whole subdir) and
// the tracking record. No-op if never installed.
func removeNautilusPack(id string) error {
	if !validComponent(id) {
		return fmt.Errorf("invalid nautilus pack id %q", id)
	}
	track := nautilusTrackDir(id)
	if fi, err := os.Lstat(track); err == nil && fi.Mode()&os.ModeSymlink != 0 {
		return fmt.Errorf("%s is a symlink", track)
	} else if err != nil && !os.IsNotExist(err) {
		return err
	}
	b, err := os.ReadFile(filepath.Join(track, "manifest.json"))
	if err != nil {
		if os.IsNotExist(err) {
			return nil
		}
		return err
	}
	var rec struct {
		Subdir string `json:"subdir"`
	}
	if err := json.Unmarshal(b, &rec); err != nil {
		return fmt.Errorf("nautilus tracking manifest: %w", err)
	}
	if !validLocalPath(rec.Subdir) {
		return fmt.Errorf("invalid tracked nautilus subdir %q", rec.Subdir)
	}
	if err := rejectSymlinkPath(nautilusScriptsDir(), rec.Subdir); err != nil {
		return err
	}
	if err := os.RemoveAll(filepath.Join(nautilusScriptsDir(), rec.Subdir)); err != nil {
		return err
	}
	return os.RemoveAll(track)
}
