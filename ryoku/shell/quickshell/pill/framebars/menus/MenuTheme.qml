import QtQuick
import Quickshell
import "../.." as Pill
import "../../Singletons"

Item {
    id: root

    required property real s
    required property bool open
    signal requestClose()

    implicitWidth: 320 * s
    implicitHeight: button.height

    Rectangle {
        id: button
        width: parent.width
        height: 46 * root.s
        radius: Theme.radiusWidget
        color: themeHover.hovered ? Theme.frameBg : Theme.surfaceContainerHigh
        border.width: 1
        border.color: Theme.outline
        Pill.GlyphIcon {
            anchors.left: parent.left
            anchors.leftMargin: 12 * root.s
            anchors.verticalCenter: parent.verticalCenter
            width: 18 * root.s
            height: 18 * root.s
            name: "palette"
            color: Theme.primary
            stroke: 1.6
        }
        Text {
            anchors.left: parent.left
            anchors.leftMargin: 42 * root.s
            anchors.verticalCenter: parent.verticalCenter
            text: qsTr("Choose wallpaper and theme")
            color: Theme.onSurface
            font.family: Theme.fontPrimary
            font.pixelSize: 12 * root.s
        }
        HoverHandler { id: themeHover; cursorShape: Qt.PointingHandCursor }
        TapHandler {
            onTapped: {
                Quickshell.execDetached(["ryoku-shell", "wallpaper-switcher"]);
                root.requestClose();
            }
        }
    }
}
