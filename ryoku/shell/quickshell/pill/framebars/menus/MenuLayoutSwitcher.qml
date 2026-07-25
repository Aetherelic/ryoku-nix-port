pragma ComponentBehavior: Bound

import QtQuick
import "../.." as Pill
import "../../Singletons"
import "../widgets" as Widgets

Item {
    id: root

    required property real s
    required property bool open

    readonly property var layouts: layoutControl.layouts
    readonly property string current: layoutControl.current

    implicitWidth: 250 * s
    implicitHeight: col.implicitHeight

    Widgets.LayoutControl {
        id: layoutControl
        active: root.open
    }

    function choose(layout) {
        layoutControl.choose(layout)
    }

    function label(layout) {
        switch (layout) {
        case "dwindle": return qsTr("Dwindle");
        case "master": return qsTr("Master");
        case "scrolling": return qsTr("Scrolling");
        case "monocle": return qsTr("Monocle");
        }
        return layout;
    }


    Column {
        id: col
        width: root.width
        spacing: 8 * root.s

        Pill.MicroLabel { label: qsTr("Layout"); s: root.s }

        Repeater {
            model: root.layouts
            delegate: Rectangle {
                id: lrow
                required property var modelData
                readonly property bool sel: root.current === lrow.modelData
                width: col.width
                height: 38 * root.s
                radius: Theme.radius
                color: lrow.sel ? Qt.alpha(Theme.brand, 0.16) : (lHov.hovered ? Theme.frameBg : "transparent")
                border.width: 1
                border.color: lrow.sel ? Theme.brand : (lHov.hovered ? Theme.frameBorder : Theme.border)
                Behavior on color { ColorAnimation { duration: Motion.fast } }
                Behavior on border.color { ColorAnimation { duration: Motion.fast } }

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 14 * root.s
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.label(lrow.modelData)
                    color: lrow.sel ? Theme.brand : Theme.cream
                    font.family: Theme.font
                    font.pixelSize: 12.5 * root.s
                    font.weight: lrow.sel ? Font.DemiBold : Font.Medium
                }
                Pill.GlyphIcon {
                    anchors.right: parent.right
                    anchors.rightMargin: 12 * root.s
                    anchors.verticalCenter: parent.verticalCenter
                    width: 13 * root.s
                    height: 13 * root.s
                    name: "check"
                    color: Theme.brand
                    stroke: 2
                    visible: lrow.sel
                }

                HoverHandler { id: lHov; cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: root.choose(lrow.modelData) }
            }
        }
    }
}
