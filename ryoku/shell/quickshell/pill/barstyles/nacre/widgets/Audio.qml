import QtQuick
import "../../../Singletons"
import "../../.." as Pill
import "../../shared" as Shared
import "../../shared/popouts" as Popouts

Item {
    id: root

    property real barHeight: 40
    property bool open: popupHost.shown
    readonly property var sink: Audio.sink
    readonly property bool available: !!(root.sink && root.sink.audio)
    readonly property bool muted: root.available && root.sink.audio.muted

    implicitWidth: content.implicitWidth
    implicitHeight: 26

    function step(up) {
        if (root.available)
            root.sink.audio.volume = Math.max(0, Math.min(1, root.sink.audio.volume + (up ? 0.02 : -0.02)));
    }

    HoverHandler { id: hover }
    WheelHandler { onWheel: event => root.step(event.angleDelta.y > 0) }
    TapHandler { onTapped: if (root.available) root.sink.audio.muted = !root.sink.audio.muted }

    Row {
        id: content
        anchors.centerIn: parent
        spacing: 4

        Pill.MaterialIcon {
            anchors.verticalCenter: parent.verticalCenter
            text: root.muted ? "volume_off" : "volume_up"
            font.pixelSize: Theme.iconSm
            color: root.muted ? Theme.onSurfaceVariant : Theme.onSurface
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: !root.available ? "--" : root.muted ? "off" : Math.round(root.sink.audio.volume * 100) + "%"
            color: root.muted ? Theme.onSurfaceVariant : Theme.onSurface
            font.family: Theme.mono
            font.pixelSize: Theme.fontSm
        }
    }

    Shared.Popout {
        id: popupHost
        target: root
        targetHovered: hover.hovered
        barHeight: root.barHeight
        namespace: "ryoku-nacre-popout"
        content: popup
    }
    Component {
        id: popup
        Popouts.AudioPopout { open: root.open }
    }
}
