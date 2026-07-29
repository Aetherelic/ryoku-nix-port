import QtQuick
import Quickshell.Hyprland
import "../../../Singletons"

Text {
    id: root

    property real barHeight: 40
    readonly property var toplevel: Hyprland.activeToplevel
    readonly property string title: root.toplevel && root.toplevel.lastIpcObject
        ? String(root.toplevel.lastIpcObject.title || "") : ""

    width: Math.min(implicitWidth, 240)
    text: root.title.length ? root.title : "Desktop"
    color: Theme.onSurfaceVariant
    font.family: Theme.fontPrimary
    font.pixelSize: Theme.fontSm
    elide: Text.ElideRight
    maximumLineCount: 1
}
