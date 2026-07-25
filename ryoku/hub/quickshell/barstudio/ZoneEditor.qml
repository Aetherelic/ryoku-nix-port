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
    required property var catalog
    signal staged(var next)
    property string addition: ""

    readonly property bool horizontal: root.edge === "top" || root.edge === "bottom"
    readonly property var compatible: {
        const out = [];
        const axis = root.horizontal ? "horizontal" : "vertical";
        for (const id of root.catalog.ids()) {
            const entry = root.catalog.entry(id);
            if (entry && entry.axes.includes(axis)) out.push(id);
        }
        return out;
    }
    spacing: Tokens.s3

    RowLayout {
        Layout.fillWidth: true
        Label { text: qsTr("Add compatible widget") }
        ComboBox { id: addPick; Layout.fillWidth: true; model: root.compatible; onActivated: root.addition = currentText }
        Button {
            text: qsTr("Add")
            enabled: root.addition.length > 0
            onClicked: root.staged(Model.addZoneItem(root.config, root.edge, root.horizontal ? "start" : "top", root.addition, root.catalog))
        }
    }
    Repeater {
        model: root.horizontal ? ["start", "center", "end"] : ["top", "center", "bottom"]
        delegate: WidgetListEditor {
            required property string modelData
            Layout.fillWidth: true
            config: root.config
            edge: root.edge
            zone: modelData
            catalog: root.catalog
            onStaged: next => root.staged(next)
        }
    }
}
