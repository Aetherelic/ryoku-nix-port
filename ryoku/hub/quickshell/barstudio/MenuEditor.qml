pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Ryoku.Ui.Singletons
import "BarStudioModel.js" as Model

ColumnLayout {
    id: root
    required property var config
    required property var catalog
    signal staged(var next)
    property string selectedId: "quick-settings"

    readonly property var menu: root.config.menus[root.selectedId]
    spacing: Tokens.s2

    RowLayout {
        Layout.fillWidth: true
        Label { text: qsTr("Menu") }
        ComboBox { id: menuPick; Layout.fillWidth: true; model: Object.keys(root.config.menus); onActivated: root.selectedId = currentText }
        ComboBox {
            id: anchorPick
            model: root.catalog.anchors()
            currentIndex: model.indexOf(root.menu.anchor)
            onActivated: root.staged(Model.setMenuAnchor(root.config, root.selectedId, currentText, root.catalog))
        }
        SpinBox {
            from: 1
            to: 10000
            value: root.menu.minWidth
            onValueModified: root.staged(Model.setMenu(root.config, root.selectedId, { anchor: root.menu.anchor, minWidth: value, expansion: root.menu.expansion, widgets: root.menu.widgets }, root.catalog))
        }
    }
    MenuWidgetListEditor { Layout.fillWidth: true; config: root.config; menuId: root.selectedId; path: []; catalog: root.catalog; onStaged: next => root.staged(next) }
    Repeater {
        model: root.menu.widgets
        delegate: MenuWidgetListEditor {
            required property var modelData
            required property int index
            visible: typeof modelData === "object" && Array.isArray(modelData.widgets)
            Layout.fillWidth: true
            config: root.config
            menuId: root.selectedId
            path: [index, "widgets"]
            catalog: root.catalog
            onStaged: next => root.staged(next)
        }
    }
}
