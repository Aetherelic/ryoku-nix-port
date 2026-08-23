package main

// qmk.go: the QMK/VIA keyboard lighting provider. One concern: driving the RGB
// matrix of a VIA-enabled QMK keyboard (Framework Laptop 16, custom mechanical
// boards) through the `qmk_hid` tool, so a board OpenRGB cannot reach and asusd
// does not own still follows the desktop accent.
//
// Unlike OpenRGB (rich per-LED SDK) and Aura (asusd D-Bus), qmk_hid is a small
// CLI over hidraw. It exposes a solid-colour matrix effect by hue/saturation,
// which is exactly what a theme-follow needs; per-key painting and the board's
// firmware effect list (which effects are compiled in varies per keymap) are out
// of scope, so this provider offers one honest mode: Static, accent-driven.
//
// No `--save`: writing the colour to EEPROM on every theme change would wear the
// chip, and Ryoku re-applies on login (autostart) and on resume (hypridle), so
// the live colour is restored each session without persisting it.

import (
	"fmt"
	"math"
	"os/exec"
	"strconv"
	"strings"
)

const (
	qmkProvider          = "qmk"
	qmkEffectStatic      = 1 // RGB_MATRIX_SOLID_COLOR (QMK firmware enum; qmk_hid --rgb-effect 1)
	qmkNoDeviceMarker    = "No device found"
	qmkDefaultDeviceName = "QMK keyboard"
)

// Seams so the provider is unit-testable without a keyboard or the tool.
var (
	qmkLookPath = func() bool { _, err := exec.LookPath("qmk_hid"); return err == nil }
	qmkList     = func() (string, error) {
		out, err := exec.Command("qmk_hid", "--list").CombinedOutput()
		return string(out), err
	}
	qmkRun = func(args ...string) error { return exec.Command("qmk_hid", args...).Run() }
)

func qmkInstalled() bool { return qmkLookPath() }

// qmkDevicePresent asks qmk_hid what is connected. The tool prints "No device
// found" and exits 0 when nothing matches, so absence is a clean signal rather
// than an error; a permission or enumeration failure is also treated as absent.
func qmkDevicePresent() bool {
	if !qmkInstalled() {
		return false
	}
	out, err := qmkList()
	if err != nil {
		return false
	}
	trimmed := strings.TrimSpace(out)
	if trimmed == "" || strings.Contains(out, qmkNoDeviceMarker) {
		return false
	}
	return true
}

// readQMKDevices presents a connected VIA keyboard as one device with a single
// Static mode. It never touches the board on an ordinary state read; enumeration
// only runs from a scan or an apply, exactly like the other providers.
func readQMKDevices() ([]orgbDevice, error) {
	if !qmkDevicePresent() {
		return nil, nil
	}
	return []orgbDevice{qmkDeviceView()}, nil
}

func qmkDeviceView() orgbDevice {
	static := orgbMode{
		Name:      "Static",
		Value:     qmkEffectStatic,
		Flags:     modeHasModeColor | modeHasBrightness,
		BriMin:    0,
		BriMax:    100,
		ColorsMin: 1,
		ColorsMax: 1,
		Bri:       100,
		ColorMode: 2, // MODE_COLORS_MODE_SPECIFIC
		Colors:    []uint32{0xFFFFFF},
	}
	return orgbDevice{
		Provider:    qmkProvider,
		Type:        "Keyboard",
		Name:        qmkDefaultDeviceName,
		Vendor:      "QMK",
		Description: "QMK/VIA keyboard",
		Serial:      qmkProvider + ":keyboard",
		Location:    "qmk_hid",
		ActiveMode:  0,
		Modes:       []orgbMode{static},
	}
}

// qmkApply drives the board: the mode already carries the tuned colour and any
// user brightness, so this converts that colour to the hue/saturation the VIA
// protocol wants and fires one write. Brightness is a percentage (0-100) as
// qmk_hid expects; a device-own brightness (-1) means full.
func qmkApply(mode orgbMode, brightness int) error {
	hue, sat := 0, 0
	if len(mode.Colors) > 0 {
		r, g, b := unpackRGB(mode.Colors[0])
		h, s := rgbToHSV255(r, g, b)
		hue, sat = int(h), int(s)
	}
	bri := 100
	if brightness >= 0 {
		bri = clampPercent(brightness)
	}
	return qmkWrite(int(mode.Value), hue, sat, bri)
}

func qmkWrite(effect, hue, sat, bri int) error {
	if err := qmkRun("via",
		"--rgb-effect", strconv.Itoa(effect),
		"--rgb-hue", strconv.Itoa(hue),
		"--rgb-saturation", strconv.Itoa(sat),
		"--rgb-brightness", strconv.Itoa(bri),
	); err != nil {
		return fmt.Errorf("qmk_hid: %w", err)
	}
	return nil
}

// rgbToHSV255 mirrors Python colorsys.rgb_to_hsv scaled to the 0-255 range VIA
// uses (what omarchy's Framework 16 script computes), returning hue and
// saturation; value/brightness is carried separately as a percentage.
func rgbToHSV255(rf, gf, bf float64) (uint8, uint8) {
	maxc := math.Max(rf, math.Max(gf, bf))
	minc := math.Min(rf, math.Min(gf, bf))
	if maxc == minc {
		return 0, 0
	}
	delta := maxc - minc
	sat := delta / maxc
	rc := (maxc - rf) / delta
	gc := (maxc - gf) / delta
	bc := (maxc - bf) / delta
	var h float64
	switch maxc {
	case rf:
		h = bc - gc
	case gf:
		h = 2 + rc - bc
	default:
		h = 4 + gc - rc
	}
	h = math.Mod(h/6, 1)
	if h < 0 {
		h++
	}
	return uint8(h * 255), uint8(sat * 255)
}
