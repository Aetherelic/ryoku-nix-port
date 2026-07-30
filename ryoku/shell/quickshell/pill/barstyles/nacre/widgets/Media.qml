import QtQuick
import "../../../Singletons"
import "../../.." as Pill

Item {
    id: root

    property real barHeight: 40
    signal popupRequested(string name, real center, bool active, bool pinned)

    implicitWidth: content.implicitWidth
    implicitHeight: 26
    visible: true

    onVisibleChanged: AudioBars.setActive(root, visible)
    Component.onCompleted: AudioBars.setActive(root, visible)
    Component.onDestruction: AudioBars.setActive(root, false)

    HoverHandler {
        id: hover
        onHoveredChanged: root.popupRequested("media",
            root.mapToItem(null, root.width / 2, root.height / 2).x, hovered, false)
    }
    TapHandler { onTapped: Media.toggle() }

    Row {
        id: content
        anchors.centerIn: parent
        spacing: 6

        Pill.MaterialIcon {
            anchors.verticalCenter: parent.verticalCenter
            text: Media.playing ? "music_note" : "music_off"
            font.pixelSize: Theme.iconSm
            color: Theme.onSurfaceVariant
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            width: 150
            text: Media.line.length > 0 ? Media.line : qsTr("No music")
            elide: Text.ElideRight
            color: Theme.onSurface
            font.family: Theme.fontPrimary
            font.pixelSize: Theme.fontSm
        }
        Pill.MusicBars {
            anchors.verticalCenter: parent.verticalCenter
            width: 28
            height: 14
            orient: "vertical"
            bands: 8
            running: Media.playing
        }
    }

}
