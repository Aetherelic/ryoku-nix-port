import QtQuick
import "../.." as Pill
import "../../Singletons"

Item {
    id: root

    required property real s
    required property bool open

    implicitWidth: 320 * s
    implicitHeight: content.implicitHeight

    Column {
        id: content
        width: parent.width
        spacing: 10 * root.s

        Text {
            text: Media.present ? (Media.player ? Media.player.trackTitle : "") : qsTr("Nothing playing")
            color: Media.present ? Theme.bright : Theme.faint
            font.family: Theme.display
            font.pixelSize: 18 * root.s
            elide: Text.ElideRight
            width: parent.width
        }
        Text {
            text: Media.player ? Theme.joinArtists(Media.player.trackArtists, Media.player.trackArtist) : ""
            color: Theme.dim
            font.family: Theme.font
            font.pixelSize: 11 * root.s
            width: parent.width
            elide: Text.ElideRight
        }
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 20 * root.s
            Repeater {
                model: ["prev", "play", "next"]
                delegate: Rectangle {
                    required property string modelData
                    width: 34 * root.s
                    height: 30 * root.s
                    radius: Theme.radius
                    color: mediaHover.hovered ? Theme.frameBg : Theme.tileBg
                    Pill.GlyphIcon {
                        anchors.centerIn: parent
                        width: 16 * root.s
                        height: 16 * root.s
                        name: modelData === "play" ? (Media.playing ? "pause" : "play") : modelData
                        color: Theme.cream
                        stroke: 1.6
                    }
                    HoverHandler { id: mediaHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler {
                        onTapped: {
                            if (!Media.player) return;
                            if (modelData === "prev") Media.player.previous();
                            else if (modelData === "next") Media.player.next();
                            else Media.toggle();
                        }
                    }
                }
            }
        }
    }
}
