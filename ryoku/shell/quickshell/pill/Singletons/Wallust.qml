pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

/**
 * The live palette for the pill/shell, active only when Ryoku Settings ->
 * Shell -> Match wallpaper is on. wallust rewrites ~/.cache/wallust/colors.json
 * on every wallpaper change (see wallust.toml) and this watches it, so the
 * shell surface and accents retune to whatever is on screen.
 *
 * This is the runtime override source for Theme.qml: it exposes the same 30
 * Material color roles Theme exposes, so the live and the compiled-default
 * paths are interchangeable. wallust emits a sixteen-colour terminal palette,
 * not Material roles, so the roles are derived here: the wallpaper background is
 * tone-mapped into a dark surface band by shade() (a bright wallpaper never
 * lifts the surface out of readable contrast), the depth ramp is walked off it
 * by tone(), the ANSI lead hues are vivified and floored to >= 3:1 against the
 * surface by legible(), and the on/container roles are mixed from those. A
 * fuller role set can later be fed in verbatim by the Go theme daemon; the
 * property names stay the same either way. Defaults sit at Everforest Dark so
 * the shell reads correctly before the first wallust run.
 */
Singleton {
    id: w

    // Surface family: the wallpaper background tone-mapped into the dark band,
    // then the container ramp lifted off it (recesses darker, tiles lighter).
    readonly property color surface:                 shade(adapter.background)
    readonly property color surfaceContainerLowest:  surface
    readonly property color surfaceContainerLow:     tone(surface, 0.03)
    readonly property color surfaceContainer:        tone(surface, 0.05)
    readonly property color surfaceContainerHigh:    tone(surface, 0.09)
    readonly property color surfaceContainerHighest: tone(surface, 0.14)
    readonly property color surfaceVariant:          tone(surface, 0.05)
    readonly property color surfaceTint:             primary
    readonly property color inverseSurface:          onSurface
    readonly property color inverseOnSurface:        surface

    // Foreground: the wallpaper text colour, floored for legibility, plus a
    // muted variant mixed toward the surface for secondary text.
    readonly property color onSurface:        legible(adapter.foreground, surface, 4.5)
    readonly property color onSurfaceVariant: mix(onSurface, surface, 0.32)

    // Accent families: ANSI lead hues (color4 lead, color5 second, color6 third,
    // color1 the red channel for error), vivified and lifted to clear 3:1
    // against the surface so a wallpaper-matched accent never sinks into it.
    readonly property color primary:              legible(vivid(adapter.color4), surfaceContainer, 3.0)
    readonly property color onPrimary:            onColor(primary)
    readonly property color primaryContainer:     mix(surface, primary, 0.28)
    readonly property color onPrimaryContainer:   legible(primary, primaryContainer, 4.5)
    readonly property color secondary:            legible(vivid(adapter.color5), surfaceContainer, 3.0)
    readonly property color onSecondary:          onColor(secondary)
    readonly property color secondaryContainer:   mix(surface, secondary, 0.28)
    readonly property color onSecondaryContainer: legible(secondary, secondaryContainer, 4.5)
    readonly property color tertiary:             legible(vivid(adapter.color6), surfaceContainer, 3.0)
    readonly property color onTertiary:           onColor(tertiary)
    readonly property color tertiaryContainer:    mix(surface, tertiary, 0.28)
    readonly property color onTertiaryContainer:  legible(tertiary, tertiaryContainer, 4.5)
    readonly property color error:                legible(vivid(adapter.color1), surfaceContainer, 3.0)
    readonly property color onError:              onColor(error)
    readonly property color errorContainer:       mix(surface, error, 0.28)
    readonly property color onErrorContainer:     legible(error, errorContainer, 4.5)

    // Lines: neutral borders mixed between surface and text, a strong and a
    // subtle weight.
    readonly property color outline:        mix(surface, onSurface, 0.42)
    readonly property color outlineVariant: mix(surface, onSurface, 0.20)

    // Shadow and scrim are always near-black regardless of the wallpaper.
    readonly property color shadow: "#000000"
    readonly property color scrim:  "#000000"

    // Tone-map the wallpaper background into the shell's dark band, hue kept.
    // HSV value inside [0.08, 0.26] passes through; pure black lifts to a soft
    // near-black; brighter than the ceiling compresses hard (6% of the
    // overshoot) so neon and pastel wallpapers land just past the ceiling
    // instead of piling onto one flat tone. Saturation caps at 0.55 so a
    // saturated wallpaper reads as a deep tint, never neon.
    function shade(c) {
        var hue = c.hsvHue < 0 ? 0 : c.hsvHue;
        var s = Math.min(c.hsvSaturation, 0.55);
        var v = c.hsvValue;
        if (v < 0.08)      v = 0.08;
        else if (v > 0.26) v = 0.26 + (v - 0.26) * 0.06;
        return Qt.hsva(hue, s, v, 1);
    }

    // Shift a colour's HSV value by dv (hue and saturation kept), so a ramp from
    // the wallpaper background sits at predictable depths.
    function tone(c, dv) {
        var hue = c.hsvHue < 0 ? 0 : c.hsvHue;
        return Qt.hsva(hue, c.hsvSaturation, Math.max(0, Math.min(1, c.hsvValue + dv)), 1);
    }

    // Linear blend of two colours, t in [0,1] toward b, opaque result.
    function mix(a, b, t) {
        return Qt.rgba(a.r + (b.r - a.r) * t,
                       a.g + (b.g - a.g) * t,
                       a.b + (b.b - a.b) * t, 1);
    }

    // The legible on-colour for a fill: whichever of the dark surface or the
    // light text contrasts more with it.
    function onColor(c) {
        return contrast(c, surface) >= contrast(c, onSurface) ? surface : onSurface;
    }

    // Lift saturation and floor brightness so an accent reads as colour, not mud,
    // however desaturated the wallpaper is. Greys (no hue) are only brightened.
    function vivid(c) {
        var hue = c.hsvHue < 0 ? 0 : c.hsvHue;
        var sat = c.hsvSaturation < 0.06 ? 0 : Math.min(1, c.hsvSaturation * 1.2 + 0.06);
        return Qt.hsva(hue, sat, Math.max(c.hsvValue, 0.74), 1);
    }

    // WCAG relative luminance.
    function relLum(c) {
        function lin(u) { return u <= 0.04045 ? u / 12.92 : Math.pow((u + 0.055) / 1.055, 2.4); }
        return 0.2126 * lin(c.r) + 0.7152 * lin(c.g) + 0.0722 * lin(c.b);
    }

    // WCAG contrast ratio between two colors.
    function contrast(a, b) {
        var la = relLum(a), lb = relLum(b);
        return (Math.max(la, lb) + 0.05) / (Math.min(la, lb) + 0.05);
    }

    // Walk fg toward white in 18% steps (max 8) until it clears `target`
    // against bg. Colors that already pass return unchanged, so well-behaved
    // palettes and the Everforest defaults render exactly as before.
    function legible(fg, bg, target) {
        var r = fg.r, g = fg.g, b = fg.b;
        for (var i = 0; i < 8; i++) {
            var c = Qt.rgba(r, g, b, 1);
            if (contrast(c, bg) >= target) return c;
            r += (1 - r) * 0.18;
            g += (1 - g) * 0.18;
            b += (1 - b) * 0.18;
        }
        return Qt.rgba(r, g, b, 1);
    }

    FileView {
        id: file
        path: (Quickshell.env("XDG_CACHE_HOME") || (Quickshell.env("HOME") + "/.cache")) + "/wallust/colors.json"
        blockLoading: true
        watchChanges: true
        printErrors: false
        onFileChanged: reload()

        // Defaults are Everforest Dark so a wallpaper-matched shell reads
        // correctly before the first wallust run: background/foreground set the
        // surface and text, color4/5/6 the accent families, color1 the error red.
        JsonAdapter {
            id: adapter
            property color background: "#1E2326"
            property color foreground: "#D3C6AA"
            property color color1: "#E67E80"
            property color color4: "#A7C080"
            property color color5: "#7FBBB3"
            property color color6: "#83C092"
        }
    }
}
