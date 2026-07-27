pragma ComponentBehavior: Bound

import QtQuick
import Ryoku.Ui
import Ryoku.Ui.Singletons
import "BarStudioModel.js" as Model

// The bounded menus: pick one, then its anchor, minimum width, contents, and
// the contents of any container it holds (indented under a rule). `committed`
// is the on-disk config for the changed marks.
Column {
    id: root
    required property var config
    required property var catalog
    property var committed: null
    signal staged(var next)
    property string selectedId: "quick-settings"

    readonly property var menu: root.config.menus[root.selectedId]
    readonly property var was: root.committed && root.committed.menus ? root.committed.menus[root.selectedId] : null
    readonly property var menuIds: Object.keys(root.config.menus).filter(id => root.catalog.menu(id))
    readonly property var menuLabels: root.menuIds.map(id => labels.item(id))
    readonly property var anchorIds: root.catalog.anchors()
    readonly property var anchorLabels: root.anchorIds.map(id => labels.anchor(id))
    readonly property var containers: {
        const out = [];
        const list = root.menu.widgets;
        for (let i = 0; i < list.length; i++) {
            const item = list[i];
            if (item && typeof item === "object" && Array.isArray(item.widgets)) out.push({ at: i });
        }
        return out;
    }

    spacing: Tokens.s3

    CatalogLabels { id: labels }

    Cell {
        width: root.width
        block: true
        height: neededHeight
        label: qsTr("Menu")
        value: labels.item(root.selectedId)
        desc: qsTr("Which bounded menu to edit. Its anchor, width and contents follow.")
        Chips {
            width: parent.width
            options: root.menuLabels
            current: labels.item(root.selectedId)
            onChose: label => root.selectedId = root.menuIds.find(id => labels.item(id) === label) || root.selectedId
        }
    }

    Cell {
        width: root.width
        block: true
        height: neededHeight
        label: qsTr("Anchor")
        value: labels.anchor(root.menu.anchor)
        def: root.was ? labels.anchor(root.was.anchor) : ""
        changed: !!root.was && root.menu.anchor !== root.was.anchor
        desc: qsTr("The frame edge or corner this menu grows from.")
        source: "shell.json"
        Chips {
            width: parent.width
            options: root.anchorLabels
            current: labels.anchor(root.menu.anchor)
            onChose: label => root.staged(Model.setMenuAnchor(root.config, root.selectedId, root.anchorIds.find(id => labels.anchor(id) === label) || root.menu.anchor, root.catalog))
        }
    }

    Cell {
        width: root.width
        controlWidth: 58
        label: qsTr("Minimum width")
        unit: "px"
        value: String(root.menu.minWidth)
        def: root.was ? String(root.was.minWidth) : ""
        changed: !!root.was && root.menu.minWidth !== root.was.minWidth
        desc: qsTr("The narrowest this menu's surface may draw.")
        source: "shell.json"
        Step {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            from: 1
            to: 10000
            value: root.menu.minWidth
            onModified: value => root.staged(Model.setMenu(root.config, root.selectedId, { anchor: root.menu.anchor, minWidth: value, expansion: root.menu.expansion, widgets: root.menu.widgets }, root.catalog))
        }
    }

    MenuWidgetListEditor {
        width: root.width
        heading: qsTr("CONTENTS")
        locked: root.selectedId === "quick-settings"
        config: root.config
        menuId: root.selectedId
        path: []
        catalog: root.catalog
        onStaged: next => root.staged(next)
    }

    Repeater {
        model: root.containers
        delegate: Item {
            id: nest
            required property var modelData
            width: root.width
            height: nested.height

            Rectangle { width: 2; height: parent.height; color: Tokens.line }
            MenuWidgetListEditor {
                id: nested
                anchors { left: parent.left; right: parent.right; leftMargin: Tokens.s4 }
                heading: qsTr("CONTAINER %1").arg(nest.modelData.at + 1)
                config: root.config
                menuId: root.selectedId
                path: [nest.modelData.at, "widgets"]
                catalog: root.catalog
                onStaged: next => root.staged(next)
            }
        }
    }
}
