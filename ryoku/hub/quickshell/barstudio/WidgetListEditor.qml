pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Ryoku.Ui.Singletons
import "BarStudioModel.js" as Model

ColumnLayout {
    id: root
    required property var config
    required property string edge
    required property string zone
    required property var catalog
    readonly property var zones: root.edge === "top" || root.edge === "bottom" ? ["start", "center", "end"] : ["top", "center", "bottom"]
    signal staged(var next)
    property int selected: -1

    readonly property var items: root.config.rails[root.edge][root.zone]
    spacing: Tokens.s2

    Label { text: qsTr("%1 zone").arg(root.zone); font: Tokens.ui }
    Repeater {
        model: root.items
        delegate: RowLayout {
            Button { text: modelData; checkable: true; checked: root.selected === index; onClicked: root.selected = index }
            Button { text: qsTr("Up"); enabled: index > 0; onClicked: root.staged(Model.moveZoneItem(root.config, root.edge, root.zone, index, root.edge, root.zone, index - 1, root.catalog)) }
            Button { text: qsTr("Down"); enabled: index < root.items.length - 1; onClicked: root.staged(Model.moveZoneItem(root.config, root.edge, root.zone, index, root.edge, root.zone, index + 1, root.catalog)) }
            ComboBox { id: target; model: root.zones }
            Button { text: qsTr("Move"); onClicked: root.staged(Model.moveZoneItem(root.config, root.edge, root.zone, index, root.edge, target.currentText, root.config.rails[root.edge][target.currentText].length, root.catalog)) }
            Button { text: qsTr("Remove"); onClicked: root.staged(Model.removeZoneItem(root.config, root.edge, root.zone, index)) }
        }
    }
}
