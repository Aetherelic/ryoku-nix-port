pragma ComponentBehavior: Bound

import QtQuick
import ".."
import shell.services
import "../../../components"
import "../framebars/menus" as Tips

// Capture card: the Super+S surface, a frame-edge card on the shared PopoutCard
// skin so it opens, melts and dismisses exactly like the music / bluetooth cards.
// Screenshot is the quick path -- pick a delay, a save target and a mode; with
// "Beautify after" on the saved shot then opens in Ryoshot. Record starts a Quick
// capture (the floating island takes over the live controls), with desktop / mic
// toggles and an "edit in Ryomotion when done" hand-off. Every option is
// remembered (Capture / Recorder prefs). Compact by design; never grabs the keyboard.
Item {
    id: root

    property real s: 1
    property bool open: false
    signal requestClose()

    readonly property real pad: 12 * root.s
    readonly property real gap: 7 * root.s
    readonly property color ink: Theme.ink(Theme.effectiveSurface)
    readonly property color inkDim: Theme.inkOn(Theme.effectiveSurface, Theme.onSurfaceVariant, 3.0)
    readonly property color line: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.14)
    readonly property real innerW: root.width - root.pad * 2

    readonly property var delaySteps: [0, 1, 3, 5, 10]
    readonly property var saveSteps: ["both", "clipboard", "file"]
    function cycle(arr, cur) { const i = arr.indexOf(cur); return arr[(i + 1) % arr.length]; }

    readonly property string saveGlyph: Capture.save === "clipboard" ? "clipboard" : Capture.save === "file" ? "folder" : "image"
    readonly property string saveLabel: Capture.save === "clipboard" ? qsTr("Clip")
        : Capture.save === "file" ? qsTr("Folder") : qsTr("Both")

    function shoot(mode) { root.requestClose(); Capture.shoot(mode); }
    function record(region) {
        root.requestClose();
        if (region)
            Capture.recordRegion(Recorder.recordArgs());
        else
            Recorder.start(Recorder.recordArgs());
    }

    implicitWidth: 264 * root.s
    implicitHeight: content.implicitHeight + root.pad * 2

    // the shared card skin: framed surface tile + click-swallow, same as music/bt.
    PopoutCard { anchors.fill: parent }

    // ── shared bits ───────────────────────────────────────────────────────────

    component Eyebrow: Text {
        color: root.inkDim
        font.family: Theme.mono
        font.pixelSize: 9 * root.s
        font.letterSpacing: 1.6
        font.weight: Font.Medium
    }

    // small tap-to-cycle pill (delay, save target): hairline box, glyph + label.
    component CycleChip: Item {
        id: chip
        property string glyph: ""
        property string label: ""
        signal tapped()
        property string tip: ""
        implicitHeight: 19 * root.s
        implicitWidth: chipRow.implicitWidth + 12 * root.s
        Rectangle {
            anchors.fill: parent
            radius: 5 * root.s
            color: chHov.hovered ? Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.08) : "transparent"
            border.width: Theme.borderWidth
            border.color: root.line
        }
        Row {
            id: chipRow
            anchors.centerIn: parent
            spacing: 4 * root.s
            GlyphIcon {
                anchors.verticalCenter: parent.verticalCenter
                width: 11 * root.s
                height: width
                name: chip.glyph
                stroke: 1.7
                color: root.inkDim
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: chip.label
                color: root.ink
                font.family: Theme.mono
                font.pixelSize: 9.5 * root.s
                font.weight: Font.Medium
            }
        }
        HoverHandler { id: chHov; cursorShape: Qt.PointingHandCursor }
        MouseArea { anchors.fill: parent; onClicked: chip.tapped() }
        Tips.QsTip { text: chip.tip; below: true; hovered: chHov.hovered }
    }
    // small icon-only toggle with a hover bubble (desktop / mic audio): bone-plate
    // when on, hairline when off.
    component IconToggle: Item {
        id: itg
        property string glyph: ""
        property string tip: ""
        property bool on: false
        signal toggled()
        implicitWidth: 22 * root.s
        implicitHeight: 18 * root.s
        Rectangle {
            anchors.fill: parent
            radius: 4 * root.s
            color: itg.on ? Theme.inverseSurface
                : (igHov.hovered ? Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.08) : "transparent")
            border.width: itg.on ? 0 : Theme.borderWidth
            border.color: root.line
            Behavior on color { ColorAnimation { duration: Motion.fast } }
        }
        GlyphIcon {
            anchors.centerIn: parent
            width: 12.5 * root.s
            height: width
            name: itg.glyph
            stroke: 1.7
            color: itg.on ? Theme.inverseOnSurface : root.inkDim
        }
        HoverHandler { id: igHov; cursorShape: Qt.PointingHandCursor }
        MouseArea { anchors.fill: parent; onClicked: itg.toggled() }
        Tips.QsTip { text: itg.tip; below: true; hovered: igHov.hovered }
    }

    // a capture-mode tile: crisp glyph over a tiny label, hairline box, hover lift.
    // `accent` tints the glyph vermilion for the record tiles.
    component ModeTile: Item {
        id: tile
        property real w: 54 * root.s
        property string glyph: ""
        property string label: ""
        property bool accent: false
        signal tapped()
        width: tile.w
        implicitHeight: 40 * root.s
        Rectangle {
            anchors.fill: parent
            radius: 6 * root.s
            color: tHov.hovered ? Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.08) : "transparent"
            border.width: Theme.borderWidth
            border.color: tHov.hovered ? Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.28) : root.line
            Behavior on border.color { ColorAnimation { duration: Motion.fast } }
        }
        Column {
            anchors.centerIn: parent
            spacing: 3 * root.s
            GlyphIcon {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 16 * root.s
                height: width
                name: tile.glyph
                stroke: 1.7
                color: tile.accent ? Theme.vermLit : root.ink
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: tile.label
                color: root.inkDim
                font.family: Theme.fontPrimary
                font.pixelSize: 8.5 * root.s
                font.weight: Font.Medium
            }
        }
        HoverHandler { id: tHov; cursorShape: Qt.PointingHandCursor }
        MouseArea { anchors.fill: parent; onClicked: tile.tapped() }
    }

    // one-line switch row (beautify, edit-after): glyph + label + LinkToggle; the
    // whole row taps to flip.
    component InlineToggle: Item {
        id: it
        property string glyph: ""
        property string label: ""
        property bool on: false
        signal toggled()
        implicitHeight: 20 * root.s
        GlyphIcon {
            id: itIcon
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: 14 * root.s
            height: width
            name: it.glyph
            stroke: 1.7
            color: it.on ? Theme.vermLit : root.inkDim
            Behavior on color { ColorAnimation { duration: Motion.fast } }
        }
        Text {
            anchors.left: itIcon.right
            anchors.leftMargin: 8 * root.s
            anchors.right: itSwitch.left
            anchors.rightMargin: 8 * root.s
            anchors.verticalCenter: parent.verticalCenter
            text: it.label
            color: root.ink
            font.family: Theme.fontPrimary
            font.pixelSize: 11.5 * root.s
            font.weight: Font.DemiBold
            elide: Text.ElideRight
        }
        LinkToggle {
            id: itSwitch
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            s: root.s
            on: it.on
            onToggled: it.toggled()
        }
        HoverHandler { cursorShape: Qt.PointingHandCursor }
        MouseArea { anchors.fill: parent; onClicked: it.toggled() }
    }

    // small square icon button for the live record controls (pause / stop).
    component MiniBtn: Rectangle {
        id: mb
        property string glyph: ""
        property color tint: root.ink
        signal tapped()
        width: 24 * root.s
        height: width
        radius: 6 * root.s
        color: mbHov.hovered ? Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.10) : "transparent"
        Behavior on color { ColorAnimation { duration: Motion.fast } }
        GlyphIcon {
            anchors.centerIn: parent
            width: 12 * root.s
            height: width
            name: mb.glyph
            stroke: 1.7
            color: mb.tint
        }
        HoverHandler { id: mbHov; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: mb.tapped() }
    }

    component Rule: Rectangle {
        implicitHeight: Theme.borderWidth
        color: root.line
    }

    // ── layout ────────────────────────────────────────────────────────────────
    Column {
        id: content
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: root.pad
        spacing: 8 * root.s

        // SCREENSHOT eyebrow, with the save target + delay chips on the right.
        Item {
            z: 20
            width: parent.width
            height: 19 * root.s
            Eyebrow {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: qsTr("SCREENSHOT")
            }
            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 5 * root.s
                CycleChip {
                    anchors.verticalCenter: parent.verticalCenter
                    glyph: root.saveGlyph
                    label: root.saveLabel
                    tip: Capture.save === "clipboard" ? qsTr("Copy to clipboard only") : Capture.save === "file" ? qsTr("Save to Screenshots folder") : qsTr("Save to Screenshots folder + clipboard")
                    onTapped: Capture.save = root.cycle(root.saveSteps, Capture.save)
                }
                CycleChip {
                    anchors.verticalCenter: parent.verticalCenter
                    glyph: "watch"
                    label: Capture.delay + "s"
                    tip: Capture.delay === 0 ? qsTr("No delay before the shot") : qsTr("%1s delay before the shot").arg(Capture.delay)
                    onTapped: Capture.delay = root.cycle(root.delaySteps, Capture.delay)
                }
            }
        }

        // capture modes: All / Screen / Window / Region.
        Row {
            width: parent.width
            spacing: root.gap
            ModeTile { w: (root.innerW - root.gap * 3) / 4; glyph: "screens"; label: qsTr("All"); onTapped: root.shoot("all") }
            ModeTile { w: (root.innerW - root.gap * 3) / 4; glyph: "monitor"; label: qsTr("Screen"); onTapped: root.shoot("monitor") }
            ModeTile { w: (root.innerW - root.gap * 3) / 4; glyph: "window"; label: qsTr("Window"); onTapped: root.shoot("window") }
            ModeTile { w: (root.innerW - root.gap * 3) / 4; glyph: "region"; label: qsTr("Region"); onTapped: root.shoot("region") }
        }

        // beautify-after switch.
        InlineToggle {
            width: parent.width
            glyph: "sparkle"
            label: qsTr("Beautify after")
            on: Capture.beautify
            onToggled: Capture.beautify = !Capture.beautify
        }

        Rule { width: parent.width }

        // RECORD eyebrow, with the desktop / mic toggles on the right (hidden while
        // a recording is live).
        Item {
            z: 20
            width: parent.width
            height: 19 * root.s
            Eyebrow {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: qsTr("RECORD")
            }
            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 5 * root.s
                visible: !Recorder.anyActive
                IconToggle {
                    glyph: "webcam"
                    tip: qsTr("Webcam mirror (place it before recording)")
                    on: Camera.active
                    onToggled: Camera.toggle()
                }
                IconToggle {
                    glyph: Recorder.optDesktopAudio ? "speaker" : "speaker-off"
                    tip: qsTr("Record desktop audio")
                    on: Recorder.optDesktopAudio
                    onToggled: Recorder.optDesktopAudio = !Recorder.optDesktopAudio
                }
                IconToggle {
                    glyph: Recorder.optMic ? "mic" : "mic-off"
                    tip: qsTr("Record microphone")
                    on: Recorder.optMic
                    onToggled: Recorder.optMic = !Recorder.optMic
                }
            }
        }

        // record starts: Screen / Region (swap for the live indicator when active).
        Row {
            width: parent.width
            visible: !Recorder.anyActive
            spacing: root.gap
            ModeTile { w: (root.innerW - root.gap) / 2; glyph: "monitor"; label: qsTr("Screen"); accent: true; onTapped: root.record(false) }
            ModeTile { w: (root.innerW - root.gap) / 2; glyph: "region"; label: qsTr("Region"); accent: true; onTapped: root.record(true) }
        }

        // live indicator: pulsing REC tag, elapsed clock, pause + stop.
        Rectangle {
            width: parent.width
            visible: Recorder.anyActive
            height: 36 * root.s
            radius: 6 * root.s
            color: "transparent"
            border.width: Theme.borderWidth
            border.color: root.line
            Row {
                anchors.left: parent.left
                anchors.leftMargin: 9 * root.s
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8 * root.s
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 8 * root.s
                    height: width
                    radius: width / 2
                    color: Recorder.paused ? root.inkDim : Theme.vermLit
                    opacity: Recorder.paused ? 1 : Recorder.pulse
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Recorder.paused ? qsTr("Paused") : qsTr("Recording")
                    color: root.ink
                    font.family: Theme.fontPrimary
                    font.pixelSize: 11.5 * root.s
                    font.weight: Font.DemiBold
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Recorder.elapsedText
                    color: root.inkDim
                    font.family: Theme.fontPrimary
                    font.pixelSize: 10.5 * root.s
                    font.features: { "tnum": 1 }
                }
            }
            Row {
                anchors.right: parent.right
                anchors.rightMargin: 7 * root.s
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2 * root.s
                MiniBtn {
                    visible: Recorder.canPause
                    glyph: Recorder.paused ? "play" : "pause"
                    tint: root.ink
                    onTapped: Recorder.togglePause()
                }
                MiniBtn {
                    glyph: "stop"
                    tint: Theme.vermLit
                    onTapped: Recorder.studioActive ? Recorder.stopStudio() : Recorder.stop()
                }
            }
        }

        // Post-capture actions for Quick recordings.
        InlineToggle {
            width: parent.width
            glyph: "film"
            label: qsTr("Edit in Ryomotion when done")
            on: Recorder.editMode
            onToggled: Recorder.editMode = !Recorder.editMode
        }
        InlineToggle {
            width: parent.width
            visible: !Recorder.anyActive
            glyph: "discord"
            label: qsTr("Compact for Discord")
            on: Recorder.discordMode
            onToggled: Recorder.discordMode = !Recorder.discordMode
        }

        Rule { width: parent.width }

        // hint: the companion beautify/annotate app.
        Text {
            width: parent.width
            text: qsTr("Super+Shift+S opens Ryoshot to beautify & annotate.")
            color: root.inkDim
            font.family: Theme.fontPrimary
            font.pixelSize: 9 * root.s
            wrapMode: Text.WordWrap
            lineHeight: 1.1
        }
    }
}
