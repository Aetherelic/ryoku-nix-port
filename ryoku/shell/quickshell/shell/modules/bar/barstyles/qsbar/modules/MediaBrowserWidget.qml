import QtQuick
import Quickshell
import Ryoku.Ui.Singletons

// Combined screenshots/videos browser launcher.
// Left-click = screenshots, right-click = videos. Sits left of the theme icon.
Item {
    id: rootMod
    required property var root
    property var screen: null
    readonly property color contentColor: root.widgetContentColor("G10", root.widgetIconColor)

    // The Media toggle existed in Settings and drove nothing: this widget always
    // took its cell. It is the widget's own switch, so it gates the width.
    visible: implicitWidth > 0.5
    implicitWidth: root.modMedia ? root.v2ActionIconCellWidth : 0
    implicitHeight: 28

    IconText {
        anchors.centerIn: parent
        text: "collections"
        font.pixelSize: 14
        font.weight: Font.Normal
        color: root.mediaBrowserVisible
            ? (root.widgetHasFill("G10") ? rootMod.contentColor : root.seal)
            : rootMod.contentColor
        Behavior on color { ColorAnimation { duration: 150 } }
    }

    TooltipMixin {
        id: tip; root: rootMod.root; owner: rootMod
        text: I18n.tr("L: Screenshots  R: Videos")
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onEntered: tip.show()
        onExited:  tip.hide()
        // Opening goes through Theme.openMediaBrowser, the same path the picker
        // IPC and keybinds use. This used to hand-roll the sequence and pick the
        // popup screen itself, which left the panel gated shut on click while the
        // IPC path opened it fine.
        onClicked: function(mouse) {
            tip.hide()
            if (root.mediaBrowserVisible) {
                root.mediaBrowserVisible = false
                return
            }
            root.openMediaBrowser(mouse.button === Qt.RightButton ? "videos" : "screenshots")
        }
    }
}
