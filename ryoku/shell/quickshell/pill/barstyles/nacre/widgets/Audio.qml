import QtQuick
import "../../../Singletons"
import "../../.." as Pill

Item {
    id: root

    property real barHeight: 40
    signal popupRequested(string name, real center, bool active, bool pinned)
    readonly property var sink: Audio.sink
    readonly property bool available: !!(root.sink && root.sink.audio)
    readonly property bool muted: root.available && root.sink.audio.muted

    implicitWidth: content.implicitWidth
    implicitHeight: 26

    function step(up) {
        if (root.available)
            root.sink.audio.volume = Math.max(0, Math.min(1, root.sink.audio.volume + (up ? 0.02 : -0.02)));
    }

    WheelHandler { onWheel: event => root.step(event.angleDelta.y > 0) }
    TapHandler {
        onTapped: root.popupRequested("audio",
            root.mapToItem(null, root.width / 2, root.height / 2).x, true, true)
    }

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

}
