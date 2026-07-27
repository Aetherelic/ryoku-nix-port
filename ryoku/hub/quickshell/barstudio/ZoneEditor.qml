pragma ComponentBehavior: Bound

import QtQuick
import Ryoku.Ui
import Ryoku.Ui.Singletons
import "BarStudioModel.js" as Model

// The selected rail's three zones and its add flow. Zone lists are surfaces,
// so they sit as full-width blocks; the add flow is one cell whose chip
// catalogue wraps inside the page column instead of clipping at its edge.
Column {
    id: root
    required property var config
    required property string edge
    required property var catalog
    signal staged(var next)
    property string addition: ""

    readonly property bool horizontal: root.edge === "top" || root.edge === "bottom"
    readonly property var zoneIds: root.horizontal ? ["start", "center", "end"] : ["top", "center", "bottom"]
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

    // a widget picked for one rail may not fit the next rail's axis
    onEdgeChanged: root.addition = ""

    spacing: Tokens.s3

    CatalogLabels { id: labels }

    Repeater {
        model: root.zoneIds
        delegate: WidgetListEditor {
            required property string modelData
            width: root.width
            config: root.config
            edge: root.edge
            zone: modelData
            catalog: root.catalog
            onStaged: next => root.staged(next)
        }
    }

    Cell {
        width: root.width
        block: true
        height: neededHeight
        label: qsTr("Add a widget")
        value: root.addition === "" ? "" : labels.item(root.addition)
        desc: qsTr("Everything compatible with this rail. A new widget lands in the %1 zone; route it with Move.").arg(labels.zone(root.zoneIds[0]).toLowerCase())
        Column {
            width: parent.width
            spacing: Tokens.s2
            Chips {
                objectName: "zone-addition"
                width: parent.width
                options: root.compatibleLabels
                current: root.addition === "" ? "" : labels.item(root.addition)
                onChose: label => root.addition = root.compatible.find(id => labels.item(id) === label) || ""
            }
            Btn {
                objectName: "zone-add"
                text: qsTr("ADD TO %1").arg(labels.zone(root.zoneIds[0]).toUpperCase())
                armed: root.addition.length > 0
                onAct: root.staged(Model.addZoneItem(root.config, root.edge, root.horizontal ? "start" : "top", root.addition, root.catalog))
            }
        }
    }
}
