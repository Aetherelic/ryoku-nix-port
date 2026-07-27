pragma ComponentBehavior: Bound

import QtQuick
import Ryoku.Ui
import Ryoku.Ui.Singletons
import "BarStudioModel.js" as Model

// One menu widget list: the menu's own contents when `path` is empty, or a
// container's contents when it points inside one. A strip per widget carries
// the name (selection and keyboard target), reorder, the send-to-end action
// (Eject, for a container child: back to the menu root), and Remove; the add
// flow is a cell whose chip catalogue wraps.
Column {
    id: root
    required property var config
    required property string menuId
    required property var path
    required property var catalog
    property string heading: qsTr("CONTENTS")
    // A locked list is a fixed composite (the quick-settings system sidebar):
    // its one widget cannot be reordered, removed, or joined by the old drawer
    // parts, so the reorder/remove controls and the add flow are withheld. The
    // normalizer pins that list regardless, so an editable list here would only
    // stage changes the shell throws away.
    property bool locked: false
    signal staged(var next)
    property string addition: ""
    property int selected: -1

    readonly property var items: {
        let list = root.config.menus[root.menuId].widgets;
        for (let i = 0; i < root.path.length; i += 2) {
            const index = root.path[i];
            if (root.path[i + 1] !== "widgets" || !list[index] || !Array.isArray(list[index].widgets)) return [];
            list = list[index].widgets;
        }
        return list;
    }
    readonly property var widgetIds: root.catalog.widgetIds()
    readonly property var widgetLabels: root.widgetIds.map(id => labels.item(id))

    function select(index) {
        if (index < 0 || index >= items.length) return;
        selected = index;
        rows.itemAt(index).selectionControl.forceActiveFocus();
    }

    // another menu's list is another selection
    onMenuIdChanged: root.selected = -1

    spacing: Tokens.s1

    CatalogLabels { id: labels }

    StripHead { width: parent.width; label: root.heading; count: String(root.items.length) }
    Text {
        visible: root.locked
        width: root.width
        text: qsTr("One composite widget. Its contents are fixed here.")
        color: Tokens.inkFaint
        font.family: Tokens.mono
        font.pixelSize: Tokens.fTiny
        wrapMode: Text.WordWrap
    }

    Repeater {
        id: rows
        model: root.items
        delegate: Rectangle {
            id: strip
            required property var modelData
            required property int index
            readonly property string itemId: typeof modelData === "string" ? modelData : modelData.id
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
                objectName: "menu-widget-selection-" + index
                compact: true
                anchors { left: parent.left; leftMargin: Tokens.s2; verticalCenter: parent.verticalCenter }
                text: labels.item(strip.itemId)
                primary: root.selected === index
                onAct: root.select(index)
                Keys.onPressed: event => {
                    if (event.key !== Qt.Key_Up && event.key !== Qt.Key_Down) return;
                    root.select(index + (event.key === Qt.Key_Up ? -1 : 1));
                    event.accepted = true;
                }
            }
            Row {
                visible: !root.locked
                anchors { right: parent.right; rightMargin: Tokens.s2; verticalCenter: parent.verticalCenter }
                spacing: Tokens.s1
                Btn { objectName: "menu-widget-up-" + index; compact: true; anchors.verticalCenter: parent.verticalCenter; text: qsTr("UP"); armed: index > 0; onAct: root.staged(Model.moveMenuWidget(root.config, root.menuId, root.path, index, root.path, index - 1, root.catalog)) }
                Btn { objectName: "menu-widget-down-" + index; compact: true; anchors.verticalCenter: parent.verticalCenter; text: qsTr("DOWN"); armed: index < root.items.length - 1; onAct: root.staged(Model.moveMenuWidget(root.config, root.menuId, root.path, index, root.path, index + 1, root.catalog)) }
                Btn { objectName: "menu-widget-move-" + index; compact: true; anchors.verticalCenter: parent.verticalCenter; text: root.path.length ? qsTr("EJECT") : qsTr("TO END"); onAct: root.staged(Model.moveMenuWidget(root.config, root.menuId, root.path, index, [], root.config.menus[root.menuId].widgets.length, root.catalog)) }
                Btn { objectName: "menu-widget-remove-" + index; compact: true; anchors.verticalCenter: parent.verticalCenter; text: qsTr("REMOVE"); onAct: root.staged(Model.removeMenuWidget(root.config, root.menuId, root.path, index)) }
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

    Cell {
        visible: !root.locked
        width: root.width
        block: true
        height: neededHeight
        label: qsTr("Add a widget")
        value: root.addition === "" ? "" : labels.item(root.addition)
        desc: root.path.length ? qsTr("Lands inside this container.") : qsTr("Lands at the end of this menu's contents.")
        Column {
            width: parent.width
            spacing: Tokens.s2
            Chips {
                width: parent.width
                options: root.widgetLabels
                current: root.addition === "" ? "" : labels.item(root.addition)
                onChose: label => root.addition = root.widgetIds.find(id => labels.item(id) === label) || ""
            }
            Btn {
                text: qsTr("ADD")
                armed: root.addition.length > 0
                onAct: root.staged(Model.addMenuWidget(root.config, root.menuId, root.path, root.addition, root.catalog))
            }
        }
    }
}
