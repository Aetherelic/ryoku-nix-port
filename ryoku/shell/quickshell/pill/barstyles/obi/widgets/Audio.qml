pragma ComponentBehavior: Bound

import QtQuick
import "../../../Singletons"
import "../../shared" as Shared
import "../../nacre/popouts" as NacrePopouts
import "../../.." as Pill

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

    Shared.Popout {
        id: hostPop
        target: root
        targetHovered: hh.hovered
        namespace: "ryoku-obi-popout"
        content: popContent
    }

    Component {
        id: popContent
        NacrePopouts.AudioPopout { open: root.open }
    }
}
