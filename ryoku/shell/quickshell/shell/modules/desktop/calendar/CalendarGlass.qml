import QtQuick
import "../Singletons"

Rectangle {
    id: root

    property bool hovered: false
    property real s: 1

    radius: Theme.radiusWidget * root.s
    color: Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b, root.hovered ? 0.92 : 0.78)
    border.width: 1
    border.color: root.hovered ? Theme.lineStrong : Theme.line

    Behavior on color { ColorAnimation { duration: Theme.quick } }
    Behavior on border.color { ColorAnimation { duration: Theme.quick } }

    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        color: "transparent"
        gradient: Gradient {
            GradientStop { position: 0; color: Qt.rgba(Theme.ink.r, Theme.ink.g, Theme.ink.b, root.hovered ? 0.09 : 0.05) }
            GradientStop { position: 0.5; color: "transparent" }
            GradientStop { position: 1; color: Qt.rgba(Theme.cardBot.r, Theme.cardBot.g, Theme.cardBot.b, 0.08) }
        }
    }
}
