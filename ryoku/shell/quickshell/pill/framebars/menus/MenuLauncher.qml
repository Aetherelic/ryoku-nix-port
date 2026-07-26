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
        height: 42 * root.s
        radius: Theme.radiusWidget
        color: launchHover.hovered ? Theme.frameBg : Theme.surfaceContainerHigh
        border.width: 1
        border.color: Theme.outline

        Pill.GlyphIcon {
            anchors {
                left: parent.left
                verticalCenter: parent.verticalCenter
                leftMargin: 12 * root.s
            }
            width: 18 * root.s
            height: 18 * root.s
            name: "search"
            color: Theme.onSurfaceVariant
            stroke: 1.6
        }
        Text {
            anchors {
                left: parent.left
                verticalCenter: parent.verticalCenter
                leftMargin: 42 * root.s
            }
            text: qsTr("Search apps and actions")
            color: Theme.onSurfaceVariant
            font.family: Theme.fontPrimary
            font.pixelSize: 12 * root.s
        }
        HoverHandler { id: launchHover; cursorShape: Qt.PointingHandCursor }
        TapHandler {
            onTapped: {
                Quickshell.execDetached(["ryoku-shell", "launcher"]);
                root.requestClose();
            }
        }
    }
}
