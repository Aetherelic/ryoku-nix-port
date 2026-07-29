import QtQuick
import "../../../Singletons"
import "../../.." as Pill
import "../../shared" as Shared
import "../../shared/popouts" as Popouts

Item {
    id: root

    property real barHeight: 40

    implicitWidth: content.implicitWidth
    implicitHeight: 26
    visible: Media.present

    onVisibleChanged: AudioBars.setActive(root, visible)
    Component.onCompleted: AudioBars.setActive(root, visible)
    Component.onDestruction: AudioBars.setActive(root, false)

    HoverHandler { id: hover }
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
            text: Media.line
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

    Shared.Popout {
        target: root
        targetHovered: hover.hovered
        barHeight: root.barHeight
        namespace: "ryoku-nacre-popout"
        content: popup
    }
    Component {
        id: popup
        Popouts.MediaPopout {}
    }
}
