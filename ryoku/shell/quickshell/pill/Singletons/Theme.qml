pragma Singleton
import QtQuick
import Quickshell

/**
 * Shell-wide style tokens: 30 Material colour roles plus shadow/scrim, sizing,
 * and fonts. Every colour resolves through a three-layer fallback chain, highest
 * priority first:
 *
 *   named scheme  ->  live wallpaper  ->  compiled default
 *
 * - compiled default: the Solitude Dark base palette. What shows when no dynamic
 *   theme is active, and the value the shell ships with.
 * - live wallpaper: the Wallust singleton, active while Config.matchWallpaper is
 *   on; a wallpaper change retunes every role live.
 * - named scheme: one of the static presets. The full 30-role palettes are owned
 *   by the Go theme daemon (a role() lookup honours a `namedScheme` palette
 *   object the daemon assigns here); null while no preset is selected. This is
 *   the single extension point for the static-theme catalog.
 *
 * The Material "on" roles (onSurface, onPrimary, ...) are declared plain and
 * bound through Binding elements. QML parses an inline `onSurface: <expr>` as a
 * change-handler for the sibling `surface` property and silently drops the
 * binding, leaving the colour at transparent black; naming the property as a
 * string in a Binding sidesteps that grab.
 *
 * Sizing and fonts are compiled defaults; opacity takes its value from the
 * Config frameOpacity knob.
 */
