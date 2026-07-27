pragma ComponentBehavior: Bound

import QtQuick
import "../../Singletons"

// The `.weather-container` page body of the weather widget (contract 08 sec 2.4):
// a bordered surface card, radius-widget, border-width outline, 8 px padding,
// with a bold title above vertically stacked content. Used by the Current,
// Hourly and Daily pages.
Item {
    id: root

    property real s: 1
    property string title: ""

    default property alias content: body.data

    implicitWidth: frame.width
    implicitHeight: frame.implicitHeight

    Rectangle {
        id: frame
        width: root.width
        radius: Theme.radiusWidget
        color: "transparent"
        border.width: Theme.borderWidth
        border.color: Theme.outline
        implicitHeight: stack.implicitHeight + 2 * (Theme.paddingMd * root.s)

        Column {
            id: stack
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Theme.paddingMd * root.s
            spacing: 8 * root.s

            Text {
                text: root.title
                color: Theme.inkOn(Theme.effectiveSurface, Theme.onSurface)
                font.family: Theme.fontPrimary
                font.pixelSize: Theme.fontLg * root.s
                font.weight: Font.Bold
            }

            Column {
                id: body
                width: parent.width
                spacing: 8 * root.s
            }
        }
    }
}
