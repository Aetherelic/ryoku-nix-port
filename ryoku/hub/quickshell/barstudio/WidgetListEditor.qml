pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Ryoku.Ui
import Ryoku.Ui.Singletons
import "BarStudioModel.js" as Model

ColumnLayout {
    id: root
    required property var config
    required property string edge
    required property string zone
    required property var catalog
    readonly property var zones: root.edge === "top" || root.edge === "bottom" ? ["start", "center", "end"] : ["top", "center", "bottom"]
    readonly property var zoneLabels: root.zones.map(id => labels.zone(id))
    signal staged(var next)
    property int selected: -1
    function select(index) {
        if (index < 0 || index >= items.length) return;
        selected = index;
        rows.itemAt(index).selectionControl.forceActiveFocus();
    }


    readonly property var items: root.config.rails[root.edge][root.zone]
    spacing: Tokens.s2

    CatalogLabels { id: labels }

    Text { text: qsTr("%1 zone").arg(labels.zone(root.zone)); font.family: Tokens.ui }
    Repeater {
        id: rows
        model: root.items
        delegate: RowLayout {
            required property string modelData
            required property int index
            property string destination: root.zone
            property alias selectionControl: selection

            Btn {
                id: selection
                objectName: "widget-selection-" + index
                text: labels.item(modelData)
                primary: root.selected === index
                onAct: root.select(index)
                onNavigation: key => root.select(index + (key === Qt.Key_Up ? -1 : 1))
            }
            Btn { objectName: "widget-up-" + index; text: qsTr("Up"); armed: index > 0; onAct: root.staged(Model.moveZoneItem(root.config, root.edge, root.zone, index, root.edge, root.zone, index - 1, root.catalog)) }
            Btn { objectName: "widget-down-" + index; text: qsTr("Down"); armed: index < root.items.length - 1; onAct: root.staged(Model.moveZoneItem(root.config, root.edge, root.zone, index, root.edge, root.zone, index + 1, root.catalog)) }
            Seg {
                options: root.zoneLabels
                current: labels.zone(destination)
                onChose: label => destination = root.zones.find(id => labels.zone(id) === label) || root.zone
            }
            Btn { objectName: "widget-move-" + index; text: qsTr("Move"); onAct: root.staged(Model.moveZoneItem(root.config, root.edge, root.zone, index, root.edge, destination, root.config.rails[root.edge][destination].length, root.catalog)) }
            Btn { objectName: "widget-remove-" + index; text: qsTr("Remove"); onAct: root.staged(Model.removeZoneItem(root.config, root.edge, root.zone, index)) }
        }
    }
}