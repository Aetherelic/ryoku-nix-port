pragma ComponentBehavior: Bound

import QtQuick
import "../.." as Pill
import "../../Singletons"
import "../lib/devices.js" as DeviceModel
import "../lib/audioselect.js" as AudioSelect

Item {
    id: root

    required property real s
    required property bool open

    property string pickedName: ""
    readonly property var current: AudioSelect.stable(Audio.inputs, root.pickedName, Audio.source)
    readonly property var rows: root.open
        ? DeviceModel.audioRows(Audio.inputs, root.current,
            ({ label: n => Audio.nodeLabel(n), icon: n => Audio.nodeIcon(n) }))
        : []

    implicitWidth: 300 * s
    implicitHeight: col.implicitHeight

    function nodeByName(name) {
        const list = Audio.inputs;
        for (let i = 0; i < list.length; i++)
            if (list[i] && list[i].name === name)
                return list[i];
        return null;
    }

    function pick(name) {
        const n = root.nodeByName(name);
        if (n) {
            root.pickedName = name;
            Audio.setInput(n);
        }
    }

    Column {
        id: col
        width: root.width
        spacing: 12 * root.s

        Pill.MicroLabel { label: qsTr("Input"); s: root.s }

        Pill.HFader {
            width: parent.width
            s: root.s
            icon: "mic"
            lit: root.open
            value: Audio.source ? Audio.source.audio.volume : 0
            muted: Audio.source ? Audio.source.audio.muted : false
            valueLabel: !Audio.source ? "" : (Audio.source.audio.muted ? qsTr("off") : Math.round(Audio.source.audio.volume * 100) + "%")
            peakNode: Audio.source
            peakEnabled: root.open && !!Audio.source
            onMoved: v => { if (Audio.source) Audio.source.audio.volume = v; }
            onIconTapped: { if (Audio.source) Audio.source.audio.muted = !Audio.source.audio.muted; }
        }

        MenuDivider { width: parent.width; scale: root.s }

        Pill.MicroLabel { label: qsTr("Devices"); s: root.s }

        Text {
            width: parent.width
            visible: root.rows.length === 0
            text: qsTr("No input devices")
            color: Theme.onSurfaceVariant
            font.family: Theme.fontPrimary
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
                radius: Theme.radiusWidget
                color: drow.modelData.selected ? Qt.alpha(Theme.primary, 0.16) : (dHov.hovered ? Theme.frameBg : "transparent")
                border.width: 1
                border.color: drow.modelData.selected ? Theme.primary : (dHov.hovered ? Theme.frameBorder : Theme.outline)
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
                    color: drow.modelData.selected ? Theme.primary : Theme.onSurfaceVariant
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
                    color: drow.modelData.selected ? Theme.primary : Theme.onSurface
                    font.family: Theme.fontPrimary
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
                    color: Theme.primary
                    stroke: 2
                    visible: drow.modelData.selected
                }

                HoverHandler { id: dHov; cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: root.pick(drow.modelData.name) }
            }
        }
    }
}
