pragma ComponentBehavior: Bound

import QtQuick
import "../.." as Pill
import "../../Singletons"

Item {
    id: root

    required property real s
    required property bool open

    implicitWidth: 260 * s
    implicitHeight: col.implicitHeight

    onOpenChanged: PowerProfiles.setActive(root, root.open)
    Component.onCompleted: PowerProfiles.setActive(root, root.open)
    Component.onDestruction: PowerProfiles.setActive(root, false)

    function label(name) {
        switch (name) {
        case "power-saver": return qsTr("Power Saver");
        case "balanced": return qsTr("Balanced");
        case "performance": return qsTr("Performance");
        }
        return name;
    }

    function glyph(name) {
        switch (name) {
        case "power-saver": return "eco";
        case "performance": return "bolt";
        }
        return "balance";
    }

    Column {
        id: col
        width: root.width
        spacing: 8 * root.s

        Pill.MicroLabel { label: qsTr("Power Profile"); s: root.s }

        Text {
            width: parent.width
            visible: !PowerProfiles.available
            text: qsTr("Power profiles unavailable")
            color: Theme.onSurfaceVariant
            font.family: Theme.fontPrimary
            font.pixelSize: 12 * root.s
            font.weight: Font.Medium
        }

        Repeater {
            model: PowerProfiles.available ? PowerProfiles.profiles : []
            delegate: Rectangle {
                id: prow
                required property var modelData
                readonly property bool sel: PowerProfiles.profile === prow.modelData
                width: col.width
                height: 40 * root.s
                radius: Theme.radiusWidget
                color: prow.sel ? Qt.alpha(Theme.primary, 0.16) : (pHov.hovered ? Theme.frameBg : "transparent")
                border.width: 1
                border.color: prow.sel ? Theme.primary : (pHov.hovered ? Theme.frameBorder : Theme.outline)
                Behavior on color { ColorAnimation { duration: Motion.fast } }
                Behavior on border.color { ColorAnimation { duration: Motion.fast } }

                Pill.MaterialIcon {
                    id: pIcon
                    anchors.left: parent.left
                    anchors.leftMargin: 12 * root.s
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.glyph(prow.modelData)
                    fill: prow.sel ? 1 : 0
                    color: prow.sel ? Theme.primary : Theme.onSurfaceVariant
                    font.pixelSize: 17 * root.s
                }
                Text {
                    anchors.left: pIcon.right
                    anchors.leftMargin: 10 * root.s
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.label(prow.modelData)
                    color: prow.sel ? Theme.primary : Theme.onSurface
                    font.family: Theme.fontPrimary
                    font.pixelSize: 12.5 * root.s
                    font.weight: prow.sel ? Font.DemiBold : Font.Medium
                }
                Pill.GlyphIcon {
                    anchors.right: parent.right
                    anchors.rightMargin: 12 * root.s
                    anchors.verticalCenter: parent.verticalCenter
                    width: 13 * root.s
                    height: 13 * root.s
                    name: "check"
                    color: Theme.primary
                    stroke: 2
                    visible: prow.sel
                }

                HoverHandler { id: pHov; cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: PowerProfiles.setProfile(prow.modelData) }
            }
        }
    }
}
