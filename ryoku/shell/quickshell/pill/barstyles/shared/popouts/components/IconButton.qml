import QtQuick
import "../../../../Singletons"
import "../../../.." as Pill

Item {
    id: root

    property string glyph: ""
    property bool on: false
    signal clicked()

    width: 24
    height: 24

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: hover.hovered
            ? Qt.rgba(Theme.onSurface.r, Theme.onSurface.g, Theme.onSurface.b, 0.1)
            : "transparent"
    }
    Pill.MaterialIcon {
        anchors.centerIn: parent
        text: root.glyph
        font.pixelSize: 16
        color: root.on ? Theme.primary : Theme.onSurfaceVariant
    }
    HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
    TapHandler { onTapped: root.clicked() }
}
