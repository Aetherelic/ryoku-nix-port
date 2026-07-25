pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Ryoku.Ui.Singletons
import "BarStudioModel.js" as Model

ColumnLayout {
    id: root
    required property var config
    required property string menuId
    required property var path
    required property var catalog
    signal staged(var next)
    property string addition: ""

    readonly property var items: {
        let list = root.config.menus[root.menuId].widgets;
        for (let i = 0; i < root.path.length; i += 2) list = list[root.path[i]].widgets;
        return list;
    }
    spacing: Tokens.s2

    RowLayout {
        Layout.fillWidth: true
        ComboBox { id: addPick; Layout.fillWidth: true; model: root.catalog.widgetIds(); onActivated: root.addition = currentText }
        Button { text: qsTr("Add"); enabled: root.addition.length > 0; onClicked: root.staged(Model.addMenuWidget(root.config, root.menuId, root.path, root.addition, root.catalog)) }
    }
    Repeater {
        model: root.items
        delegate: RowLayout {
            required property var modelData
            required property int index
            readonly property string label: typeof modelData === "string" ? modelData : modelData.id
            Label { text: label }
            Button { text: qsTr("Up"); enabled: index > 0; onClicked: root.staged(Model.moveMenuWidget(root.config, root.menuId, root.path, index, root.path, index - 1, root.catalog)) }
            Button { text: qsTr("Down"); enabled: index < root.items.length - 1; onClicked: root.staged(Model.moveMenuWidget(root.config, root.menuId, root.path, index, root.path, index + 1, root.catalog)) }
            Button { text: qsTr("Move"); onClicked: root.staged(Model.moveMenuWidget(root.config, root.menuId, root.path, index, [], root.config.menus[root.menuId].widgets.length, root.catalog)) }
            Button { text: qsTr("Remove"); onClicked: root.staged(Model.removeMenuWidget(root.config, root.menuId, root.path, index, root.catalog)) }
        }
    }
}
