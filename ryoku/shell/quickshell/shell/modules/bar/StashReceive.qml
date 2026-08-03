pragma ComponentBehavior: Bound

import QtQuick
import "../../services"
import "../../components"

/**
 * LocalSend receive sheet. while it's up the shell runs a LocalSend server
 * that announces on the LAN and drops anything pushed at it into the stash.
 * shows the name other devices see, a live tally of what arrived, and a
 * Stop. server + state live in the Stash singleton, this only paints the
 * waiting room.
 */
Rectangle {
    id: root

    property real s: 1

    readonly property bool active: Stash.recvState !== "idle"

    radius: Motion.rTile * s
    color: Qt.alpha(Theme.surfaceContainer, 0.98)
    visible: active

    MouseArea { anchors.fill: parent; hoverEnabled: true }

    Column {
        visible: Stash.recvState !== "prompt"
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -8 * root.s
        width: parent.width - 48 * root.s
        spacing: 14 * root.s

        // broadcasting halo around the receive glyph.
        Item {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 64 * root.s
            height: 64 * root.s

            Repeater {
                model: 2
                Rectangle {
                    required property int index
                    anchors.centerIn: parent
                    width: 28 * root.s
                    height: 28 * root.s
                    radius: width / 2
                    color: "transparent"
                    border.width: 1.5 * root.s
                    border.color: Theme.flameGlow
                    SequentialAnimation on opacity {
                        running: root.active
                        loops: Animation.Infinite
                        PauseAnimation { duration: index * 700 }
                        NumberAnimation { from: 0.5; to: 0; duration: 1400; easing.type: Easing.OutCubic }
                        PauseAnimation { duration: (1 - index) * 700 }
                    }
                    SequentialAnimation on scale {
                        running: root.active
                        loops: Animation.Infinite
                        PauseAnimation { duration: index * 700 }
                        NumberAnimation { from: 0.7; to: 2.2; duration: 1400; easing.type: Easing.OutCubic }
                        PauseAnimation { duration: (1 - index) * 700 }
                    }
                }
            }

            Rectangle {
                anchors.centerIn: parent
                width: 44 * root.s
                height: 44 * root.s
                radius: width / 2
                color: Qt.alpha(Theme.flameGlow, 0.14)
                border.width: 1
                border.color: Qt.alpha(Theme.flameGlow, 0.5)

                GlyphIcon {
                    anchors.centerIn: parent
                    width: 22 * root.s; height: 22 * root.s
                    name: "hotspot"
                    color: Theme.flameGlow
                    stroke: 1.7
                }
            }
        }

        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 3 * root.s

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Listening as " + (Stash.recvAlias.length > 0 ? Stash.recvAlias : "Ryoku Stash")
                color: Theme.onSurface
                font.family: Theme.fontPrimary
                font.pixelSize: 12 * root.s
                font.weight: Font.DemiBold
                textFormat: Text.PlainText
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Stash.recvCount > 0
                    ? ("Received " + Stash.recvCount + (Stash.recvCount === 1 ? " file" : " files"))
                    : "Other devices can send files here"
                color: Stash.recvCount > 0 ? Theme.flameGlow : Theme.onSurfaceVariant
                font.family: Theme.fontPrimary
                font.pixelSize: 9.5 * root.s
                font.weight: Font.Medium
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: Stash.recvLast.length > 0
                text: "↓ " + Stash.recvLast
                color: Theme.onSurfaceVariant
                font.family: Theme.fontPrimary
                font.pixelSize: 9 * root.s
                elide: Text.ElideMiddle
                width: root.width - 60 * root.s
                horizontalAlignment: Text.AlignHCenter
                maximumLineCount: 1
                textFormat: Text.PlainText
            }
        }

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: stopRow.implicitWidth + 28 * root.s
            height: 30 * root.s
            radius: Motion.rSmall * root.s
            color: stopArea.containsMouse ? Theme.frameBg : Theme.surfaceContainerHigh
            border.width: 1
            border.color: stopArea.containsMouse ? Theme.frameBorder : Theme.outline
            Behavior on color { ColorAnimation { duration: Motion.fast } }

            Row {
                id: stopRow
                anchors.centerIn: parent
                spacing: 6 * root.s
                GlyphIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 12 * root.s; height: 12 * root.s
                    name: "close"
                    color: stopArea.containsMouse ? Theme.onSurface : Theme.onSurfaceVariant
                    stroke: 1.7
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Stop listening"
                    color: stopArea.containsMouse ? Theme.onSurface : Theme.onSurfaceVariant
                    font.family: Theme.fontPrimary
                    font.pixelSize: 10.5 * root.s
                    font.weight: Font.DemiBold
                }
            }
            MouseArea {
                id: stopArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Stash.stopReceive()
            }
        }
    }

    // incoming-transfer consent: sender's prepare-upload sits server-side until
    // Accept/Decline answers here. nothing has transferred yet.
    Column {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -8 * root.s
        width: parent.width - 48 * root.s
        spacing: 16 * root.s
        visible: Stash.recvState === "prompt"

        Item {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 44 * root.s
            height: 44 * root.s
            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: Qt.alpha(Theme.flameGlow, 0.14)
                border.width: 1
                border.color: Qt.alpha(Theme.flameGlow, 0.5)
            }
            GlyphIcon {
                anchors.centerIn: parent
                width: 22 * root.s; height: 22 * root.s
                name: "inbox"
                color: Theme.flameGlow
                stroke: 1.7
            }
        }

        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 3 * root.s
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                width: root.width - 56 * root.s
                text: (Stash.offerAlias.length > 0 ? Stash.offerAlias : "A device") + " wants to send"
                color: Theme.onSurface
                font.family: Theme.fontPrimary
                font.pixelSize: 12 * root.s
                font.weight: Font.DemiBold
                textFormat: Text.PlainText
                elide: Text.ElideRight
                horizontalAlignment: Text.AlignHCenter
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Stash.offerCount + (Stash.offerCount === 1 ? " file" : " files")
                color: Theme.flameGlow
                font.family: Theme.fontPrimary
                font.pixelSize: 10 * root.s
                font.weight: Font.Medium
            }
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 10 * root.s

            Rectangle {
                width: declineRow.implicitWidth + 24 * root.s
                height: 30 * root.s
                radius: Motion.rSmall * root.s
                color: declineArea.containsMouse ? Theme.frameBg : Theme.surfaceContainerHigh
                border.width: 1
                border.color: declineArea.containsMouse ? Theme.frameBorder : Theme.outline
                Behavior on color { ColorAnimation { duration: Motion.fast } }
                Row {
                    id: declineRow
                    anchors.centerIn: parent
                    spacing: 6 * root.s
                    GlyphIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 12 * root.s; height: 12 * root.s
                        name: "close"
                        color: declineArea.containsMouse ? Theme.onSurface : Theme.onSurfaceVariant
                        stroke: 1.7
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Decline"
                        color: declineArea.containsMouse ? Theme.onSurface : Theme.onSurfaceVariant
                        font.family: Theme.fontPrimary
                        font.pixelSize: 10.5 * root.s
                        font.weight: Font.DemiBold
                    }
                }
                MouseArea {
                    id: declineArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Stash.declineIncoming()
                }
            }

            Rectangle {
                width: acceptRow.implicitWidth + 24 * root.s
                height: 30 * root.s
                radius: Motion.rSmall * root.s
                color: acceptArea.containsMouse ? Qt.alpha(Theme.flameGlow, 0.3) : Qt.alpha(Theme.flameGlow, 0.16)
                border.width: 1
                border.color: Qt.alpha(Theme.flameGlow, 0.6)
                Behavior on color { ColorAnimation { duration: Motion.fast } }
                Row {
                    id: acceptRow
                    anchors.centerIn: parent
                    spacing: 6 * root.s
                    GlyphIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 12 * root.s; height: 12 * root.s
                        name: "check"
                        color: Theme.flameGlow
                        stroke: 1.9
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Accept"
                        color: Theme.onSurface
                        font.family: Theme.fontPrimary
                        font.pixelSize: 10.5 * root.s
                        font.weight: Font.DemiBold
                    }
                }
                MouseArea {
                    id: acceptArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Stash.acceptIncoming()
                }
            }
        }
    }
}
