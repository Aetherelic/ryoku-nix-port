pragma ComponentBehavior: Bound

import QtQuick
import "../../../Singletons"
import "../../.." as Pill
import "../Format.js" as Format

Item {
    implicitWidth: 300
    implicitHeight: content.implicitHeight + 32

    component TransportButton: Item {
        id: button

        property string icon: ""
        property bool primary: false
        signal clicked()

        width: 40
        height: 40

        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: button.primary
                ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, mouse.containsMouse ? 0.22 : 0.14)
                : mouse.containsMouse ? Qt.rgba(Theme.onSurface.r, Theme.onSurface.g, Theme.onSurface.b, 0.08)
                : "transparent"
        }
        Pill.MaterialIcon {
            anchors.centerIn: parent
            text: button.icon
            font.pixelSize: button.primary ? Theme.iconMd : 20
            fill: button.primary ? 1 : 0
            color: !button.enabled
                ? Qt.rgba(Theme.onSurface.r, Theme.onSurface.g, Theme.onSurface.b, 0.3)
                : button.primary ? Theme.primary : Theme.onSurface
        }
        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: button.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: button.clicked()
        }
    }

    Timer {
        interval: 500
        repeat: true
        running: Media.player !== null && Media.playing
        onTriggered: Media.player.positionChanged()
    }

    Column {
        id: content
        anchors.centerIn: parent
        width: parent.width - 32
        spacing: 12

        Pill.MusicBars {
            width: parent.width
            height: 28
            orient: "vertical"
            bands: 28
            running: Media.playing
            opacity: Media.playing ? 1 : 0.55
            Behavior on opacity {
                NumberAnimation { duration: Motion.standard; easing.type: Motion.easeStandard }
            }
        }

        Row {
            width: parent.width
            spacing: 12

            Rectangle {
                id: art
                width: 64
                height: 64
                radius: 10
                clip: true
                color: Qt.rgba(Theme.onSurface.r, Theme.onSurface.g, Theme.onSurface.b, 0.08)

                Image {
                    id: artImage
                    anchors.fill: parent
                    source: Media.player ? (Media.player.trackArtUrl || "") : ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }
                Pill.MaterialIcon {
                    anchors.centerIn: parent
                    text: "music_note"
                    font.pixelSize: Theme.iconMd
                    color: Theme.onSurfaceVariant
                    visible: artImage.status !== Image.Ready || artImage.source === ""
                }
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - art.width - parent.spacing
                spacing: 3

                Text {
                    width: parent.width
                    text: Media.player ? (Media.player.trackTitle || "") : ""
                    elide: Text.ElideRight
                    color: Theme.onSurface
                    font.family: Theme.fontPrimary
                    font.pixelSize: Theme.fontMd
                    font.weight: Font.Bold
                }
                Text {
                    width: parent.width
                    text: Media.player ? Theme.joinArtists(Media.player.trackArtists, Media.player.trackArtist) : ""
                    elide: Text.ElideRight
                    color: Theme.onSurfaceVariant
                    font.family: Theme.fontPrimary
                    font.pixelSize: Theme.fontSm
                }
            }
        }

        Item {
            id: seek
            width: parent.width
            height: 16

            readonly property real length: Media.player && Media.player.length > 0 ? Media.player.length : 0
            readonly property real fraction: seek.length > 0
                ? Math.max(0, Math.min(1, Media.player.position / seek.length)) : 0

            Text {
                id: elapsed
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: Format.duration(Media.player ? Media.player.position : 0)
                color: Theme.onSurfaceVariant
                font.family: Theme.mono
                font.pixelSize: Theme.fontSm - 2
            }
            Text {
                id: total
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: Format.duration(seek.length)
                color: Theme.onSurfaceVariant
                font.family: Theme.mono
                font.pixelSize: Theme.fontSm - 2
            }
            Rectangle {
                anchors.left: elapsed.right
                anchors.leftMargin: 6
                anchors.right: total.left
                anchors.rightMargin: 6
                anchors.verticalCenter: parent.verticalCenter
                height: 3
                radius: 1.5
                color: Qt.rgba(Theme.onSurface.r, Theme.onSurface.g, Theme.onSurface.b, 0.14)

                Rectangle {
                    width: parent.width * seek.fraction
                    height: parent.height
                    radius: parent.radius
                    color: Theme.primary
                }
            }
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 8

            TransportButton {
                icon: "skip_previous"
                enabled: Media.player ? Media.player.canGoPrevious : false
                onClicked: if (Media.player) Media.player.previous()
            }
            TransportButton {
                icon: Media.playing ? "pause" : "play_arrow"
                primary: true
                enabled: Media.player ? Media.player.canTogglePlaying : false
                onClicked: Media.toggle()
            }
            TransportButton {
                icon: "skip_next"
                enabled: Media.player ? Media.player.canGoNext : false
                onClicked: if (Media.player) Media.player.next()
            }
        }
    }
}
