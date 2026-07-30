pragma ComponentBehavior: Bound

import QtQuick
import "../../../Singletons"
import "../../.." as Pill
import "../../../framebars/menus" as Menus
import "../../../popouts" as Popouts

Item {
    id: root

    property bool open: true
    readonly property var sink: Audio.sink
    readonly property var source: Audio.source
    readonly property bool haveSink: !!(root.sink && root.sink.audio)
    readonly property bool haveSource: !!(root.source && root.source.audio)

    implicitWidth: 300
    implicitHeight: content.implicitHeight + 24

    property bool outputPickerOpen: false
    property bool inputPickerOpen: false

    component Heading: Text {
        color: Theme.onSurfaceVariant
        font.family: Theme.mono
        font.pixelSize: 9
        font.letterSpacing: 1.5
    }

    Column {
        id: content
        anchors.fill: parent
        anchors.margins: 12
        spacing: 11

        Text {
            text: "AUDIO"
            color: Theme.onSurfaceVariant
            font.family: Theme.mono
            font.pixelSize: 9
            font.letterSpacing: 1.6
            font.weight: Font.Medium
        }

        Column {
            width: parent.width
            spacing: 6

            Heading { text: "OUTPUT" }
            Pill.HFader {
                width: parent.width
                icon: root.sink ? Audio.nodeIcon(root.sink) : "speaker"
                lit: root.open
                value: root.haveSink ? root.sink.audio.volume : 0
                muted: root.haveSink ? root.sink.audio.muted : false
                valueLabel: !root.haveSink ? "" : (root.sink.audio.muted ? "off" : Math.round(root.sink.audio.volume * 100) + "%")
                peakNode: root.sink
                peakEnabled: root.open && !!root.sink
                onMoved: value => { if (root.haveSink) root.sink.audio.volume = value; }
                onIconTapped: { if (root.haveSink) root.sink.audio.muted = !root.sink.audio.muted; }
            }
            Menus.AudioDevicePicker {
                width: parent.width
                current: root.sink
                devices: Audio.outputs
                listOpen: root.outputPickerOpen
                fallbackIcon: "speaker"
                emptyLabel: "No output device"
                onToggled: root.outputPickerOpen = !root.outputPickerOpen
                onPicked: node => Audio.setOutput(node)
            }
            Row {
                width: parent.width
                spacing: 6
                visible: Audio.sinkIsBluez

                Popouts.PopoutChip {
                    glyph: "bluetooth"
                    label: Audio.btCodec.length ? Audio.btCodec : "Codec"
                }
                Popouts.PopoutChip {
                    label: Audio.profileLabel().length ? Audio.profileLabel() : "Profile"
                    act: true
                    onClicked: Audio.toggleProfile()
                }
            }
        }

        Column {
            width: parent.width
            spacing: 6

            Heading { text: "INPUT" }
            Pill.HFader {
                width: parent.width
                icon: "mic"
                lit: root.open
                value: root.haveSource ? root.source.audio.volume : 0
                muted: root.haveSource ? root.source.audio.muted : false
                valueLabel: !root.haveSource ? "" : (root.source.audio.muted ? "off" : Math.round(root.source.audio.volume * 100) + "%")
                peakNode: root.source
                peakEnabled: root.open && !!root.source
                onMoved: value => { if (root.haveSource) root.source.audio.volume = value; }
                onIconTapped: { if (root.haveSource) root.source.audio.muted = !root.source.audio.muted; }
            }
            Menus.AudioDevicePicker {
                width: parent.width
                current: root.source
                devices: Audio.inputs
                listOpen: root.inputPickerOpen
                fallbackIcon: "mic"
                emptyLabel: "No input device"
                onToggled: root.inputPickerOpen = !root.inputPickerOpen
                onPicked: node => Audio.setInput(node)
            }
        }

        Column {
            id: applications
            width: parent.width
            spacing: 6

            Heading { text: "APPS" }
            Repeater {
                model: root.open ? Audio.streams : []
                delegate: Pill.AudioAppRow {
                    required property var modelData
                    width: applications.width
                    open: root.open
                    stream: modelData
                }
            }
            Text {
                visible: Audio.streams.length === 0
                width: parent.width
                text: "Nothing playing"
                horizontalAlignment: Text.AlignHCenter
                color: Theme.onSurfaceVariant
                font.family: Theme.fontPrimary
                font.pixelSize: 10
            }
        }
    }
}
