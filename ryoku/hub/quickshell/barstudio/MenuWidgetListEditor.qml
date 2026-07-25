pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Ryoku.Ui
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
    property int selected: -1
    function select(index) {
        if (index < 0 || index >= items.length) return;
        selected = index;
        rows.itemAt(index).selectionControl.forceActiveFocus();
    }


    readonly property var items: {
        let list = root.config.menus[root.menuId].widgets;
        for (let i = 0; i < root.path.length; i += 2) list = list[root.path[i]].widgets;
        return list;
    }
    readonly property var widgetIds: root.catalog.widgetIds()
    readonly property var widgetLabels: root.widgetIds.map(id => labels.item(id))
    spacing: Tokens.s2

    CatalogLabels { id: labels }

    RowLayout {
        Layout.fillWidth: true
        Chips {
            Layout.fillWidth: true
            options: root.widgetLabels
            current: labels.item(root.addition)
            onChose: label => root.addition = root.widgetIds.find(id => labels.item(id) === label) || ""
        }
        Btn { text: qsTr("Add"); armed: root.addition.length > 0; onAct: root.staged(Model.addMenuWidget(root.config, root.menuId, root.path, root.addition, root.catalog)) }
    }
    Repeater {
        id: rows
        model: root.items
        delegate: RowLayout {
            required property var modelData
            required property int index
            readonly property string itemId: typeof modelData === "string" ? modelData : modelData.id
            property alias selectionControl: selection
            Btn {
                id: selection
                objectName: "menu-widget-selection-" + index
                text: labels.item(itemId)
                primary: root.selected === index
                onAct: root.select(index)
                onNavigation: key => root.select(index + (key === Qt.Key_Up ? -1 : 1))
            }
            Btn { objectName: "menu-widget-up-" + index; text: qsTr("Up"); armed: index > 0; onAct: root.staged(Model.moveMenuWidget(root.config, root.menuId, root.path, index, root.path, index - 1, root.catalog)) }
            Btn { objectName: "menu-widget-down-" + index; text: qsTr("Down"); armed: index < root.items.length - 1; onAct: root.staged(Model.moveMenuWidget(root.config, root.menuId, root.path, index, root.path, index + 1, root.catalog)) }
            Btn { objectName: "menu-widget-move-" + index; text: qsTr("Move"); onAct: root.staged(Model.moveMenuWidget(root.config, root.menuId, root.path, index, [], root.config.menus[root.menuId].widgets.length, root.catalog)) }
            Btn { objectName: "menu-widget-remove-" + index; text: qsTr("Remove"); onAct: root.staged(Model.removeMenuWidget(root.config, root.menuId, root.path, index)) }
        }
    }
}