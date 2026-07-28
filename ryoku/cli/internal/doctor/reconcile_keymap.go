package doctor

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"strings"
	"time"
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
