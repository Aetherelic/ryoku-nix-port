pragma ComponentBehavior: Bound

import QtQuick
import Ryoku.Ui
import Ryoku.Ui.Singletons
import "BarStudioModel.js" as Model

// One zone of a rail: its head, then a strip per widget carrying the widget's
// name (the selection and keyboard target), reorder buttons, the destination
// zone picker with its Move action, and Remove. Up/Down on a selected name
// walks the strips; an empty zone says so instead of vanishing.
Column {
    id: root
    required property var config
    required property string edge
    required property string zone
    required property var catalog
    signal staged(var next)
    property int selected: -1

    readonly property var zones: root.edge === "top" || root.edge === "bottom" ? ["start", "center", "end"] : ["top", "center", "bottom"]
    readonly property var zoneLabels: root.zones.map(id => labels.zone(id))
    readonly property var items: root.config.rails[root.edge][root.zone]

    function select(index) {
        if (index < 0 || index >= items.length) return;
        selected = index;
        rows.itemAt(index).selectionControl.forceActiveFocus();
    }

    // a different rail's list is a different selection
    onEdgeChanged: root.selected = -1

    spacing: Tokens.s1

    CatalogLabels { id: labels }

    StripHead { width: parent.width; label: labels.zone(root.zone).toUpperCase(); count: String(root.items.length) }

    Repeater {
        id: rows
        model: root.items
        delegate: Rectangle {
            id: strip
            required property string modelData
            required property int index
            property string destination: root.zone
            property alias selectionControl: selection

            width: root.width
            height: 36
            radius: Tokens.radius
            color: root.selected === index ? Tokens.tint5 : "transparent"
            border.width: Tokens.border
            border.color: root.selected === index ? Tokens.lineStrong : Tokens.lineSoft
            Behavior on border.color { ColorAnimation { duration: Tokens.snap } }

            Btn {
                id: selection
                objectName: "widget-selection-" + index
                compact: true
                anchors { left: parent.left; leftMargin: Tokens.s2; verticalCenter: parent.verticalCenter }
                text: labels.item(strip.modelData)
                primary: root.selected === index
                onAct: root.select(index)
                Keys.onPressed: event => {
                    if (event.key !== Qt.Key_Up && event.key !== Qt.Key_Down) return;
                    root.select(index + (event.key === Qt.Key_Up ? -1 : 1));
                    event.accepted = true;
                }
            }
            Row {
                anchors { right: parent.right; rightMargin: Tokens.s2; verticalCenter: parent.verticalCenter }
                spacing: Tokens.s1
                Btn { objectName: "widget-up-" + index; compact: true; anchors.verticalCenter: parent.verticalCenter; text: qsTr("UP"); armed: index > 0; onAct: root.staged(Model.moveZoneItem(root.config, root.edge, root.zone, index, root.edge, root.zone, index - 1, root.catalog)) }
                Btn { objectName: "widget-down-" + index; compact: true; anchors.verticalCenter: parent.verticalCenter; text: qsTr("DOWN"); armed: index < root.items.length - 1; onAct: root.staged(Model.moveZoneItem(root.config, root.edge, root.zone, index, root.edge, root.zone, index + 1, root.catalog)) }
                Seg {
                    anchors.verticalCenter: parent.verticalCenter
                    options: root.zoneLabels
                    current: labels.zone(strip.destination)
                    onChose: label => strip.destination = root.zones.find(id => labels.zone(id) === label) || root.zone
                }
                Btn { objectName: "widget-move-" + index; compact: true; anchors.verticalCenter: parent.verticalCenter; text: qsTr("MOVE"); onAct: root.staged(Model.moveZoneItem(root.config, root.edge, root.zone, index, root.edge, strip.destination, root.config.rails[root.edge][strip.destination].length, root.catalog)) }
                Btn { objectName: "widget-remove-" + index; compact: true; anchors.verticalCenter: parent.verticalCenter; text: qsTr("REMOVE"); onAct: root.staged(Model.removeZoneItem(root.config, root.edge, root.zone, index)) }
            }
        }
    }

    Rectangle {
        visible: root.items.length === 0
        width: root.width
        height: 28
        radius: Tokens.radius
        color: "transparent"
        border.width: Tokens.border
        border.color: Tokens.lineSoft
        Text {
            anchors { left: parent.left; leftMargin: Tokens.s3; verticalCenter: parent.verticalCenter }
            text: qsTr("// EMPTY_")
            color: Tokens.inkFaint
            font.family: Tokens.mono
            font.pixelSize: Tokens.fTiny
            font.letterSpacing: Tokens.trackLabel
        }
    }
}
