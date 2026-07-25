pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Ryoku.Ui
import Ryoku.Ui.Singletons
import "BarStudioModel.js" as Model

ColumnLayout {
    id: root
    required property var config
    required property var catalog
    signal staged(var next)
    property string selectedId: "quick-settings"

    readonly property var menu: root.config.menus[root.selectedId]
    readonly property var menuIds: Object.keys(root.config.menus).filter(id => root.catalog.menu(id))
    readonly property var menuLabels: root.menuIds.map(id => labels.item(id))
    readonly property var anchorIds: root.catalog.anchors()
    readonly property var anchorLabels: root.anchorIds.map(id => labels.anchor(id))
    spacing: Tokens.s2

    CatalogLabels { id: labels }

    RowLayout {
        Layout.fillWidth: true
        Text { text: qsTr("Menu") }
        Chips {
            Layout.fillWidth: true
            options: root.menuLabels
            current: labels.item(root.selectedId)
            onChose: label => root.selectedId = root.menuIds.find(id => labels.item(id) === label) || root.selectedId
        }
        Seg {
            options: root.anchorLabels
            current: labels.anchor(root.menu.anchor)
            onChose: label => root.staged(Model.setMenuAnchor(root.config, root.selectedId, root.anchorIds.find(id => labels.anchor(id) === label) || root.menu.anchor, root.catalog))
        }
        Text { text: root.menu.minWidth; font.family: Tokens.mono }
        Step {
            from: 1
            to: 10000
            value: root.menu.minWidth
            onModified: value => root.staged(Model.setMenu(root.config, root.selectedId, { anchor: root.menu.anchor, minWidth: value, expansion: root.menu.expansion, widgets: root.menu.widgets }, root.catalog))
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