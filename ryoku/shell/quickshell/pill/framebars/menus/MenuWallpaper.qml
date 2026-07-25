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
        radius: Theme.radius
        color: wallpaperHover.hovered ? Theme.frameBg : Theme.tileBg
        border.width: 1
        border.color: Theme.border
        Pill.GlyphIcon {
            anchors.left: parent.left
            anchors.leftMargin: 12 * root.s
            anchors.verticalCenter: parent.verticalCenter
            width: 18 * root.s
            height: 18 * root.s
            name: "image"
            color: Theme.brand
            stroke: 1.6
        }
        Text {
            anchors.left: parent.left
            anchors.leftMargin: 42 * root.s
            anchors.verticalCenter: parent.verticalCenter
            text: qsTr("Open wallpaper picker")
            color: Theme.cream
            font.family: Theme.font
            font.pixelSize: 12 * root.s
        }
        HoverHandler { id: wallpaperHover; cursorShape: Qt.PointingHandCursor }
        TapHandler {
            onTapped: {
                Quickshell.execDetached(["ryoku-shell", "wallpaper-switcher"]);
                root.requestClose();
            }
        }
    }
}