Singleton {
    id: root

    // The live wallpaper palette is active only while Match wallpaper is on.
    readonly property bool matchWallpaper: Config.matchWallpaper

    // Extension point for the static theme catalog (the 57 presets). Their
    // 30-role palettes live in the Go theme daemon; it assigns a palette object
    // here when a preset is active. null = no preset (wallpaper or base palette
    // applies). Writable so the daemon can drive it.
    property var namedScheme: null

    // Resolve one colour role through the layer chain: a selected named scheme
    // wins, then the live wallpaper palette, then the compiled Solitude base.
    function role(key, base) {
        if (namedScheme && namedScheme[key] !== undefined)
            return namedScheme[key];
        if (matchWallpaper)
            return Wallust[key];
        return base;
    }

    // --- 30 Material colour roles (compiled defaults: Solitude Dark) ----------
    readonly property color surface:                 role("surface", "#101315")
    readonly property color surfaceVariant:          role("surfaceVariant", "#1a1d1f")
    readonly property color surfaceContainerLowest:  role("surfaceContainerLowest", "#101315")
    readonly property color surfaceContainerLow:     role("surfaceContainerLow", "#1a1d1f")
    readonly property color surfaceContainer:        role("surfaceContainer", "#2c2f32")
    readonly property color surfaceContainerHigh:    role("surfaceContainerHigh", "#3d4144")
    readonly property color surfaceContainerHighest: role("surfaceContainerHighest", "#4b4e55")
    readonly property color inverseSurface:          role("inverseSurface", "#cacccc")
    readonly property color inverseOnSurface:        role("inverseOnSurface", "#101315")
    readonly property color surfaceTint:             role("surfaceTint", "#798186")
    readonly property color primary:                 role("primary", "#798186")
    readonly property color primaryContainer:        role("primaryContainer", "#1a1d1f")
    readonly property color secondary:               role("secondary", "#a8adb0")
    readonly property color secondaryContainer:      role("secondaryContainer", "#1a1d1f")
    readonly property color tertiary:                role("tertiary", "#de6145")
    readonly property color tertiaryContainer:       role("tertiaryContainer", "#1a1d1f")
    readonly property color error:                   role("error", "#de6145")
    readonly property color errorContainer:          role("errorContainer", "#1a1d1f")
    readonly property color outline:                 role("outline", "#565d60")
    readonly property color outlineVariant:          role("outlineVariant", "#343d41")

    // The "on" roles (see the class note): declared plain, bound via Binding so
    // the QML signal-handler grammar does not swallow their bindings.
    property color onSurface
    property color onSurfaceVariant
    property color onPrimary
    property color onPrimaryContainer
    property color onSecondary
    property color onSecondaryContainer
    property color onTertiary
    property color onTertiaryContainer
    property color onError
    property color onErrorContainer
    Binding { target: root; property: "onSurface";            value: root.role("onSurface", "#cacccc") }
    Binding { target: root; property: "onSurfaceVariant";     value: root.role("onSurfaceVariant", "#a8adb0") }
    Binding { target: root; property: "onPrimary";            value: root.role("onPrimary", "#101315") }
    Binding { target: root; property: "onPrimaryContainer";   value: root.role("onPrimaryContainer", "#a8adb0") }
    Binding { target: root; property: "onSecondary";          value: root.role("onSecondary", "#101315") }
    Binding { target: root; property: "onSecondaryContainer"; value: root.role("onSecondaryContainer", "#a8adb0") }
    Binding { target: root; property: "onTertiary";           value: root.role("onTertiary", "#101315") }
    Binding { target: root; property: "onTertiaryContainer";  value: root.role("onTertiaryContainer", "#de6145") }
    Binding { target: root; property: "onError";              value: root.role("onError", "#101315") }
    Binding { target: root; property: "onErrorContainer";     value: root.role("onErrorContainer", "#de6145") }

    // shadow and scrim are Material roles Ryoku paints with; always near-black.
    readonly property color shadow: role("shadow", "#000000")
    readonly property color scrim:  role("scrim", "#000000")

    // --- derived accent variants (Ryoku hover/active/gradient tints) ----------
    // No Material role covers a lightened/muted accent, so these track primary.
    readonly property color vermLit:     Qt.lighter(primary, 1.22)
    readonly property color vermDim:      Qt.darker(primary, 1.4)
    readonly property color vermDimDeep:  Qt.darker(primary, 2.2)
    readonly property color threadBg:     Qt.rgba(primary.r, primary.g, primary.b, 0.13)

    // --- overlay tints (Ryoku selection/hover fills over the surface) ---------
    readonly property color frameBg:     Qt.rgba(primary.r, primary.g, primary.b, 0.10)
    readonly property color frameBorder: Qt.rgba(onSurface.r, onSurface.g, onSurface.b, 0.18)
    // A dim tone for out-of-scope elements, e.g. out-of-month calendar days.
    readonly property color ghost:       Qt.darker(onSurfaceVariant, 1.6)

    // --- flame identity (the RASHIN mark; a fixed Ryoku accent) ---------------
    readonly property color flameGlow: "#ff9e64"
    readonly property color flameCore: "#ffd2bf"

    // Hard offset for the brutalist drop shadow (opaque, no blur).
    readonly property int shadowOffset: 3

    // --- sizing (compiled defaults; frameOpacity is the Config knob) ----------
    readonly property int  radiusWidget: 8
    readonly property int  radiusWindow: 8
    readonly property int  borderWidth: 2
    readonly property int  paddingSm: 4
    readonly property int  paddingMd: 8
    readonly property int  paddingLg: 16
    readonly property int  iconSm: 16
    readonly property int  iconMd: 24
    readonly property int  iconLg: 32
    readonly property real windowOpacity: Config.frameOpacity

    // --- fonts ----------------------------------------------------------------
    // Primary is the shell UI face; empty resolves to the platform default sans,
    // matching the reference's inherited system font. secondary/tertiary are
    // override slots that inherit primary until a theme sets them.
    readonly property string fontPrimary:   ""
    readonly property string fontSecondary: fontPrimary
    readonly property string fontTertiary:  fontPrimary
    readonly property int fontSm: 14
    readonly property int fontMd: 16
    readonly property int fontLg: 18
    readonly property int fontXl: 26
    readonly property int fontXxl: 32
    readonly property int fontXxxl: 48
    // Ryoku-specific faces: a serif display, a monospace, and a CJK face.
    readonly property string display: "Fraunces"
    readonly property string mono:    "JetBrainsMono Nerd Font"
    readonly property string fontJp:  "Noto Sans CJK JP"

    // brand mark, user-overridable via ~/.config/ryoku/brand.json (Shell ->
    // Global). BrandMark renders `mark`, or `markSource` (an image) when set.
    readonly property string mark: Config.markText.length > 0 ? Config.markText : "\u529b"
    readonly property string markSource: Config.markImage
    readonly property bool markTint: Config.markTint

    /**
     * MPRIS trackArtists arrives as a JS array from some players and as a
     * plain string from others (Spotify); calling join on the string throws
     * and kills the whole binding. Handles both, falls back to trackArtist.
     */
    function joinArtists(artists, single) {
        if (artists && typeof artists.join === "function" && artists.length > 0)
            return artists.join(", ");
        if (artists && String(artists).length > 0)
            return String(artists);
        return single ? String(single) : "";
    }
}
