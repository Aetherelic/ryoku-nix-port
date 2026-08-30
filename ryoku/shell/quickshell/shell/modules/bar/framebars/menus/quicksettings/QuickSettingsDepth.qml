pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Io
import shell.services
import "../../../../../components"
import ".." as Menus
import "../../../../depth/Singletons" as DepthCfg

// Depth tab of the Super+Esc quick-settings panel. Detail is staged and applied
// only on a deliberate Recut because the cut is expensive; while one runs the
// tunables lock and the preview shows progress. See docs/depth.md.
Item {
    id: root

    property real s: 1
    property bool open: false
    property var navigate: null
    property var closePanel: null

    readonly property bool checked: DepthCfg.DepthBackend.checked
    readonly property bool ready: DepthCfg.DepthBackend.available
    readonly property bool installing: DepthCfg.DepthBackend.installing
    readonly property bool hasFine: DepthCfg.DepthBackend.hasModel("birefnet-general-lite")

    // Busy is held for a beat after a recut (minBusy) so the lock engages
    // instantly and never flickers between poll ticks. busyStuck releases the
    // lock if a cut never reports done, so controls can't stick forever.
    property bool statusBusy: false
    property bool busyStuck: false
    readonly property bool generating: (root.statusBusy && !root.busyStuck) || minBusy.running
    property string cutoutPath: ""
    property int previewRev: 0

    // Staged detail; applied only on Recut. Kept synced with the applied value.
    property string draftDetail: DepthCfg.Config.qualityLevel()
    readonly property bool detailDirty: root.draftDetail !== DepthCfg.Config.qualityLevel()
    Connections {
        target: DepthCfg.Config
        function onModelChanged() { if (!root.generating) root.draftDetail = DepthCfg.Config.qualityLevel(); }
        function onAlphaMattingChanged() { if (!root.generating) root.draftDetail = DepthCfg.Config.qualityLevel(); }
    }
    onOpenChanged: if (root.open) root.draftDetail = DepthCfg.Config.qualityLevel()

    Timer { id: minBusy; interval: 900 }

    // Belt-and-suspenders: give up the lock if a cut never reports done, while
    // the poll keeps running so a real completion still lands.
    Timer {
        id: stuckGuard
        interval: 50000
        running: root.statusBusy && !root.busyStuck
        onTriggered: root.busyStuck = true
    }

    function recut() {
        minBusy.restart();
        root.busyStuck = false;
        root.statusBusy = true;
        DepthCfg.Config.setQuality(root.draftDetail);
        poll.restart();
    }
    function editWidgets() {
        const st = ShellState.forActive();
        if (st)
            st.depthComposing = true;
        if (root.closePanel)
            root.closePanel();
    }

    Timer {
        id: poll
        interval: 500
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
                const wasBusy = root.statusBusy;
                root.statusBusy = d.busy === true;
                if (!root.statusBusy)
                    root.busyStuck = false;
                const p = d.path || "";
                if (p !== root.cutoutPath) {
                    root.cutoutPath = p;
                    root.previewRev++;
                } else if (wasBusy && !root.statusBusy) {
                    root.previewRev++;
                }
            }
        }
    }

    function blendTint(a) {
        return Theme.blend(Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, a), Theme.surface);
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.surface
    }

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

    component ActBtn: Rectangle {
        id: btn
        property string icon: ""
        property string label: ""
        property string kind: "outlined" // filled | outlined | ghost
        property bool enabledAct: true
        signal act()
        width: parent ? parent.width : 0
        height: 46
        radius: Theme.radiusWidget
        opacity: btn.enabledAct ? 1 : 0.4
        readonly property color tint: Theme.primary
        color: btn.kind === "filled" ? Qt.rgba(btn.tint.r, btn.tint.g, btn.tint.b, ma.containsMouse && btn.enabledAct ? 0.30 : 0.22)
            : (ma.containsMouse && btn.enabledAct) ? Qt.rgba(Theme.onSurface.r, Theme.onSurface.g, Theme.onSurface.b, 0.08) : "transparent"
        border.width: btn.kind === "ghost" ? 0 : 1
        border.color: btn.kind === "filled"
            ? Qt.rgba(btn.tint.r, btn.tint.g, btn.tint.b, 0.55)
            : Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.35)
        Behavior on color { ColorAnimation { duration: Motion.crossfade; easing.type: Motion.crossfadeCurve } }
        Behavior on opacity { NumberAnimation { duration: Motion.crossfade } }
        scale: ma.pressed && btn.enabledAct ? 0.98 : 1
        Behavior on scale { NumberAnimation { duration: Motion.fast; easing.type: Easing.OutBack; easing.overshoot: 2 } }
        Row {
            anchors.centerIn: parent
            spacing: 8
            MaterialIcon {
                anchors.verticalCenter: parent.verticalCenter
                text: btn.icon
                font.pixelSize: 18
                fill: btn.kind === "filled" ? 1 : 0
                color: Theme.onSurface
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
            cursorShape: btn.enabledAct ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: if (btn.enabledAct) btn.act()
        }
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

            // Live preview of the detected subject, with generation progress.
            Rectangle {
                id: preview
                width: parent.width
                height: 150
                radius: Theme.radiusWidget
                clip: true
                color: root.blendTint(0.04)
                border.width: 1
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.30)

                Image {
                    anchors.fill: parent
                    anchors.margins: 6
                    // #previewRev busts the Image cache on a regenerated cutout;
                    // the wallpaper path change reloads on its own.
                    source: root.cutoutPath !== "" ? "file://" + root.cutoutPath + "#" + root.previewRev : ""
                    cache: false
                    asynchronous: true
                    fillMode: Image.PreserveAspectFit
                    sourceSize.width: preview.width
                    sourceSize.height: preview.height
                    opacity: root.generating ? 0.3 : (status === Image.Ready ? 1 : 0)
                    Behavior on opacity { NumberAnimation { duration: Motion.crossfade } }
                }

                Text {
                    anchors.centerIn: parent
                    width: parent.width - 40
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    visible: root.checked && root.cutoutPath === "" && !root.generating
                    text: root.ready ? qsTr("Turn Depth on to lift your subject.")
                                     : qsTr("Install the engine to detect your subject.")
                    color: Theme.onSurfaceVariant
                    font.family: Theme.fontPrimary
                    font.pixelSize: Theme.fontSm - 1
                }

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

            // Engine not resolved yet: a placeholder, never the install flash.
            Text {
                width: parent.width
                visible: !root.checked
                text: qsTr("Preparing…")
                color: Theme.onSurfaceVariant
                font.family: Theme.fontPrimary
                font.pixelSize: Theme.fontSm - 1
            }

            // Engine missing: one-time opt-in install.
            Menus.QsNavRow {
                width: parent.width
                visible: root.checked && !root.ready
                icon: "download"
                label: root.installing ? qsTr("Installing engine…") : qsTr("Install engine")
                sub: root.installing ? DepthCfg.DepthBackend.progress
                                     : qsTr("A one-time on-device download to detect subjects.")
                onActivated: if (!root.installing)
                    DepthCfg.DepthBackend.install()
            }

            Menus.QsTile {
                width: parent.width
                visible: root.checked && root.ready
                icon: "layers"
                label: qsTr("Depth effect")
                sub: DepthCfg.Config.enabled ? qsTr("On") : qsTr("Off")
                on: DepthCfg.Config.enabled
                onToggled: DepthCfg.Config.setEnabled(!DepthCfg.Config.enabled)
            }

            // Tunables lock while a cut runs (no click-through).
            Item {
                width: parent.width
                visible: root.checked && root.ready
                implicitHeight: tune.implicitHeight
                enabled: !root.generating
                opacity: root.generating ? 0.45 : 1
                Behavior on opacity { NumberAnimation { duration: Motion.crossfade } }

                Column {
                    id: tune
                    width: parent.width
                    spacing: 12

                    Menus.QsSection { width: parent.width; label: qsTr("Quality") }
                    Field {
                        title: qsTr("Detail")
                        hint: qsTr("Higher detail traces hair and fine edges, but the cut takes longer.")
                        choices: root.hasFine
                            ? [{ id: "draft", label: qsTr("Draft") }, { id: "standard", label: qsTr("Standard") }, { id: "fine", label: qsTr("Fine") }]
                            : [{ id: "draft", label: qsTr("Draft") }, { id: "standard", label: qsTr("Standard") }]
                        current: root.draftDetail
                        onChose: id => root.draftDetail = id
                    }
                    // Recut only appears once a new Detail is staged; it fades and
                    // collapses to nothing otherwise, so there is no leftover gap.
                    ActBtn {
                        id: recutBtn
                        readonly property bool shown: root.detailDirty && !root.generating
                        kind: "filled"
                        icon: "auto_fix_high"
                        label: qsTr("Recut the subject")
                        enabledAct: recutBtn.shown
                        clip: true
                        visible: recutBtn.height > 0
                        height: recutBtn.shown ? 46 : 0
                        opacity: recutBtn.shown ? 1 : 0
                        onAct: root.recut()
                        Behavior on height { NumberAnimation { duration: Motion.crossfade; easing.type: Motion.crossfadeCurve } }
                    }
                    Menus.QsNavRow {
                        width: parent.width
                        visible: !root.hasFine
                        icon: "hd"
                        label: root.installing ? qsTr("Fetching Fine detail…") : qsTr("Unlock Fine detail")
                        sub: root.installing ? DepthCfg.DepthBackend.progress
                                             : qsTr("The cleanest edges (~224 MB).")
                        onActivated: if (!root.installing)
                            DepthCfg.DepthBackend.install("birefnet-general-lite")
                    }

                    Menus.QsSection { width: parent.width; label: qsTr("Look") }
                    Field {
                        title: qsTr("Edge fade")
                        hint: qsTr("Soften where the cut-out meets the scene.")
                        choices: [{ id: "none", label: qsTr("None") }, { id: "soft", label: qsTr("Soft") }, { id: "strong", label: qsTr("Strong") }]
                        current: DepthCfg.Config.feather < 0.05 ? "none" : DepthCfg.Config.feather < 0.35 ? "soft" : "strong"
                        onChose: id => DepthCfg.Config.setFeather(id === "none" ? 0 : id === "soft" ? 0.15 : 0.45)
                    }
                    Field {
                        title: qsTr("Strength")
                        hint: qsTr("How much the subject stands out in front.")
                        choices: [{ id: "subtle", label: qsTr("Subtle") }, { id: "medium", label: qsTr("Medium") }, { id: "full", label: qsTr("Full") }]
                        current: DepthCfg.Config.lift <= 0.5 ? "subtle" : DepthCfg.Config.lift < 0.9 ? "medium" : "full"
                        onChose: id => DepthCfg.Config.setLift(id === "subtle" ? 0.4 : id === "medium" ? 0.7 : 1.0)
                    }
                    Field {
                        title: qsTr("Shadow")
                        hint: qsTr("A soft shadow behind the subject, for more depth.")
                        choices: [{ id: "none", label: qsTr("None") }, { id: "soft", label: qsTr("Soft") }, { id: "strong", label: qsTr("Strong") }]
                        current: DepthCfg.Config.shadow < 0.05 ? "none" : DepthCfg.Config.shadow < 0.6 ? "soft" : "strong"
                        onChose: id => DepthCfg.Config.setShadow(id === "none" ? 0 : id === "soft" ? 0.45 : 0.85)
                    }

                    Menus.QsSection { width: parent.width; label: qsTr("Arrange") }
                    ActBtn {
                        kind: "filled"
                        icon: "open_with"
                        label: qsTr("Edit widgets")
                        onAct: root.editWidgets()
                    }
                    ActBtn {
                        kind: "ghost"
                        icon: "folder_open"
                        label: qsTr("Open cutouts folder")
                        onAct: DepthCfg.DepthBackend.openFolder()
                    }
                }
            }
        }
    }
}
