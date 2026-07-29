pragma ComponentBehavior: Bound

import QtQuick
import "../../../Singletons"
import "../components" as C
import "../../.." as Pill

// Obi media chip: a small rounded album thumbnail and an elided "title · artist"
// line. Hovering opens a now-playing control card with larger art, a seek line,
// and prev/play/next transport. Self-hides until a real player reports a track.
Item {
    id: root

    implicitWidth: rowr.implicitWidth
    implicitHeight: 26
    visible: Media.present

    // Claim the shared cava feed only while the chip is shown, like the rail
    // music widget, so a playerless desktop never runs the analyser.
    onVisibleChanged: AudioBars.setActive(root, visible)
    Component.onCompleted: AudioBars.setActive(root, visible)
    Component.onDestruction: AudioBars.setActive(root, false)

    function fmtTime(sec) {
        sec = Math.max(0, Math.floor(sec));
        var m = Math.floor(sec / 60);
        var r = sec % 60;
        return m + ":" + (r < 10 ? "0" : "") + r;
    }

    HoverHandler { id: hh }

    Row {
        id: rowr
        anchors.centerIn: parent
        spacing: 8

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 22
            height: 22
            radius: 6
            clip: true
            color: Qt.rgba(Theme.onSurface.r, Theme.onSurface.g, Theme.onSurface.b, 0.08)

            Image {
                id: art
                anchors.fill: parent
                source: Media.player ? (Media.player.trackArtUrl || "") : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
            }

            Pill.MaterialIcon {
                anchors.centerIn: parent
                text: "music_note"
                font.pixelSize: Theme.iconSm
                color: Theme.onSurfaceVariant
                visible: art.status !== Image.Ready || art.source === ""
            }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            width: 160
            text: Media.line
            elide: Text.ElideRight
            color: Theme.onSurface
            font.family: Theme.fontPrimary
            font.pixelSize: Theme.fontSm
        }

        Pill.MusicBars {
            anchors.verticalCenter: parent.verticalCenter
            orient: "vertical"
            bands: 9
            s: 1.1
            width: 32
            height: 16
            running: Media.playing
            opacity: Media.playing ? 1 : 0.5
            Behavior on opacity { NumberAnimation { duration: Motion.standard; easing.type: Motion.easeStandard } }
        }
    }

    C.Popout {
        target: root
        targetHovered: hh.hovered
        content: popContent
    }

    Component {
        id: popContent
        Item {
            implicitWidth: 300
            implicitHeight: col.implicitHeight + 32

            component XportBtn: Item {
                id: tbtn
                property string icon: ""
                property bool primary: false
                signal clicked()

                width: 40
                height: 40

                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: tbtn.primary
                        ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, ma.containsMouse ? 0.22 : 0.14)
                        : ma.containsMouse ? Qt.rgba(Theme.onSurface.r, Theme.onSurface.g, Theme.onSurface.b, 0.08)
                        : "transparent"
                }

                Pill.MaterialIcon {
                    anchors.centerIn: parent
                    text: tbtn.icon
                    font.pixelSize: tbtn.primary ? Theme.iconMd : 20
                    fill: tbtn.primary ? 1 : 0
                    color: !tbtn.enabled
                        ? Qt.rgba(Theme.onSurface.r, Theme.onSurface.g, Theme.onSurface.b, 0.3)
                        : tbtn.primary ? Theme.primary : Theme.onSurface
                }

                MouseArea {
                    id: ma
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: tbtn.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: tbtn.clicked()
                }
            }

            // Keep the seek line live while the card is open.
            Timer {
                interval: 500
                repeat: true
                running: Media.player !== null && Media.playing
                onTriggered: Media.player.positionChanged()
            }

            Column {
                id: col
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
                    Behavior on opacity { NumberAnimation { duration: Motion.standard; easing.type: Motion.easeStandard } }
                }

                Row {
                    width: parent.width
                    spacing: 12

                    Rectangle {
                        id: popArt
                        width: 64
                        height: 64
                        radius: 10
                        clip: true
                        color: Qt.rgba(Theme.onSurface.r, Theme.onSurface.g, Theme.onSurface.b, 0.08)

                        Image {
                            id: popArtImg
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
                            visible: popArtImg.status !== Image.Ready || popArtImg.source === ""
                        }
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - popArt.width - parent.spacing
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

                // Seek: elapsed | 3px track | total
                Item {
                    id: seek
                    width: parent.width
                    height: 16

                    readonly property real len: (Media.player && Media.player.length > 0) ? Media.player.length : 0
                    readonly property real frac: seek.len > 0 ? Math.max(0, Math.min(1, Media.player.position / seek.len)) : 0

                    Text {
                        id: elapsed
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.fmtTime(Media.player ? Media.player.position : 0)
                        color: Theme.onSurfaceVariant
                        font.family: Theme.mono
                        font.pixelSize: Theme.fontSm - 2
                    }
                    Text {
                        id: total
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.fmtTime(seek.len)
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
                            width: parent.width * seek.frac
                            height: parent.height
                            radius: parent.radius
                            color: Theme.primary
                        }
                    }
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 8

                    XportBtn {
                        icon: "skip_previous"
                        enabled: Media.player ? Media.player.canGoPrevious : false
                        onClicked: if (Media.player) Media.player.previous()
                    }
                    XportBtn {
                        icon: Media.playing ? "pause" : "play_arrow"
                        primary: true
                        enabled: Media.player ? Media.player.canTogglePlaying : false
                        onClicked: Media.toggle()
                    }
                    XportBtn {
                        icon: "skip_next"
                        enabled: Media.player ? Media.player.canGoNext : false
                        onClicked: if (Media.player) Media.player.next()
                    }
                }
            }
        }
    }
}
