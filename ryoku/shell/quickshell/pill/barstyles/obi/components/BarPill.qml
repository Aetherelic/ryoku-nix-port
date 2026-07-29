import QtQuick
import "../../../Singletons"

// One Obi pill: a rounded surface group that hugs its content in a centred row,
// mirroring iNiR's BarGroup. Widgets dropped inside lay out left to right.
Item {
    id: root

    default property alias content: row.data
    property real spacing: 8
    property real padding: 10
    property real minHeight: 32
    readonly property bool empty: row.implicitWidth < 1

    implicitWidth: root.empty ? 0 : row.implicitWidth + root.padding * 2
    implicitHeight: root.minHeight
    visible: !root.empty

    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusWidget
        color: Theme.surface
        border.width: Theme.borderWidth
        border.color: Theme.outline
        opacity: Theme.windowOpacity
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: root.spacing
    }
}
