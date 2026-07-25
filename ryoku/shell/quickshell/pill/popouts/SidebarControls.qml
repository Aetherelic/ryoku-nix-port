import QtQuick
import ".."
import "../framebars/menus" as Menus

Column {
    id: root

    required property real s
    required property bool open
    signal dismiss()
    signal clipboardRequested()

    spacing: 14 * root.s

    DeckControls {
        width: parent.width
        s: root.s
        active: root.open
    }

    DeckTools {
        width: parent.width
        s: root.s
        onRequestClose: root.dismiss()
        onClipboardRequested: root.clipboardRequested()
    }

    Menus.MenuVolumeFader {
        width: parent.width
        s: root.s
        open: root.open
    }

    BrightnessControl {
        width: parent.width
        s: root.s
        active: root.open
    }
}
