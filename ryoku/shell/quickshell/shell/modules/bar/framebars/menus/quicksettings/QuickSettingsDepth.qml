pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Io
import shell.services
import "../../../../../components"
import ".." as Menus
import "../../../../depth/Singletons" as DepthCfg

// The Depth tab of the Super+Esc quick-settings panel: lift the wallpaper's
// subject in front of the widgets, tune it per image, and arrange the clock
// behind it. A live preview shows the detected subject and the generation
// progress; the controls read in plain language (no model ids, no "matting").
// Mirrors the other quick-settings modules (a Theme surface under a Flickable).
// See docs/depth.md.
Item {
    id: root

    property real s: 1
    property bool open: false
    property var navigate: null
    property var closePanel: null

    readonly property bool ready: DepthCfg.DepthBackend.available
    readonly property bool installing: DepthCfg.DepthBackend.installing
    readonly property bool hasFine: DepthCfg.DepthBackend.hasModel("birefnet-general-lite")

    // Live generation state + the current cutout, polled from the daemon while
    // the tab is open, so the preview and the progress bar reflect reality.
    property bool generating: false
    property string cutoutPath: ""
    property int previewRev: 0

    function compose() {
        DepthCfg.Config.setEnabled(true);
        const st = ShellState.forActive();
        if (st)
            st.depthComposing = true;
        if (root.closePanel)
            root.closePanel();
    }

    Timer {
        id: poll
        interval: 700
        repeat: true
        running: root.open
        triggeredOnStart: true
        onTriggered: statusProc.running = true
    }
    Process {
        id: statusProc
        command: ["ryoku-shell", "depth", "status"]
        stdout: StdioCollector {
            onStreamFinished: {
                let d = {};
                try {
                    d = JSON.parse(("" + this.text).trim() || "{}");
                } catch (e) {}
                const wasBusy = root.generating;
                root.generating = d.busy === true;
                const p = d.path || "";
                if (p !== root.cutoutPath) {
                    root.cutoutPath = p;
                    root.previewRev++;
                } else if (wasBusy && !root.generating) {
                    root.previewRev++;
                }
            }
        }
    }

    // Opaque backing so the incoming push covers the outgoing module cleanly.
    Rectangle {
        anchors.fill: parent
        color: Theme.surface
    }

    // ── a labelled segmented field: title, a plain-language hint, and the choices.
    component Field: Column {
        id: field
        property string title: ""
        property string hint: ""
        property var choices: []
        property string current: ""
        signal chose(string id)
        width: parent ? parent.width : 0
        spacing: 5
        Text {
            text: field.title
            color: Theme.onSurface
            font.family: Theme.fontPrimary
            font.pixelSize: Theme.fontSm
            font.weight: Font.DemiBold
        }
        Text {
            width: field.width
            visible: field.hint.length > 0
            text: field.hint
            wrapMode: Text.WordWrap
            color: Qt.rgba(Theme.onSurfaceVariant.r, Theme.onSurfaceVariant.g, Theme.onSurfaceVariant.b, 0.9)
            font.family: Theme.fontPrimary
            font.pixelSize: Theme.fontSm - 3
        }
        Menus.QsSeg {
            width: field.width
            options: field.choices
            current: field.current
            onChose: id => field.chose(id)
        }
    }

    // ── an action button: filled (primary), outlined, or ghost.
    component ActBtn: Rectangle {
        id: btn
        property string icon: ""
        property string label: ""
        property string kind: "outlined" // filled | outlined | ghost
        property bool primaryTint: false
        signal act()
        width: parent ? parent.width : 0
        height: 46
        radius: Theme.radiusWidget
        readonly property color tint: Theme.primary
        color: btn.kind === "filled" ? Qt.rgba(btn.tint.r, btn.tint.g, btn.tint.b, ma.containsMouse ? 0.30 : 0.22)
            : ma.containsMouse ? Qt.rgba(Theme.onSurface.r, Theme.onSurface.g, Theme.onSurface.b, 0.08) : "transparent"
        border.width: btn.kind === "ghost" ? 0 : 1
        border.color: btn.kind === "filled"
            ? Qt.rgba(btn.tint.r, btn.tint.g, btn.tint.b, 0.55)
            : Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.35)
        Behavior on color { ColorAnimation { duration: Motion.crossfade; easing.type: Motion.crossfadeCurve } }
        scale: ma.pressed ? 0.98 : 1
        Behavior on scale { NumberAnimation { duration: Motion.fast; easing.type: Easing.OutBack; easing.overshoot: 2 } }
        Row {
            anchors.centerIn: parent
            spacing: 8
            MaterialIcon {
                anchors.verticalCenter: parent.verticalCenter
                text: btn.icon
                font.pixelSize: 18
                fill: btn.kind === "filled" ? 1 : 0
                color: btn.kind === "filled" ? Theme.inkOn(root.blendTint(0.22), Theme.onSurface) : Theme.onSurface
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: btn.label
                color: Theme.onSurface
                font.family: Theme.fontPrimary
                font.pixelSize: Theme.fontSm
                font.weight: Font.DemiBold
            }
        }
        MouseArea {
            id: ma
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: btn.act()
        }
    }

    function blendTint(a) {
        return Theme.blend(Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, a), Theme.surface);
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
            spacing: 12

            // ── header: what this is, in one line.
            Column {
                width: parent.width
                spacing: 2
                Text {
                    text: qsTr("Depth")
                    color: Theme.onSurface
                    font.family: Theme.fontPrimary
                    font.pixelSize: Theme.fontLg
                    font.weight: Font.DemiBold
                }
                Text {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    text: qsTr("Lift your wallpaper's subject in front of the clock and widgets.")
                    color: Theme.onSurfaceVariant
                    font.family: Theme.fontPrimary
                    font.pixelSize: Theme.fontSm - 1
                }
            }

            // ── preview: the detected subject, and the live generation progress.
            Rectangle {
                id: preview
                width: parent.width
                height: 150
                radius: Theme.radiusWidget
                clip: true
                color: root.blendTint(0.04)
                border.width: 1
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.30)

                // faint checker so a transparent cutout reads as lifted, not empty.
                Image {
                    anchors.fill: parent
                    source: root.cutoutPath !== "" ? "file://" + root.cutoutPath : ""
                    cache: false
                    asynchronous: true
                    fillMode: Image.PreserveAspectFit
                    sourceSize.width: preview.width
                    sourceSize.height: preview.height
                    opacity: root.generating ? 0.35 : (status === Image.Ready ? 1 : 0)
                    Behavior on opacity { NumberAnimation { duration: Motion.crossfade } }
                    // previewRev busts the cache when the cutout is regenerated.
                    property int rev: root.previewRev
                    onRevChanged: { const s = source; source = ""; source = s; }
                }

                Text {
                    anchors.centerIn: parent
                    width: parent.width - 40
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    visible: root.cutoutPath === "" && !root.generating
                    text: root.ready ? qsTr("Turn Depth on to lift your subject.")
                                     : qsTr("Install the engine to detect your subject.")
                    color: Theme.onSurfaceVariant
                    font.family: Theme.fontPrimary
                    font.pixelSize: Theme.fontSm - 1
                }

                // generation progress: a label and an indeterminate sweep.
                Column {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.margins: 12
                    spacing: 6
                    visible: root.generating
                    Text {
                        text: qsTr("Cutting out the subject…")
                        color: Theme.onSurface
                        font.family: Theme.fontPrimary
                        font.pixelSize: Theme.fontSm - 1
                        font.weight: Font.DemiBold
                    }
                    Rectangle {
                        id: track
                        width: parent.width
                        height: 4
                        radius: 2
                        color: Qt.rgba(Theme.onSurface.r, Theme.onSurface.g, Theme.onSurface.b, 0.14)
                        Rectangle {
                            width: parent.width * 0.32
                            height: parent.height
                            radius: 2
                            color: Theme.primary
                            x: 0
                            SequentialAnimation on x {
                                running: root.generating
                                loops: Animation.Infinite
                                NumberAnimation { from: -track.width * 0.32; to: track.width; duration: 1100; easing.type: Easing.InOutQuad }
                            }
                        }
                    }
                }
            }

            // ── the master switch (or the engine install when it is missing).
            Menus.QsTile {
                width: parent.width
                visible: root.ready
                icon: "layers"
                label: qsTr("Depth effect")
                sub: DepthCfg.Config.enabled ? qsTr("On") : qsTr("Off")
                on: DepthCfg.Config.enabled
                onToggled: DepthCfg.Config.setEnabled(!DepthCfg.Config.enabled)
            }
            Menus.QsNavRow {
                width: parent.width
                visible: !root.ready
                icon: "download"
                label: root.installing ? qsTr("Installing engine…") : qsTr("Install engine")
                sub: root.installing ? DepthCfg.DepthBackend.progress
                                     : qsTr("A one-time on-device download to detect subjects.")
                onActivated: if (!root.installing)
                    DepthCfg.DepthBackend.install()
            }

            // ── quality: one plain control folding model + edge refinement.
            Menus.QsSection {
                width: parent.width
                visible: root.ready
                label: qsTr("Quality")
            }
            Field {
                visible: root.ready
                title: qsTr("Detail")
                hint: qsTr("Higher detail traces hair and fine edges, but takes longer to make.")
                choices: root.hasFine
                    ? [{ id: "draft", label: qsTr("Draft") }, { id: "standard", label: qsTr("Standard") }, { id: "fine", label: qsTr("Fine") }]
                    : [{ id: "draft", label: qsTr("Draft") }, { id: "standard", label: qsTr("Standard") }]
                current: DepthCfg.Config.qualityLevel()
                onChose: id => DepthCfg.Config.setQuality(id)
            }
            Menus.QsNavRow {
                width: parent.width
                visible: root.ready && !root.hasFine
                icon: "auto_awesome"
                label: root.installing ? qsTr("Fetching Fine detail…") : qsTr("Unlock Fine detail")
                sub: root.installing ? DepthCfg.DepthBackend.progress
                                     : qsTr("The cleanest edges (~224 MB).")
                onActivated: if (!root.installing)
                    DepthCfg.DepthBackend.install("birefnet-general-lite")
            }

            // ── look: live, no regeneration.
            Menus.QsSection {
                width: parent.width
                visible: root.ready
                label: qsTr("Look")
            }
            Field {
                visible: root.ready
                title: qsTr("Edge fade")
                hint: qsTr("Soften where the cut-out meets the scene.")
                choices: [{ id: "none", label: qsTr("None") }, { id: "soft", label: qsTr("Soft") }, { id: "strong", label: qsTr("Strong") }]
                current: DepthCfg.Config.feather < 0.05 ? "none" : DepthCfg.Config.feather < 0.35 ? "soft" : "strong"
                onChose: id => DepthCfg.Config.setFeather(id === "none" ? 0 : id === "soft" ? 0.15 : 0.45)
            }
            Field {
                visible: root.ready
                title: qsTr("Strength")
                hint: qsTr("How much the subject stands out in front.")
                choices: [{ id: "subtle", label: qsTr("Subtle") }, { id: "medium", label: qsTr("Medium") }, { id: "full", label: qsTr("Full") }]
                current: DepthCfg.Config.lift <= 0.5 ? "subtle" : DepthCfg.Config.lift < 0.9 ? "medium" : "full"
                onChose: id => DepthCfg.Config.setLift(id === "subtle" ? 0.4 : id === "medium" ? 0.7 : 1.0)
            }
            Field {
                visible: root.ready
                title: qsTr("Shadow")
                hint: qsTr("A soft shadow behind the subject, for more depth.")
                choices: [{ id: "none", label: qsTr("None") }, { id: "soft", label: qsTr("Soft") }, { id: "strong", label: qsTr("Strong") }]
                current: DepthCfg.Config.shadow < 0.05 ? "none" : DepthCfg.Config.shadow < 0.6 ? "soft" : "strong"
                onChose: id => DepthCfg.Config.setShadow(id === "none" ? 0 : id === "soft" ? 0.45 : 0.85)
            }

            // ── arrange + actions.
            Menus.QsSection {
                width: parent.width
                visible: root.ready
                label: qsTr("Arrange")
            }
            ActBtn {
                visible: root.ready
                kind: "filled"
                icon: "open_with"
                label: qsTr("Place clock behind subject")
                onAct: root.compose()
            }
            ActBtn {
                visible: root.ready
                kind: "outlined"
                icon: "cached"
                label: qsTr("Redo the cut-out")
                onAct: DepthCfg.Config.refresh()
            }
            ActBtn {
                visible: root.ready
                kind: "ghost"
                icon: "folder_open"
                label: qsTr("Open cutouts folder")
                onAct: DepthCfg.DepthBackend.openFolder()
            }
        }
    }
}
