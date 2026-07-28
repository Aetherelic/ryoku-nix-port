package doctor

import (
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"strings"
	"time"

	"ryoku-cli/internal/sys"
)

// ---- reconciler: the keyboard layout, on every screen that asks for one -------
//
// A layout is set in four places and the desktop only owns one of them:
//
//	Hyprland  settings.lua input.kb_layout   the session, once you are logged in
//	X11       /etc/X11/xorg.conf.d/00-keyboard.conf   the SDDM greeter
//	console   /etc/vconsole.conf KEYMAP      the TTYs, after the initramfs hands over
//	initramfs a COPY of vconsole.conf        the LUKS passphrase prompt
//
// The last one is the trap. mkinitcpio's sd-vconsole hook does `add_file
// /etc/vconsole.conf` at BUILD time, so the passphrase prompt uses whatever the
// keymap was when the boot image was last generated. Editing /etc/vconsole.conf
// afterwards, by hand or through localectl, cannot reach it: an AZERTY user
// keeps typing their passphrase on a QWERTY prompt until the image is rebuilt.
//
// This reports drift and, for the two plain config files, fixes it. It never
// rebuilds the boot image itself: that regenerates what the machine boots from,
// so it prints the command instead, the same way the alongside boot entry does.

var keymapLayoutRe = regexp.MustCompile(`kb_layout\s*=\s*"([^"]*)"`)

// hyprLayout reads the session's primary layout from settings.lua. The value can
// carry a second layout ("fr,us"); the first is the one a login screen needs.
func hyprLayout() string {
	b, err := os.ReadFile(filepath.Join(configHome(), "hypr", "settings.lua"))
	if err != nil {
		return ""
	}
	m := keymapLayoutRe.FindSubmatch(b)
	if m == nil {
		return ""
	}
	return strings.TrimSpace(strings.SplitN(string(m[1]), ",", 2)[0])
}

// vconsoleKeymap reads KEYMAP from /etc/vconsole.conf.
func vconsoleKeymap() string {
	b, err := os.ReadFile("/etc/vconsole.conf")
	if err != nil {
		return ""
	}
	for _, line := range strings.Split(string(b), "\n") {
		line = strings.TrimSpace(line)
		if v, ok := strings.CutPrefix(line, "KEYMAP="); ok {
			return strings.Trim(strings.TrimSpace(v), `"`)
		}
	}
	return ""
}

// bootImageTime is the newest boot image mtime: the UKIs this machine boots, or
// the plain initramfs images. Zero when none is readable.
// bootImageGlobs is a package var so a test can point it at a temp dir.
var bootImageGlobs = []string{"/boot/EFI/Linux/*.efi", "/boot/initramfs-*.img"}

func bootImageTime() (time.Time, string) {
	var newest time.Time
	var which string
	globs := bootImageGlobs
	for _, g := range globs {
		paths, _ := filepath.Glob(g)
		for _, p := range paths {
			if strings.Contains(p, "fallback") {
				continue
			}
			fi, err := os.Stat(p)
			if err != nil {
				continue
			}
			if fi.ModTime().After(newest) {
				newest = fi.ModTime()
				which = p
			}
		}
	}
	return newest, which
}

func reconcileKeymap(checkOnly bool) recResult {
	layout := hyprLayout()
	if layout == "" {
		return okRes("no session keyboard layout recorded yet")
	}
	km := vconsoleKeymap()

	// The console keymap and the X11 layout share a name for the common codes
	// (us, fr, de, be...). localectl owns the conversion for the odd ones, so a
	// mismatch here is the signal, not the exact mapping.
	consoleDrifted := km != "" && km != layout

	// The passphrase prompt reads the copy baked into the boot image, so a
	// vconsole.conf newer than that image means the prompt is still on the old
	// keymap however correct /etc looks.
	stale := false
	imgWhen, imgPath := bootImageTime()
	if fi, err := os.Stat("/etc/vconsole.conf"); err == nil && !imgWhen.IsZero() {
		stale = fi.ModTime().After(imgWhen)
	}

	switch {
	case consoleDrifted && stale:
		return warnRes("console keymap is %q but the session uses %q, and the boot image predates /etc/vconsole.conf so the disk passphrase prompt is older still", km, layout).
			withFix("sudo localectl set-x11-keymap %s && sudo mkinitcpio -P", layout)
	case consoleDrifted:
		if checkOnly {
			return wouldRes("console keymap is %q but the session uses %q, so the login screen and TTYs disagree with the desktop", km, layout).
				withFix("ryoku doctor")
		}
		if err := runQuiet("localectl", "set-x11-keymap", layout); err != nil {
			return warnRes("console keymap is %q but the session uses %q", km, layout).
				withFix("sudo localectl set-x11-keymap %s && sudo mkinitcpio -P", layout)
		}
		// The files now agree; the boot image still holds the old copy.
		return fixedRes("set the login screen and TTY keymap to %q; rebuild the boot image so the disk passphrase prompt follows: sudo mkinitcpio -P", layout)
	case stale:
		return warnRes("%s predates /etc/vconsole.conf, so the disk passphrase prompt still uses the keymap baked in when it was built", filepath.Base(imgPath)).
			withFix("sudo mkinitcpio -P")
	}
	return okRes("keyboard layout %q matches on the session, login screen, and console", layout)
}

