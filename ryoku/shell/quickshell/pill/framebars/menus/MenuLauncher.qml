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
        radius: Theme.radius
        color: launchHover.hovered ? Theme.frameBg : Theme.tileBg
        border.width: 1
        border.color: Theme.border

        Pill.GlyphIcon {
            anchors {
                left: parent.left
                verticalCenter: parent.verticalCenter
                leftMargin: 12 * root.s
            }
            width: 18 * root.s
            height: 18 * root.s
            name: "search"
            color: Theme.iconDim
            stroke: 1.6
        }
        Text {
            anchors {
                left: parent.left
                verticalCenter: parent.verticalCenter
                leftMargin: 42 * root.s
            }
            text: qsTr("Search apps and actions")
            color: Theme.dim
            font.family: Theme.font
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
