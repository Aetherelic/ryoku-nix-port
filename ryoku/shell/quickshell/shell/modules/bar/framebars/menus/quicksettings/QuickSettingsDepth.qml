pragma ComponentBehavior: Bound

import QtQuick
import ".." as Menus
import shell.services
import "../../../../depth/Singletons" as DepthCfg

// The Depth tab of the Super+Esc quick-settings panel: turn the wallpaper-subject
// cutout on, provision the engine, tune the cut quality per image (model + edge
// refinement), and open compose to arrange the clock behind the subject. Mirrors
// the other quick-settings modules (a Theme surface under a Flickable). The knobs
// match docs/depth.md; live look tuning (feather, foreground) also rides here as
// presets, with fine control in the compose bar on the wallpaper.
Item {
    id: root

    property real s: 1
    property bool open: false
    property var navigate: null
    property var closePanel: null

    readonly property bool ready: DepthCfg.DepthBackend.available
    readonly property bool busy: DepthCfg.DepthBackend.installing
    readonly property bool hasQuality: DepthCfg.DepthBackend.hasModel("birefnet-general-lite")

    // Feather/foreground are continuous in the compose bar; here they step through
    // honest presets so the tab keeps the quick-settings idiom.
    function featherName(v) {
        return v < 0.05 ? "None" : v < 0.25 ? "Soft" : v < 0.45 ? "Medium" : "Strong";
    }
    function featherVal(n) {
        return n === "None" ? 0 : n === "Soft" ? 0.15 : n === "Medium" ? 0.35 : 0.6;
    }
    function liftName(v) {
        return v <= 0.5 ? "Subtle" : v < 0.9 ? "Medium" : "Full";
    }
    function liftVal(n) {
        return n === "Subtle" ? 0.4 : n === "Medium" ? 0.7 : 1.0;
    }

    function compose() {
        DepthCfg.Config.setEnabled(true);
        const st = ShellState.forActive();
        if (st)
            st.depthComposing = true;
        if (root.closePanel)
            root.closePanel();
    }

    // Opaque backing so the incoming push covers the outgoing module cleanly.
    Rectangle {
        anchors.fill: parent
        color: Theme.surface
    }

    Flickable {
        anchors.fill: parent
        anchors.margins: 12
        contentWidth: width
        contentHeight: col.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height

        Column {
            id: col
            width: parent.width
            spacing: 10

            Menus.QsSection {
                width: parent.width
                label: qsTr("Depth")
            }

            Grid {
                id: tiles
                width: parent.width
                columns: 2
                columnSpacing: 8
                rowSpacing: 8
                readonly property real tileW: (width - columnSpacing) / 2

                Menus.QsTile {
                    width: tiles.tileW
                    icon: "layers"
                    label: qsTr("Depth effect")
                    sub: !root.ready ? qsTr("Install first") : DepthCfg.Config.enabled ? qsTr("On") : qsTr("Off")
                    on: DepthCfg.Config.enabled
                    available: root.ready
                    onToggled: DepthCfg.Config.setEnabled(!DepthCfg.Config.enabled)
                }
                Menus.QsTile {
                    width: tiles.tileW
                    visible: root.ready
                    icon: "auto_fix_high"
                    label: qsTr("Edge refine")
                    sub: DepthCfg.Config.alphaMatting ? qsTr("On") : qsTr("Off")
                    on: DepthCfg.Config.alphaMatting
                    onToggled: DepthCfg.Config.setAlphaMatting(!DepthCfg.Config.alphaMatting)
                }
            }

            // Opt-in runtime: a one-time model download, never automatic.
            Menus.QsNavRow {
                width: parent.width
                visible: !root.ready
                icon: "download"
                label: root.busy ? qsTr("Installing engine") : qsTr("Install engine")
                sub: root.busy ? DepthCfg.DepthBackend.progress : qsTr("A small on-device model, downloaded once.")
                onActivated: if (!root.busy)
                    DepthCfg.DepthBackend.install()
            }

            Menus.QsSection {
                width: parent.width
                visible: root.ready
                label: qsTr("Cutout")
            }
            Menus.QsSeg {
                width: parent.width
                visible: root.ready && DepthCfg.DepthBackend.models.length > 1
                options: [
                    { id: "u2netp", label: qsTr("Fast") },
                    { id: "birefnet-general-lite", label: qsTr("Quality") }
                ]
                current: DepthCfg.Config.model
                onChose: id => DepthCfg.Config.setModel(id)
            }
            Menus.QsNavRow {
                width: parent.width
                visible: root.ready && !root.hasQuality
                icon: "hd"
                label: root.busy ? qsTr("Fetching quality model") : qsTr("Higher quality")
                sub: root.busy ? DepthCfg.DepthBackend.progress : qsTr("Larger model (~224 MB), cleaner edges.")
                onActivated: if (!root.busy)
                    DepthCfg.DepthBackend.install("birefnet-general-lite")
            }

            Menus.QsSection {
                width: parent.width
                visible: root.ready
                label: qsTr("Look")
            }
            Menus.QsSeg {
                width: parent.width
                visible: root.ready
                options: [
                    { id: "None", label: qsTr("None") },
                    { id: "Soft", label: qsTr("Soft") },
                    { id: "Medium", label: qsTr("Medium") },
                    { id: "Strong", label: qsTr("Strong") }
                ]
                current: root.featherName(DepthCfg.Config.feather)
                onChose: id => DepthCfg.Config.setFeather(root.featherVal(id))
            }
            Menus.QsSeg {
                width: parent.width
                visible: root.ready
                options: [
                    { id: "Subtle", label: qsTr("Subtle") },
                    { id: "Medium", label: qsTr("Medium") },
                    { id: "Full", label: qsTr("Full") }
                ]
                current: root.liftName(DepthCfg.Config.lift)
                onChose: id => DepthCfg.Config.setLift(root.liftVal(id))
            }

            Menus.QsNavRow {
                width: parent.width
                visible: root.ready
                icon: "tune"
                label: qsTr("Compose")
                sub: qsTr("Slide the clock behind the subject.")
                onActivated: root.compose()
            }
            Menus.QsNavRow {
                width: parent.width
                visible: root.ready
                icon: "refresh"
                label: qsTr("Regenerate")
                sub: qsTr("Re-cut the current wallpaper.")
                onActivated: DepthCfg.Config.refresh()
            }
            Menus.QsNavRow {
                width: parent.width
                visible: root.ready
                icon: "folder_open"
                label: qsTr("Saved cutouts")
                sub: qsTr("Kept in Pictures/Depth, one per wallpaper.")
                onActivated: DepthCfg.DepthBackend.openFolder()
            }
        }
    }
}
