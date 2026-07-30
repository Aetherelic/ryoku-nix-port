pragma ComponentBehavior: Bound

import QtQuick
import "../../../Singletons"
import "../../.." as Pill
import "../Format.js" as Format

Item {
    id: root

    property var mediaService: Media
    property bool scrubbing: false
    property real scrubFraction: 0

    implicitWidth: 300
    implicitHeight: content.implicitHeight + 32

    function seekToFraction(value) {
        const player = root.mediaService.player;
        if (!player || !player.canSeek || !(player.length > 0))
            return false;
        player.position = Math.max(0, Math.min(1, value)) * player.length;
        return true;
    }

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
        running: root.mediaService.player !== null && root.mediaService.playing
        onTriggered: root.mediaService.player.positionChanged()
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
            running: root.mediaService.playing
            opacity: root.mediaService.playing ? 1 : 0.55
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
                    source: root.mediaService.player
                        ? (root.mediaService.player.trackArtUrl || "") : ""
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
                    text: root.mediaService.player
                        ? (root.mediaService.player.trackTitle || "") : ""
                    elide: Text.ElideRight
                    color: Theme.onSurface
                    font.family: Theme.fontPrimary
                    font.pixelSize: Theme.fontMd
                    font.weight: Font.Bold
                }
                Text {
                    width: parent.width
                    text: root.mediaService.player
                        ? Theme.joinArtists(root.mediaService.player.trackArtists,
                            root.mediaService.player.trackArtist) : ""
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

            readonly property real length: root.mediaService.player
                && root.mediaService.player.length > 0
                ? root.mediaService.player.length : 0
            readonly property bool canSeek: root.mediaService.player
                ? root.mediaService.player.canSeek && seek.length > 0 : false
            readonly property real fraction: seek.length > 0
                ? root.scrubbing ? root.scrubFraction
                    : Math.max(0, Math.min(1,
                        root.mediaService.player.position / seek.length))
                : 0

            function fractionAt(x) {
                return Math.max(0, Math.min(1,
                    (x - progressTrack.x) / progressTrack.width));
            }

            Text {
                id: elapsed
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: Format.duration(root.scrubbing
                    ? root.scrubFraction * seek.length
                    : root.mediaService.player ? root.mediaService.player.position : 0)
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
                id: progressTrack
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
            MouseArea {
                anchors.fill: parent
                enabled: seek.canSeek
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                preventStealing: true
                onPressed: (mouse) => {
                    root.scrubbing = true;
                    root.scrubFraction = seek.fractionAt(mouse.x);
                }
                onPositionChanged: (mouse) => {
                    if (root.scrubbing)
                        root.scrubFraction = seek.fractionAt(mouse.x);
                }
                onReleased: (mouse) => {
                    root.scrubFraction = seek.fractionAt(mouse.x);
                    root.seekToFraction(root.scrubFraction);
                    root.scrubbing = false;
                }
                onCanceled: root.scrubbing = false
            }
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 8

            TransportButton {
                icon: "skip_previous"
                enabled: root.mediaService.player
                    ? root.mediaService.player.canGoPrevious : false
                onClicked: if (root.mediaService.player)
                    root.mediaService.player.previous()
            }
            TransportButton {
                icon: root.mediaService.playing ? "pause" : "play_arrow"
                primary: true
                enabled: root.mediaService.player
                    ? root.mediaService.player.canTogglePlaying : false
                onClicked: root.mediaService.toggle()
            }
            TransportButton {
                icon: "skip_next"
                enabled: root.mediaService.player
                    ? root.mediaService.player.canGoNext : false
                onClicked: if (root.mediaService.player)
                    root.mediaService.player.next()
            }
        }
    }
}
