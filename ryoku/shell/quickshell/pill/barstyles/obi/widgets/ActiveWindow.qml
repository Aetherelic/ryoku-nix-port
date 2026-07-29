import QtQuick
import Quickshell.Hyprland
import "../../../Singletons"

// Obi active-window title: the focused window's title, elided. Falls back to a
// neutral label on an empty workspace.
Text {
    id: root

    readonly property var tl: Hyprland.activeToplevel
    readonly property string title: (root.tl && root.tl.lastIpcObject && root.tl.lastIpcObject.title)
        ? String(root.tl.lastIpcObject.title) : ""

    width: Math.min(implicitWidth, 260)
    text: root.title.length > 0 ? root.title : "Desktop"
    color: Theme.onSurfaceVariant
    font.family: Theme.fontPrimary
    font.pixelSize: Theme.fontSm
    elide: Text.ElideRight
    maximumLineCount: 1
}
