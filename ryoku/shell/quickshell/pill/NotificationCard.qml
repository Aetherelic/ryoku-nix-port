pragma ComponentBehavior: Bound

import QtQuick
import "Singletons"

// One notification card, shared by the history panel and the popup surface
// (contract 07 sec 2.3). A bordered surface tile with a header (app name, time,
// close), a bold summary, an optional body, and one primary button per action.
// No app icon and no image are drawn, matching the reference widget exactly.
// The card fills the width its host gives it and is sized entirely from tokens.
Rectangle {
    id: card

    required property var notif
    // Fired after an action runs; the panel closes the menu on it, the popup
    // ignores it (contract 07 sec 4.3).
    signal actionInvoked()

    radius: Theme.radiusWidget
    border.width: Theme.borderWidth
    border.color: Theme.outline
    color: Theme.surface
    implicitHeight: body.implicitHeight + Theme.paddingMd * 2

    Column {
        id: body
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Theme.paddingMd
        spacing: Theme.paddingMd

        // Header: app name (fills), arrival time, close button.
        Item {
            width: parent.width
            height: Math.max(appName.implicitHeight, timeLabel.implicitHeight, closeBtn.height)

            Text {
                id: appName
                anchors.left: parent.left
                anchors.right: timeLabel.left
                anchors.rightMargin: Theme.paddingSm
                anchors.verticalCenter: parent.verticalCenter
                text: card.notif.appName || ""
                color: Theme.onSurfaceVariant
                font.family: Theme.fontPrimary
                font.pixelSize: Theme.fontSm
                font.weight: Font.Bold
                elide: Text.ElideRight
            }

            Text {
                id: timeLabel
                anchors.right: closeBtn.left
                anchors.rightMargin: Theme.paddingSm
                anchors.verticalCenter: parent.verticalCenter
                text: Notifs.timeLabel(card.notif)
                color: Theme.onSurfaceVariant
                font.family: Theme.fontPrimary
                font.pixelSize: Theme.fontSm
            }

            Rectangle {
                id: closeBtn
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: Theme.iconSm + Theme.paddingSm * 2
                height: width
                radius: Theme.radiusWidget
                color: closeHov.hovered
                    ? Qt.tint(Theme.surface, Qt.rgba(Theme.onSurface.r, Theme.onSurface.g, Theme.onSurface.b, 0.08))
                    : "transparent"

                MaterialIcon {
                    anchors.centerIn: parent
                    text: "close"
                    font.pixelSize: Theme.iconSm
                    color: closeHov.hovered ? Theme.onSurface : Theme.onSurfaceVariant
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Notifs.dismiss(card.notif)
                    HoverHandler { id: closeHov }
                }
            }
        }

        // Summary: bold, wraps.
        Text {
            width: parent.width
            text: card.notif.summary || ""
            color: Theme.onSurface
            font.family: Theme.fontPrimary
            font.pixelSize: Theme.fontMd
            font.weight: Font.Bold
            wrapMode: Text.WrapAtWordBoundaryOrAnywhere
        }

        // Body: only when present.
        Text {
            width: parent.width
            visible: (card.notif.body || "").length > 0
            text: card.notif.body || ""
            color: Theme.onSurfaceVariant
            font.family: Theme.fontPrimary
            font.pixelSize: Theme.fontSm
            wrapMode: Text.WrapAtWordBoundaryOrAnywhere
        }

        // Actions: one primary button per action, full width (contract 07 sec 2.3).
        Column {
            width: parent.width
            spacing: Theme.paddingSm
            visible: card.notif.actions && card.notif.actions.length > 0

            Repeater {
                model: card.notif.actions

                delegate: Rectangle {
                    id: actionBtn
                    required property var modelData

                    width: parent.width
                    height: actionLabel.implicitHeight + Theme.paddingSm * 2
                    radius: Theme.radiusWidget
                    color: actionHov.hovered ? Theme.vermLit : Theme.primary

                    Behavior on color { ColorAnimation { duration: Motion.rowFade; easing.type: Motion.easeType; easing.bezierCurve: Motion.easeCurve } }

                    Text {
                        id: actionLabel
                        anchors.centerIn: parent
                        width: parent.width - Theme.paddingMd * 2
                        horizontalAlignment: Text.AlignHCenter
                        text: actionBtn.modelData.text
                        color: Theme.onPrimary
                        font.family: Theme.fontPrimary
                        font.pixelSize: Theme.fontSm
                        font.weight: Font.Bold
                        elide: Text.ElideRight
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            actionBtn.modelData.invoke();
                            card.actionInvoked();
                        }
                        HoverHandler { id: actionHov }
                    }
                }
            }
        }
    }
}
