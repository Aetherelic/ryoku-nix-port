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
	if id == "" {
		return "", fmt.Errorf("plugin id required")
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

	dst := pluginDataDir(id)
	if err := os.MkdirAll(filepath.Dir(dst), 0o755); err != nil {
		return "", err
	}
	// stage a sibling temp tree; discarded on any failure, renamed into place
	// only once complete so an aborted fetch never looks installed.
	stage, err := os.MkdirTemp(filepath.Dir(dst), ".stage-*")
	if err != nil {
		return "", err
	}
	defer os.RemoveAll(stage)

	write := func(name string, data []byte, mode os.FileMode) error {
		return atomicWrite(filepath.Join(stage, filepath.Clean(name)), data, mode)
	}
	optional := map[string]bool{"README.md": true, "assets/preview.gif": true}
	files := []string{"README.md", "assets/preview.gif"}
	for _, f := range man.EntryPoints {
		files = append(files, f)
	}
	files = append(files, man.Commands...)
	files = append(files, man.Files...)
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
		if err := write(f, b, mode); err != nil {
			return "", err
		}
	}
	// manifest last inside the stage, then swap the whole tree into place.
	if err := write("manifest.json", manRaw, 0o644); err != nil {
		return "", err
	}
	// replace any prior install atomically; symlink-safe so a dev plugin's
	// symlinked source tree is unlinked, never clobbered through the link.
	if fi, err := os.Lstat(dst); err == nil {
		if fi.Mode()&os.ModeSymlink != 0 {
			if err := os.Remove(dst); err != nil {
				return "", err
			}
		} else if err := os.RemoveAll(dst); err != nil {
			return "", err
		}
	}
	if err := os.Rename(stage, dst); err != nil {
		return "", err
	}
	// seed the plugin's preset block into plugins.json so its settings exist in
	// the right place the moment it lands (forgotten again on uninstall). This
	// never sets enabled: install places, it does not activate.
	_ = exec.Command("ryoku-plugins-place", id, "seed").Run()
	return dst, nil
}

// removePlugin nukes an installed plugin from the data dir and drops its
// plugins.json entry (placement + settings) so its config disappears with it.
// Symlink-safe: a dev plugin is often a symlink into a checkout, so the symlink
// itself is unlinked, never recursed into; a real install gets RemoveAll.
func removePlugin(id string) error {
	if id == "" {
		return fmt.Errorf("plugin id required")
	}
	_ = exec.Command("ryoku-plugins-place", id, "forget").Run()
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
	if id == "" {
		return "", fmt.Errorf("nautilus pack id required")
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
	root := filepath.Join(nautilusScriptsDir(), subdir)
	if err := os.MkdirAll(root, 0o755); err != nil {
		return "", err
	}
	for _, s := range man.Scripts {
		b, err := c.get(ctx, path+"/scripts/"+s)
		if err != nil {
			return "", fmt.Errorf("nautilus pack %q: could not fetch %s: %w", id, s, err)
		}
		if err := atomicWrite(filepath.Join(root, filepath.Clean(s)), b, 0o755); err != nil {
			return "", err
		}
	}
	track := nautilusTrackDir(id)
	if err := os.MkdirAll(track, 0o755); err != nil {
		return "", err
	}
	rec, _ := json.Marshal(map[string]any{"id": id, "subdir": subdir, "scripts": man.Scripts})
	_ = os.WriteFile(filepath.Join(track, "manifest.json"), rec, 0o644)
	return root, nil
}

// removeNautilusPack deletes a pack's installed scripts (its whole subdir) and
// the tracking record. No-op if never installed.
func removeNautilusPack(id string) error {
	if id == "" {
		return fmt.Errorf("nautilus pack id required")
	}
	track := nautilusTrackDir(id)
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
	_ = json.Unmarshal(b, &rec)
	if rec.Subdir != "" {
		_ = os.RemoveAll(filepath.Join(nautilusScriptsDir(), rec.Subdir))
	}
	return os.RemoveAll(track)
}
