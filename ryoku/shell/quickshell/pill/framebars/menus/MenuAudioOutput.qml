pragma ComponentBehavior: Bound

import QtQuick
import "../.." as Pill
import "../../Singletons"
import "../lib/devices.js" as DeviceModel
import "../lib/audioselect.js" as AudioSelect

// Audio-output frame menu: the default sink's volume/mute fader over the list of
// switchable output devices. Selection is resolved by node name so it stays
// stable across a Pipewire graph refresh; the VU peak meter runs only while open.
Item {
    id: root

    required property real s
    required property bool open

    property string pickedName: ""
    readonly property var current: AudioSelect.stable(Audio.outputs, root.pickedName, Audio.sink)
    readonly property var rows: root.open
        ? DeviceModel.audioRows(Audio.outputs, root.current,
            ({ label: n => Audio.nodeLabel(n), icon: n => Audio.nodeIcon(n) }))
        : []

    implicitWidth: 300 * s
    implicitHeight: col.implicitHeight

    function nodeByName(name) {
        const list = Audio.outputs;
        for (let i = 0; i < list.length; i++)
            if (list[i] && list[i].name === name)
                return list[i];
        return null;
    }

    function pick(name) {
        const n = root.nodeByName(name);
        if (n) {
            root.pickedName = name;
            Audio.setOutput(n);
        }
    }

    Column {
        id: col
        width: root.width
        spacing: 12 * root.s

        Pill.MicroLabel { label: qsTr("Output"); s: root.s }

        Pill.HFader {
            width: parent.width
            s: root.s
            icon: "speaker"
            lit: root.open
            value: Audio.sink ? Audio.sink.audio.volume : 0
            muted: Audio.sink ? Audio.sink.audio.muted : false
            valueLabel: !Audio.sink ? "" : (Audio.sink.audio.muted ? qsTr("off") : Math.round(Audio.sink.audio.volume * 100) + "%")
            peakNode: Audio.sink
            peakEnabled: root.open && !!Audio.sink
            onMoved: v => { if (Audio.sink) Audio.sink.audio.volume = v; }
            onIconTapped: { if (Audio.sink) Audio.sink.audio.muted = !Audio.sink.audio.muted; }
        }

        MenuDivider { width: parent.width; scale: root.s }

        Pill.MicroLabel { label: qsTr("Devices"); s: root.s }

        Text {
            width: parent.width
            visible: root.rows.length === 0
            text: qsTr("No output devices")
            color: Theme.faint
            font.family: Theme.font
            font.pixelSize: 12 * root.s
            font.weight: Font.Medium
        }

        Repeater {
            model: root.rows
            delegate: Rectangle {
                id: drow
                required property var modelData
                width: col.width
                height: 38 * root.s
                radius: Theme.radius
                color: drow.modelData.selected ? Qt.alpha(Theme.brand, 0.16) : (dHov.hovered ? Theme.frameBg : "transparent")
                border.width: 1
                border.color: drow.modelData.selected ? Theme.brand : (dHov.hovered ? Theme.frameBorder : Theme.border)
                Behavior on color { ColorAnimation { duration: Motion.fast } }
                Behavior on border.color { ColorAnimation { duration: Motion.fast } }

                Pill.GlyphIcon {
                    id: dIcon
                    anchors.left: parent.left
                    anchors.leftMargin: 12 * root.s
                    anchors.verticalCenter: parent.verticalCenter
                    width: 15 * root.s
                    height: 15 * root.s
                    name: drow.modelData.icon
                    color: drow.modelData.selected ? Theme.brand : Theme.iconDim
                    stroke: 1.6
                }
                Text {
                    anchors.left: dIcon.right
                    anchors.leftMargin: 10 * root.s
                    anchors.right: dCheck.left
                    anchors.rightMargin: 8 * root.s
                    anchors.verticalCenter: parent.verticalCenter
                    text: drow.modelData.label
                    elide: Text.ElideRight
                    color: drow.modelData.selected ? Theme.brand : Theme.cream
                    font.family: Theme.font
                    font.pixelSize: 12 * root.s
                    font.weight: drow.modelData.selected ? Font.DemiBold : Font.Medium
                }
                Pill.GlyphIcon {
                    id: dCheck
                    anchors.right: parent.right
                    anchors.rightMargin: 12 * root.s
                    anchors.verticalCenter: parent.verticalCenter
                    width: 13 * root.s
                    height: 13 * root.s
                    name: "check"
                    color: Theme.brand
                    stroke: 2
                    visible: drow.modelData.selected
                }

                HoverHandler { id: dHov; cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: root.pick(drow.modelData.name) }
            }
        }
    }
}
