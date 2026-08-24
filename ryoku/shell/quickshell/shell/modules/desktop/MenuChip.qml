pragma ComponentBehavior: Bound
import QtQuick
import "Singletons"
import Ryoku.Ui.Singletons

// A selectable chip: an option in a choice group, a style swatch, a snap-zone
// target. Selected = a bone plate carrying dark ink (inversion, never a tint),
// a quiet tile wash on hover, a press dip. The studio selection idiom. A label
// covers the common case; a caller that needs a glyph fills the default
// content slot and binds to `contentColor` / `hovered`.
Item {
    id: chip

    property string label: ""
    property bool selected: false
    property real minWidth: 0

    signal clicked()

    // for custom (glyph) content that must track the chip's state.
    readonly property bool hovered: ma.containsMouse
    readonly property color contentColor: chip.selected ? Theme.inkOnBone
        : (ma.containsMouse ? Theme.ink : Theme.inkDim)

    default property alias content: hold.data

    implicitWidth: Math.max(chip.minWidth, lbl.implicitWidth + Theme.s5)
    implicitHeight: Theme.ctlH

    scale: ma.pressed ? 0.94 : 1
    Behavior on scale { NumberAnimation { duration: Theme.quick; easing.type: Theme.ease } }

    Rectangle {
        anchors.fill: parent
        radius: Theme.menuTileRadius
        color: chip.selected ? Theme.bone
            : ma.pressed ? Theme.tilePress
            : ma.containsMouse ? Theme.tileHover : Theme.tile
        border.width: 1
        border.color: chip.selected ? Theme.bone : Theme.line
        Behavior on color { ColorAnimation { duration: Theme.quick } }
    }

    Text {
        id: lbl
        visible: chip.label.length > 0
        anchors.centerIn: parent
        text: I18n.tr(chip.label)
        color: chip.contentColor
        font.family: Theme.font
        font.pixelSize: Theme.fSmall
        font.weight: chip.selected ? Font.DemiBold : Font.Medium
        Behavior on color { ColorAnimation { duration: Theme.quick } }
    }

    Item { id: hold; anchors.fill: parent }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: chip.clicked()
    }
}
