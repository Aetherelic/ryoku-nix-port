package doctor

import (
	"strings"
)

// ---- what layout is this keyboard, really ------------------------------------
//
// A keyboard cannot be asked. USB/HID reports scancodes and a product name, not
// the legends printed on the keys, so an AZERTY board and a QWERTY board are the
// same device to the kernel. Hyprland's per-device `layout` is just the layout
// already configured, so reading it back only ever confirms our own guess.
//
// What the machine does know is what the person told the installer. A keymap
// picked there lands in /etc/vconsole.conf, and a deliberate localectl call
// lands in the X11 config. Both are real statements about the physical board.
// The locale is a weaker third: someone installing in fr_FR is usually typing on
// a French keyboard, though a French speaker on a US board is common enough that
// it must never outrank an explicit keymap.
//
// So detection is: read what is already recorded, strongest source first.

// consoleToXkb maps the console keymap names that differ from their xkb layout
// code. Anything not listed passes through unchanged, which covers the many that
// already agree (fr, de, es, it, pt, ru, ...).
var consoleToXkb = map[string]string{
	"uk": "gb", "gb": "gb",
	"fr-latin1": "fr", "fr-pc": "fr", "azerty": "fr",
	"be-latin1": "be",
	"de-latin1": "de", "de_CH-latin1": "ch", "sg": "ch", "sf": "ch",
	"es-cp850": "es", "la-latin1": "latam",
	"it2":       "it",
	"pt-latin1": "pt", "br-abnt2": "br",
	"no-latin1": "no", "nb": "no", "fi-latin1": "fi", "se-latin1": "se",
	"dk-latin1": "dk", "is-latin1": "is",
	"pl2": "pl", "cz-lat2": "cz", "sk-qwertz": "sk",
	"hu101": "hu", "croat": "hr", "slovene": "si",
	"trq": "tr", "trf": "tr",
	"ua-utf": "ua", "ruwin_alt-UTF-8": "ru",
	"gr": "gr", "il": "il",
	"jp106": "jp", "kr": "kr",
	"us-acentos": "us", "dvorak": "us", "colemak": "us",
}

// localeToXkb maps a locale country to the layout that country ships on its
// keyboards. Only the unambiguous ones: a country whose boards are commonly
// QWERTY (IE, NL, MT, and every English locale) is left out so it falls to us.
var localeToXkb = map[string]string{
	"FR": "fr", "BE": "be", "LU": "fr",
	"DE": "de", "AT": "de", "CH": "ch",
	"ES": "es", "IT": "it", "PT": "pt", "BR": "br",
	"RU": "ru", "UA": "ua", "PL": "pl", "CZ": "cz", "SK": "sk",
	"HU": "hu", "HR": "hr", "SI": "si", "RS": "rs", "BG": "bg",
	"RO": "ro", "GR": "gr", "TR": "tr", "IL": "il",
	"SE": "se", "NO": "no", "DK": "dk", "FI": "fi", "IS": "is", "EE": "ee",
	"LV": "lv", "LT": "lt", "JP": "jp", "KR": "kr",
	"GB": "gb", "MA": "fr", "DZ": "fr", "TN": "fr", "SN": "fr", "CI": "fr",
}

// detectedLayout is one answer plus where it came from, so the report can say
// why rather than just asserting a code.
type detectedLayout struct {
	Layout string
	Source string
}

// detectKeyboardLayout resolves the layout from what the system already records.
// Empty Layout means nothing on the box says anything, so nothing should change.
func detectKeyboardLayout(x11, console, locale string) detectedLayout {
	// 1. an explicit X11 layout is already an xkb code and was set on purpose.
	if v := strings.TrimSpace(x11); v != "" {
		if first := strings.SplitN(v, ",", 2)[0]; first != "" {
			return detectedLayout{Layout: first, Source: "the X11 keymap"}
		}
	}
	// 2. the console keymap: what was picked during installation.
	if v := strings.TrimSpace(console); v != "" {
		if mapped, ok := consoleToXkb[v]; ok {
			return detectedLayout{Layout: mapped, Source: "the console keymap"}
		}
		// a bare two-or-three letter keymap usually equals its xkb code
		if len(v) <= 3 && !strings.ContainsAny(v, "-_") {
			return detectedLayout{Layout: v, Source: "the console keymap"}
		}
		// strip a trailing charset suffix ("fr-latin9" -> "fr") as a last try
		if base := strings.SplitN(v, "-", 2)[0]; len(base) <= 3 && base != "" {
			return detectedLayout{Layout: base, Source: "the console keymap"}
		}
	}
	// 3. the locale's country, the weakest of the three.
	if c := localeCountry(locale); c != "" {
		if mapped, ok := localeToXkb[c]; ok {
			return detectedLayout{Layout: mapped, Source: "the system locale"}
		}
	}
	return detectedLayout{}
}

// localeCountry pulls the country out of a locale string ("fr_FR.UTF-8" -> FR).
func localeCountry(locale string) string {
	v := strings.TrimSpace(locale)
	if v == "" {
		return ""
	}
	if i := strings.IndexAny(v, ".@"); i >= 0 {
		v = v[:i]
	}
	parts := strings.SplitN(v, "_", 2)
	if len(parts) != 2 {
		return ""
	}
	return strings.ToUpper(parts[1])
}
