pragma Singleton
import QtQuick
import Quickshell

/**
 * Shell-wide style tokens: 30 Material colour roles plus shadow/scrim, sizing,
 * and fonts. Every colour resolves through a four-layer fallback chain, highest
 * priority first:
 *
 *   named scheme  ->  live wallpaper  ->  compiled default
 *   (surface also honours a user override; see below)
 *
 * - compiled default: the Everforest Dark base palette. What shows when no
 *   dynamic theme is active.
 * - live wallpaper: the Wallust singleton, active while Config.matchWallpaper is
 *   on; a wallpaper change retunes every role live.
 * - named scheme: one of the static presets. The full 30-role palettes are owned
 *   by the Go theme daemon (a role() lookup honours a `namedScheme` palette
 *   object the daemon assigns here); null while no preset is selected. This is
 *   the single extension point for the static-theme catalog.
 * - user override: Config.surfaceColor is the one per-token colour knob Ryoku
 *   ships and doubles as the base surface. There is no cascading style engine,
 *   so only token-level overrides map, not arbitrary per-widget rules.
 *
 * Sizing, opacity, and the primary font take their override from the Config
 * attribute knobs (roundness, frameOpacity, fontFamily) and fall back to the
 * compiled defaults.
 */
Singleton {
    id: root

    // Whether a Ryoku-frame style is selected; drives the frame-chrome tokens.
    readonly property bool ryokuFrame: Config.normalizedFrameBars.style === "ryoku-frame"

    // The live wallpaper palette is active only while Match wallpaper is on.
    readonly property bool matchWallpaper: Config.matchWallpaper

    // Extension point for the static theme catalog (the 57 presets). Their
    // 30-role palettes live in the Go theme daemon; it assigns a palette object
    // here when a preset is active. null = no preset (wallpaper or base palette
    // applies). Writable so the daemon can drive it.
    property var namedScheme: null

    // Resolve one colour role through the layer chain: a selected named scheme
    // wins, then the live wallpaper palette, then the compiled Everforest base.
    function role(key, base) {
        if (namedScheme && namedScheme[key] !== undefined)
            return namedScheme[key];
        if (matchWallpaper)
            return Wallust[key];
        return base;
    }

    // --- 30 Material colour roles (compiled defaults: Everforest Dark) --------
    // surface additionally honours the Config.surfaceColor user override, which
    // defaults to the compiled surface value.
    readonly property color surface:                 namedScheme && namedScheme.surface !== undefined ? namedScheme.surface : (matchWallpaper ? Wallust.surface : Config.surfaceColor)
    readonly property color onSurface:               role("onSurface", "#D3C6AA")
    readonly property color surfaceVariant:          role("surfaceVariant", "#2E383C")
    readonly property color onSurfaceVariant:        role("onSurfaceVariant", "#9DA9A0")
    readonly property color surfaceContainerLowest:  role("surfaceContainerLowest", "#1E2326")
    readonly property color surfaceContainerLow:     role("surfaceContainerLow", "#272E33")
    readonly property color surfaceContainer:        role("surfaceContainer", "#2E383C")
    readonly property color surfaceContainerHigh:    role("surfaceContainerHigh", "#374145")
    readonly property color surfaceContainerHighest: role("surfaceContainerHighest", "#414B50")
    readonly property color inverseSurface:          role("inverseSurface", "#D3C6AA")
    readonly property color inverseOnSurface:        role("inverseOnSurface", "#1E2326")
    readonly property color surfaceTint:             role("surfaceTint", "#7FBBB3")
    readonly property color primary:                 role("primary", "#A7C080")
    readonly property color onPrimary:               role("onPrimary", "#1E2326")
    readonly property color primaryContainer:        role("primaryContainer", "#3C4841")
    readonly property color onPrimaryContainer:      role("onPrimaryContainer", "#A7C080")
    readonly property color secondary:               role("secondary", "#7FBBB3")
    readonly property color onSecondary:             role("onSecondary", "#1E2326")
    readonly property color secondaryContainer:      role("secondaryContainer", "#384B55")
    readonly property color onSecondaryContainer:    role("onSecondaryContainer", "#7FBBB3")
    readonly property color tertiary:                role("tertiary", "#83C092")
    readonly property color onTertiary:              role("onTertiary", "#1E2326")
    readonly property color tertiaryContainer:       role("tertiaryContainer", "#3C4841")
    readonly property color onTertiaryContainer:     role("onTertiaryContainer", "#83C092")
    readonly property color error:                   role("error", "#E67E80")
    readonly property color onError:                 role("onError", "#1E2326")
    readonly property color errorContainer:          role("errorContainer", "#493B40")
    readonly property color onErrorContainer:        role("onErrorContainer", "#E67E80")
    readonly property color outline:                 role("outline", "#7A8478")
    readonly property color outlineVariant:          role("outlineVariant", "#374145")

    // shadow and scrim are Material roles Ryoku paints with; always near-black.
    readonly property color shadow: role("shadow", "#000000")
    readonly property color scrim:  role("scrim", "#000000")

    // --- frame chrome (Ryoku blob frame; no Material equivalent) --------------
    // The rail surface sinks a touch on the legacy per-edge frame so the bars
    // read as recessed; on the Ryoku frame it sits flush with the surface.
    readonly property color frameRailSurface:      ryokuFrame ? surface : Qt.darker(surface, 1.18)
    readonly property color frameRailOutline:      ryokuFrame ? outline : Qt.lighter(outline, 1.2)
    readonly property real  frameRailOutlineWidth: ryokuFrame ? 1.5 : 1
    readonly property real  frameClockScale:       ryokuFrame ? 1 : 0.88

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

    // --- sizing (compiled defaults; roundness/opacity are the Config knobs) ---
    readonly property int  radiusWidget: Math.round(Config.roundness)
    readonly property int  radiusWindow: Math.round(Config.roundness)
    readonly property int  borderWidth: 2
    readonly property int  paddingSm: 4
    readonly property int  paddingMd: 8
    readonly property int  paddingLg: 16
    readonly property int  iconSm: 16
    readonly property int  iconMd: 24
    readonly property int  iconLg: 32
    readonly property real windowOpacity: Config.frameOpacity

    // --- fonts ----------------------------------------------------------------
    // Primary is the shell UI face (Config override); secondary/tertiary are
    // override slots that inherit primary until a theme sets them.
    readonly property string fontPrimary:   Config.fontFamily.length > 0 ? Config.fontFamily : "Space Grotesk"
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
