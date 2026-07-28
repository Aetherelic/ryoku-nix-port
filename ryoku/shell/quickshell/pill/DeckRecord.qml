pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Ryoku.Ui.Singletons as Ui
import "Singletons"

/**
 * record zone of the 力 deck = capture control + the recordings list under one
 * roof. running state shows a pulsing REC tag, elapsed clock and pause/stop;
 * idle shows a Record button that opens the floating recording island in its
 * pre-record chooser (capture mode + audio toggles, then Quick / Studio / Edit).
 * the recordings list sits directly below, so the whole "record" concern is one
 * group instead of two. requestClose() dismisses the deck before the island opens
 * (and before any capture) so the panel is never in the frame. the deck renders
 * the "Record" eyebrow + count above us; `recCount` is published up for it.
 */
Item {
    id: root

    property real s: 1
    property bool active: true
    signal requestClose()

    readonly property alias recCount: recModel.count

    implicitHeight: content.implicitHeight

    // one resolution, shared with ryoku-cmd-screenrecord and the Hub's Recording
    // page. hardcoding $HOME/Videos/Recordings here made the list miss every
    // recording on a box with a custom XDG_VIDEOS_DIR.
    readonly property string recDir: Ui.Paths.recordingsDir

    // ── recordings model ──────────────────────────────────────────────────
    ListModel { id: recModel }

    function refreshRecs() {
        recProc.running = true;
    }

    Process {
        id: recProc
        // any video in the one directory, not just our own naming: Ryoku Motion
        // records and exports here too, and its clips are recordings like any
        // other. its .session.json / .cursor.json sidecars do not match.
        command: ["sh", "-c", "find \"$1\" -maxdepth 1 -type f \\( -iname '*.mp4' -o -iname '*.webm' -o -iname '*.mkv' \\) -printf '%T@\\t%s\\t%p\\n' 2>/dev/null | sort -rn", "_", root.recDir]
        stdout: StdioCollector {
            onStreamFinished: {
                recModel.clear();
                var lines = this.text.split("\n");
                for (var i = 0; i < lines.length; i++) {
                    var ln = lines[i];
                    if (!ln.length)
                        continue;
                    var parts = ln.split("\t");
                    if (parts.length < 3)
                        continue;
                    var path = parts[2];
                    var base = path.substring(path.lastIndexOf("/") + 1).replace(/\.mp4$/, "");
                    recModel.append({ path: path, label: root.prettyName(base), size: root.humanSize(parseInt(parts[1], 10)) });
                }
            }
        }
    }

    function prettyName(base) {
        var m = base.match(/^recording_(\d{4})-(\d{2})-(\d{2})_(\d{2})\.(\d{2})\.(\d{2})/);
        if (!m)
            return base;
        var d = new Date(m[1], m[2] - 1, m[3], m[4], m[5], m[6]);
        return Qt.formatDateTime(d, "MMM d, HH:mm");
    }

    function humanSize(bytes) {
        if (!bytes || bytes < 1024)
            return (bytes || 0) + " B";
        var kb = bytes / 1024;
        if (kb < 1024)
            return Math.round(kb) + " KB";
        var mb = kb / 1024;
        if (mb < 1024)
            return mb.toFixed(mb < 10 ? 1 : 0) + " MB";
        return (mb / 1024).toFixed(1) + " GB";
    }

    onActiveChanged: if (active) refreshRecs()

    // refresh the list a hair after a recording ends so the new file shows up.
    Connections {
        target: Recorder
        function onActiveChanged() {
            if (root.active && !Recorder.active)
                recRefresh.restart();
        }
    }
    Timer {
        id: recRefresh
        interval: 1500
        onTriggered: if (root.active) root.refreshRecs()
    }

    // flat icon button (play / folder / trash / pause / stop). tints carry
    // semantics: vermilion = destructive, cream = neutral, iconDim = rest.
    component IconBtn: Rectangle {
        property string glyph: ""
        property color tint: Theme.onSurfaceVariant
        property real box: 26
        signal clicked()
        width: box * root.s
        height: box * root.s
        color: hov.hovered ? Theme.frameBg : "transparent"
        Behavior on color { ColorAnimation { duration: Motion.fast } }
        GlyphIcon {
            anchors.centerIn: parent
            width: parent.box * 0.5 * root.s
            height: parent.box * 0.5 * root.s
            name: parent.glyph
            color: parent.tint
            stroke: 1.6
        }
        HoverHandler { id: hov; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: parent.clicked() }
    }

    Column {
        id: content
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 8 * root.s

        // running controls = pulsing vermilion REC tag, elapsed time in
        // tabular figures, pause + stop on the right.
        Item {
            width: parent.width
            visible: Recorder.active
            height: 30 * root.s

            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 9 * root.s

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: recPillText.implicitWidth + 14 * root.s
                    height: 20 * root.s
                    color: Recorder.paused ? Theme.onSurfaceVariant : Theme.primary
                    opacity: Recorder.paused ? 1 : Recorder.pulse
                    Text {
                        id: recPillText
                        anchors.centerIn: parent
                        text: Recorder.paused ? "PAUSED" : "REC"
                        color: Theme.onSurface
                        font.family: Theme.mono
                        font.pixelSize: 9.5 * root.s
                        font.weight: Font.Bold
                        font.letterSpacing: 1.2 * root.s
                    }
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Recorder.elapsedText
                    color: Theme.onSurface
                    font.family: Theme.fontPrimary
                    font.pixelSize: 13 * root.s
                    font.features: { "tnum": 1 }
                }
            }

            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 0
                IconBtn {
                    visible: Recorder.canPause
                    glyph: Recorder.paused ? "play" : "pause"
                    tint: Theme.onSurface
                    onClicked: Recorder.togglePause()
                }
                IconBtn {
                    glyph: "stop"
                    tint: Theme.vermLit
                    onClicked: Recorder.stop()
                }
            }
        }

        // idle Record button: flat tile that opens the recording island.
        Rectangle {
            id: recBtn
            width: parent.width
            visible: !Recorder.active
            height: 32 * root.s
            color: recBtnHov.hovered ? Theme.frameBg : Theme.surfaceContainerHigh
            border.width: 1
            border.color: Theme.outline
            Behavior on color { ColorAnimation { duration: Motion.fast } }

            Row {
                anchors.centerIn: parent
                spacing: 8 * root.s
                GlyphIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 13 * root.s
                    height: 13 * root.s
                    name: "record"
                    color: Theme.primary
                    stroke: 1.7
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "RECORD"
                    color: Theme.onSurface
                    font.family: Theme.mono
                    font.pixelSize: 10.5 * root.s
                    font.weight: Font.DemiBold
                    font.letterSpacing: 1.6 * root.s
                }
            }
            HoverHandler { id: recBtnHov; cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: { Recorder.chooserOpen = true; root.requestClose(); } }
        }

        // discord-quick toggle: shrink a Quick capture under 10MB for chat.
        // drives Recorder.discordMode (persisted); the pre-record chooser latches
        // it when Quick starts, and Studio is never compressed.
        Rectangle {
            width: parent.width
            visible: !Recorder.active
            implicitHeight: dcCol.implicitHeight + 16 * root.s
            color: Theme.surfaceContainerHigh
            border.width: 1
            border.color: Theme.outline

            GlyphIcon {
                id: dcIcon
                anchors.left: parent.left
                anchors.leftMargin: 9 * root.s
                anchors.verticalCenter: parent.verticalCenter
                width: 15 * root.s
                height: 15 * root.s
                name: "discord"
                color: Recorder.discordMode ? Theme.primary : Theme.onSurfaceVariant
                stroke: 1.6
            }

            LinkToggle {
                id: dcSwitch
                anchors.right: parent.right
                anchors.rightMargin: 9 * root.s
                anchors.verticalCenter: parent.verticalCenter
                s: root.s
                on: Recorder.discordMode
                onToggled: Recorder.discordMode = !Recorder.discordMode
            }

            Column {
                id: dcCol
                anchors.left: dcIcon.right
                anchors.leftMargin: 9 * root.s
                anchors.right: dcSwitch.left
                anchors.rightMargin: 9 * root.s
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2 * root.s
                Text {
                    text: "Discord clip"
                    color: Theme.onSurface
                    font.family: Theme.fontPrimary
                    font.pixelSize: 12 * root.s
                    font.weight: Font.DemiBold
                }
                Text {
                    width: parent.width
                    text: "Quick clips auto-compress to fit Discord (under 10 MB), keeping quality and sound. Studio stays full size."
                    color: Theme.onSurfaceVariant
                    font.family: Theme.fontPrimary
                    font.pixelSize: 10 * root.s
                    wrapMode: Text.WordWrap
                    lineHeight: 1.15
                }
            }
        }

        // empty state.
        Text {
            visible: recModel.count === 0 && !Recorder.active
            text: "No recordings yet"
            color: Theme.onSurfaceVariant
            font.family: Theme.fontPrimary
            font.pixelSize: 11 * root.s
        }

        // recordings list, capped at 4 rows.
        ListView {
            width: parent.width
            visible: recModel.count > 0
            implicitHeight: Math.min(recModel.count, 4) * 30 * root.s
            clip: true
            model: recModel
            spacing: 0
            boundsBehavior: Flickable.StopAtBounds

            delegate: Rectangle {
                id: recItem
                required property string path
                required property string label
                required property string size
                width: ListView.view.width
                height: 30 * root.s
                color: rHov.hovered ? Theme.frameBg : "transparent"
                Behavior on color { ColorAnimation { duration: Motion.fast } }
                HoverHandler { id: rHov }

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 4 * root.s
                    anchors.right: sizeText.left
                    anchors.rightMargin: 8 * root.s
                    anchors.verticalCenter: parent.verticalCenter
                    text: recItem.label
                    elide: Text.ElideRight
                    color: Theme.onSurfaceVariant
                    font.family: Theme.fontPrimary
                    font.pixelSize: 11 * root.s
                }

                Text {
                    id: sizeText
                    anchors.right: actions.left
                    anchors.rightMargin: 6 * root.s
                    anchors.verticalCenter: parent.verticalCenter
                    text: recItem.size
                    color: Theme.onSurfaceVariant
                    font.family: Theme.mono
                    font.pixelSize: 9.5 * root.s
                    font.features: { "tnum": 1 }
                }

                Row {
                    id: actions
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 0
                    IconBtn {
                        glyph: "play"
                        box: 24
                        tint: Theme.onSurface
                        onClicked: { Quickshell.execDetached(["xdg-open", recItem.path]); root.requestClose(); }
                    }
                    IconBtn {
                        glyph: "folder"
                        box: 24
                        onClicked: { Quickshell.execDetached(["xdg-open", root.recDir]); root.requestClose(); }
                    }
                    IconBtn {
                        glyph: "trash"
                        box: 24
                        tint: Theme.vermLit
                        onClicked: {
                            Quickshell.execDetached(["sh", "-c", "gio trash \"$1\" 2>/dev/null || rm -f \"$1\"", "_", recItem.path]);
                            recRefresh.restart();
                        }
                    }
                }
            }
        }
    }
}
