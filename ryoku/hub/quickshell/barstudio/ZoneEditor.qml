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
    readonly property var compatibleLabels: root.compatible.map(id => labels.item(id))
    spacing: Tokens.s3

    CatalogLabels { id: labels }

    RowLayout {
        Layout.fillWidth: true
        Text { text: qsTr("Add compatible widget") }
        Chips {
            Layout.fillWidth: true
            options: root.compatibleLabels
            current: labels.item(root.addition)
            onChose: label => root.addition = root.compatible.find(id => labels.item(id) === label) || ""
        }
        Btn {
            text: qsTr("Add")
            armed: root.addition.length > 0
            onAct: root.staged(Model.addZoneItem(root.config, root.edge, root.horizontal ? "start" : "top", root.addition, root.catalog))
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