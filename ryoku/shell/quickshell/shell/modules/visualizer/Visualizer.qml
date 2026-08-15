//@ pragma DefaultEnv QSG_RENDER_LOOP = threaded

import QtQuick
import Quickshell
import Quickshell.Wayland
import "Singletons"

// desktop audio visualiser module entry. click-through, palette-tinted cava
// spectrum across the bottom of one monitor. mode drives visibility and layer:
// "off" hides it, "desktop" draws on the wallpaper behind every window
// (WlrLayer.Bottom), "overlay" raises it over windows (WlrLayer.Top). the
// controller instantiates one per screen and binds `screen`/`mode`; cava only
// runs while enabled.
Item {
    id: root

    // monitor this instance draws on, supplied by the controller.
    property var screen

    // off | desktop | overlay. defaults from Config so a standalone instance
    // still honours the persisted enabled flag; the controller overrides it.
    property string mode: Config.enabled ? "desktop" : "off"

    // Placement: a polar look becomes draggable on the desktop, on its own
    // surface (Placer), and rides the top layer so it is not buried while aimed.
    property bool placing: false
    signal placingDone

    readonly property bool active: root.mode !== "off"
    readonly property bool placeable: root.placing && root.active && view.polar
    readonly property bool raised: root.mode === "overlay" || root.placeable

    // cava runs whenever the visualiser is enabled: gating on "audio playing"
    // needs a probe that is either broken or costs a periodic graph dump, while
    // cava is ~1% idle and the render already freezes on silence.
    Binding {
        target: Spectrum
        property: "active"
        value: root.active
    }

    // configured band count; changing it restarts cava with the new bars.
    Binding {
        target: Spectrum
        property: "bars"
        value: Config.bars
    }

    // cava's framerate follows the render ceiling: no point sampling faster than
    // the spectrum draws.
    Binding {
        target: Spectrum
        property: "fps"
        value: Config.fps
    }

    // the scope look draws the actual playback waveform; capture the monitor
    // only while that look is selected and the visualiser is on.
    Binding {
        target: Waveform
        property: "active"
        value: root.active && Config.styleId === "line"
    }

    PanelWindow {
        id: win

        screen: root.screen
        visible: root.active
        color: "transparent"

        // The curtain hangs off the bar, so its surface honours the bar's
        // exclusive zone and starts where the bar ends. Every other look owns
        // the whole screen and ignores reservations.
        exclusionMode: Config.styleId === "curtain" ? ExclusionMode.Normal : ExclusionMode.Ignore
        WlrLayershell.layer: root.raised ? WlrLayer.Top : WlrLayer.Bottom
        WlrLayershell.namespace: "ryoku-visualizer"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        // empty input region: every click falls through to windows above, so the
        // visualiser shares the desktop without ever intercepting it. Placement
        // runs on its own surface (Placer) rather than lifting this one, since a
        // surface masked click-through does not start taking a pointer again just
        // because the region is swapped.
        mask: emptyRegion
        Region { id: emptyRegion }

        anchors { top: true; left: true; right: true; bottom: true }

        VisualizerView {
            id: view
            anchors.fill: parent
        }
    }

    // The placement overlay only exists while a polar look is being aimed.
    Loader {
        active: root.placeable
        sourceComponent: Placer {
            screen: root.screen
            shapeRadius: view.shapeRadius
            guide: view.guide
            onDone: root.placingDone()
        }
    }
}
