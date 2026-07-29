pragma ComponentBehavior: Bound

import QtQuick
import "../../../Singletons"
import "../components" as C
import "../../.." as Pill
import "../../../framebars/menus" as Menus
import "../../../popouts" as Pop

// Obi audio: compact output and input controls in the bar (scroll to set volume,
// click to mute), with a mixer card on hover that grows off them: output and
// input faders with device pickers, per-app volumes. Reads the shared Audio graph.
Item {
    id: root

    implicitWidth: rowr.implicitWidth
    implicitHeight: 26

    readonly property var sink: Audio.sink
    readonly property var source: Audio.source
    readonly property bool haveSink: !!(root.sink && root.sink.audio)
    readonly property bool haveSource: !!(root.source && root.source.audio)
    property bool open: hostPop.shown

    function stepVol(node, up) {
        if (!(node && node.audio))
            return;
        node.audio.volume = Math.max(0, Math.min(1, node.audio.volume + (up ? 0.02 : -0.02)));
    }

    HoverHandler { id: hh }

    Row {
        id: rowr
        anchors.centerIn: parent
        spacing: 12

        Row {
            id: outRow
            anchors.verticalCenter: parent.verticalCenter
            spacing: 5
            readonly property bool muted: root.haveSink && root.sink.audio.muted

            Pill.MaterialIcon {
                anchors.verticalCenter: parent.verticalCenter
                text: outRow.muted ? "volume_off" : "volume_up"
                font.pixelSize: Theme.iconSm
                color: outRow.muted ? Theme.onSurfaceVariant : Theme.onSurface
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: !root.haveSink ? "--" : (outRow.muted ? "off" : Math.round(root.sink.audio.volume * 100) + "%")
                color: outRow.muted ? Theme.onSurfaceVariant : Theme.onSurface
                font.family: Theme.mono
                font.pixelSize: Theme.fontSm
            }

            WheelHandler { onWheel: e => root.stepVol(root.sink, e.angleDelta.y > 0) }
            TapHandler { onTapped: if (root.haveSink) root.sink.audio.muted = !root.sink.audio.muted }
        }

        Row {
            id: inRow
            anchors.verticalCenter: parent.verticalCenter
            spacing: 5
            readonly property bool muted: root.haveSource && root.source.audio.muted

            Pill.MaterialIcon {
                anchors.verticalCenter: parent.verticalCenter
                text: inRow.muted ? "mic_off" : "mic"
                font.pixelSize: Theme.iconSm
                color: inRow.muted ? Theme.error : Theme.onSurface
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: !root.haveSource ? "--" : (inRow.muted ? "off" : Math.round(root.source.audio.volume * 100) + "%")
                color: inRow.muted ? Theme.error : Theme.onSurface
                font.family: Theme.mono
                font.pixelSize: Theme.fontSm
            }

            WheelHandler { onWheel: e => root.stepVol(root.source, e.angleDelta.y > 0) }
            TapHandler { onTapped: if (root.haveSource) root.source.audio.muted = !root.source.audio.muted }
        }
    }

    C.Popout {
        id: hostPop
        target: root
        targetHovered: hh.hovered
        content: popContent
    }

    Component {
        id: popContent
        Item {
            id: pop
            implicitWidth: 300
            implicitHeight: col.implicitHeight + 24

            property bool outDevicesOpen: false
            property bool inDevicesOpen: false

            component Head: Text {
                color: Theme.onSurfaceVariant
                font.family: Theme.mono
                font.pixelSize: 9
                font.letterSpacing: 1.5
            }

            Column {
                id: col
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
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

                    Head { text: "OUTPUT" }
                    Pill.HFader {
                        width: parent.width
                        icon: root.sink ? Audio.nodeIcon(root.sink) : "speaker"
                        lit: root.open
                        value: root.haveSink ? root.sink.audio.volume : 0
                        muted: root.haveSink ? root.sink.audio.muted : false
                        valueLabel: !root.haveSink ? "" : (root.sink.audio.muted ? "off" : Math.round(root.sink.audio.volume * 100) + "%")
                        peakNode: root.sink
                        peakEnabled: root.open && !!root.sink
                        onMoved: v => { if (root.haveSink) root.sink.audio.volume = v; }
                        onIconTapped: { if (root.haveSink) root.sink.audio.muted = !root.sink.audio.muted; }
                    }
                    Menus.AudioDevicePicker {
                        width: parent.width
                        current: root.sink
                        devices: Audio.outputs
                        listOpen: pop.outDevicesOpen
                        fallbackIcon: "speaker"
                        emptyLabel: "No output device"
                        onToggled: pop.outDevicesOpen = !pop.outDevicesOpen
                        onPicked: node => Audio.setOutput(node)
                    }
                    Row {
                        width: parent.width
                        spacing: 6
                        visible: Audio.sinkIsBluez
                        Pop.PopoutChip {
                            glyph: "bluetooth"
                            label: Audio.btCodec.length ? Audio.btCodec : "Codec"
                        }
                        Pop.PopoutChip {
                            label: Audio.profileLabel().length ? Audio.profileLabel() : "Profile"
                            act: true
                            onClicked: Audio.toggleProfile()
                        }
                    }
                }

                Column {
                    width: parent.width
                    spacing: 6

                    Head { text: "INPUT" }
                    Pill.HFader {
                        width: parent.width
                        icon: "mic"
                        lit: root.open
                        value: root.haveSource ? root.source.audio.volume : 0
                        muted: root.haveSource ? root.source.audio.muted : false
                        valueLabel: !root.haveSource ? "" : (root.source.audio.muted ? "off" : Math.round(root.source.audio.volume * 100) + "%")
                        peakNode: root.source
                        peakEnabled: root.open && !!root.source
                        onMoved: v => { if (root.haveSource) root.source.audio.volume = v; }
                        onIconTapped: { if (root.haveSource) root.source.audio.muted = !root.source.audio.muted; }
                    }
                    Menus.AudioDevicePicker {
                        width: parent.width
                        current: root.source
                        devices: Audio.inputs
                        listOpen: pop.inDevicesOpen
                        fallbackIcon: "mic"
                        emptyLabel: "No input device"
                        onToggled: pop.inDevicesOpen = !pop.inDevicesOpen
                        onPicked: node => Audio.setInput(node)
                    }
                }

                Column {
                    id: appsCol
                    width: parent.width
                    spacing: 6

                    Head { text: "APPS" }
                    Repeater {
                        model: root.open ? Audio.streams : []
                        delegate: Pill.AudioAppRow {
                            required property var modelData
                            width: appsCol.width
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
    }
}