// runQuiet runs a command and reports only whether it succeeded. localectl
// escalates through polkit on its own, so this needs no sudo of its own.
func runQuiet(name string, args ...string) error {
	out, err := exec.Command(name, args...).CombinedOutput()
	if err != nil {
		return fmt.Errorf("%s: %w (%s)", name, err, strings.TrimSpace(string(out)))
	}
	return nil
}

// ---- reconciler: adopt the keyboard the installer was told about --------------

// keyboardSeedMarker records that the one-time adoption has run, so a later
// deliberate pick in Ryoku Settings is never quietly undone on the next doctor.
func keyboardSeedMarker() string {
	return filepath.Join(sys.Xdg("XDG_STATE_HOME", ".local/state"), "ryoku", "migrations", "keyboard-layout-seed")
}

// hyprGetKbLayout pulls input.kbLayout out of a saved hypr.json.
func hyprGetKbLayout(raw string) (string, bool) {
	var o struct {
		Input struct {
			KbLayout *string `json:"kbLayout"`
		} `json:"input"`
	}
	if json.Unmarshal([]byte(raw), &o) != nil || o.Input.KbLayout == nil {
		return "", false
	}
	return *o.Input.KbLayout, true
}

// hyprSetKbLayout rewrites input.kbLayout, leaving every other key untouched.
func hyprSetKbLayout(raw, layout string) (string, error) {
	var doc map[string]any
	if err := json.Unmarshal([]byte(raw), &doc); err != nil {
		return "", err
	}
	input, _ := doc["input"].(map[string]any)
	if input == nil {
		input = map[string]any{}
		doc["input"] = input
	}
	input["kbLayout"] = layout
	out, err := json.MarshalIndent(doc, "", "  ")
	if err != nil {
		return "", err
	}
	return string(out), nil
}

// reconcileKeyboardSeed adopts the layout the machine already records when the
// desktop is still on the shipped default. A keyboard cannot report its own
// legends, so installing with an AZERTY keymap and then finding the desktop on
// QWERTY is the normal first-boot experience; this closes that gap once.
func reconcileKeyboardSeed(checkOnly bool) recResult {
	marker := keyboardSeedMarker()
	if sys.Exists(marker) {
		return okRes("keyboard layout already adopted once")
	}
	mark := func() {
		if checkOnly {
			return
		}
		_ = os.MkdirAll(filepath.Dir(marker), 0o755)
		_ = os.WriteFile(marker, []byte("done\n"), 0o644)
	}
	hyprJSON := filepath.Join(sys.ConfigHome(), "ryoku", "hypr.json")
	if !sys.Has("ryoku-hub") || !sys.Exists(hyprJSON) {
		mark()
		return okRes("no saved hypr input to seed a layout into")
	}
	cur, ok := hyprGetKbLayout(readFileSafe(hyprJSON))
	// Only the untouched shipped default is adopted over. Anything else is a
	// choice, including a deliberate "us".
	if !ok || cur != "us" {
		mark()
		return okRes("keyboard layout is a deliberate choice; leaving it")
	}
	got := detectKeyboardLayout(x11Layout(), vconsoleKeymap(), systemLocale())
	if got.Layout == "" || got.Layout == "us" {
		mark()
		return okRes("nothing on this system points at a non-US keyboard")
	}
	if checkOnly {
		return wouldRes("%s says this is a %q keyboard but the desktop is still on us", got.Source, got.Layout).
			withFix("ryoku doctor")
	}
	raw, err := sys.RunOut("ryoku-hub", "hypr", "get")
	if err != nil {
		return warnRes("could not read hypr settings to adopt the layout: %v", err)
	}
	fixed, err := hyprSetKbLayout(raw, got.Layout)
	if err != nil {
		return failRes("could not update hypr settings: %v", err)
	}
	if err := sys.Run("ryoku-hub", "hypr", "save", fixed); err != nil {
		return failRes("could not save the detected layout: %v", err).withFix("ryoku doctor")
	}
	mark()
	return fixedRes("adopted the %q keyboard layout from %s", got.Layout, got.Source)
}

// x11Layout reads the greeter's layout from the X11 keyboard config.
func x11Layout() string {
	b, err := os.ReadFile("/etc/X11/xorg.conf.d/00-keyboard.conf")
	if err != nil {
		return ""
	}
	m := x11LayoutRe.FindSubmatch(b)
	if m == nil {
		return ""
	}
	return strings.TrimSpace(string(m[1]))
}

var x11LayoutRe = regexp.MustCompile(`(?i)Option\s+"XkbLayout"\s+"([^"]*)"`)

// systemLocale prefers /etc/locale.conf over the caller's environment, so a
// doctor run from an odd shell still reads what the system was installed as.
func systemLocale() string {
	if b, err := os.ReadFile("/etc/locale.conf"); err == nil {
		for _, line := range strings.Split(string(b), "\n") {
			if v, ok := strings.CutPrefix(strings.TrimSpace(line), "LANG="); ok {
				return strings.Trim(strings.TrimSpace(v), `"`)
			}
		}
	}
	return os.Getenv("LANG")
}
