pragma ComponentBehavior: Bound

import QtQuick
import Ryoku.Ui
import Ryoku.Ui.Singletons
import "BarStudioModel.js" as Model

// The selected rail's three zones and its add flow, rebuilt simple. Each zone
// is a labelled list of its widgets; a widget carries Up, Down and Remove.
// One add block picks a target zone, then offers every widget that fits this
// rail's axis and is not already on the rail. There is no cross-zone move and
// no per-widget destination picker: a widget lands in the zone you point at,
// and a misplaced one is a Remove and an Add. Fewer controls, all of them live.
Column {
    id: root
    required property var config
    required property string edge
    required property var catalog
    signal staged(var next)

    readonly property bool horizontal: root.edge === "top" || root.edge === "bottom"
    readonly property var zoneIds: root.horizontal ? ["start", "center", "end"] : ["top", "center", "bottom"]
    property string addZone: root.zoneIds[0]

    // every widget that fits this rail's axis and is not already on the rail
    readonly property var available: {
        const axis = root.horizontal ? "horizontal" : "vertical";
        const onRail = Model.railWidgets(root.config, root.edge);
        const out = [];
        for (const id of root.catalog.ids()) {
            const entry = root.catalog.entry(id);
            if (entry && entry.axes.includes(axis) && onRail.indexOf(id) < 0) out.push(id);
        }
        return out;
    }
    readonly property var availableLabels: root.available.map(id => labels.item(id))
    readonly property var zoneLabels: root.zoneIds.map(id => labels.zone(id))

    // a different rail is a different axis; keep the add target a valid zone
    onEdgeChanged: root.addZone = root.zoneIds[0]

    spacing: Tokens.s3
    CatalogLabels { id: labels }

    Repeater {
        model: root.zoneIds
        delegate: Column {
            id: zone
            required property string modelData
            readonly property var items: root.config.rails[root.edge][zone.modelData]
            width: root.width
            spacing: Tokens.s1

            StripHead { width: parent.width; label: labels.zone(zone.modelData).toUpperCase(); count: String(zone.items.length) }

            Repeater {
                model: zone.items
                delegate: Rectangle {
                    id: strip
                    required property string modelData
                    required property int index
                    objectName: "widget-" + root.edge + "-" + zone.modelData + "-" + strip.index
                    width: zone.width
                    height: 36
                    radius: Tokens.radius
                    color: "transparent"
                    border.width: Tokens.border
                    border.color: Tokens.lineSoft

                    Text {
                        anchors { left: parent.left; leftMargin: Tokens.s3; verticalCenter: parent.verticalCenter }
                        text: labels.item(strip.modelData)
                        color: Tokens.ink
                        font.family: Tokens.ui
                        font.pixelSize: Tokens.fBody
                    }
                    Row {
                        anchors { right: parent.right; rightMargin: Tokens.s2; verticalCenter: parent.verticalCenter }
                        spacing: Tokens.s1
                        Btn {
                            objectName: "widget-up-" + strip.index
                            compact: true; anchors.verticalCenter: parent.verticalCenter
                            text: qsTr("UP"); armed: strip.index > 0
                            onAct: root.staged(Model.reorderZoneItem(root.config, root.edge, zone.modelData, strip.index, strip.index - 1))
                        }
                        Btn {
                            objectName: "widget-down-" + strip.index
                            compact: true; anchors.verticalCenter: parent.verticalCenter
                            text: qsTr("DOWN"); armed: strip.index < zone.items.length - 1
                            onAct: root.staged(Model.reorderZoneItem(root.config, root.edge, zone.modelData, strip.index, strip.index + 1))
                        }
                        Btn {
                            objectName: "widget-remove-" + strip.index
                            compact: true; anchors.verticalCenter: parent.verticalCenter
                            text: qsTr("REMOVE")
                            onAct: root.staged(Model.removeZoneItem(root.config, root.edge, zone.modelData, strip.index))
                        }
                    }
                }
            }

            Rectangle {
                visible: zone.items.length === 0
                width: parent.width
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
        }
    }

    // add: one block, a zone target and the widgets that fit and are free
    Cell {
        width: root.width
        block: true
        height: neededHeight
        label: qsTr("Add a widget")
        value: root.available.length === 0 ? qsTr("rail is full") : ""
        desc: qsTr("Everything that fits this rail and is not already on it. Pick a zone, then a widget; reorder within a zone with Up and Down.")
        Column {
            width: parent.width
            spacing: Tokens.s2
            Seg {
                objectName: "zone-target"
                options: root.zoneLabels
                current: labels.zone(root.addZone)
                onChose: label => root.addZone = root.zoneIds.find(id => labels.zone(id) === label) || root.addZone
            }
            Chips {
                objectName: "zone-add"
                width: parent.width
                options: root.availableLabels
                current: ""
                onChose: label => {
                    const id = root.available.find(w => labels.item(w) === label);
                    if (id) root.staged(Model.addZoneItem(root.config, root.edge, root.addZone, id, root.catalog));
                }
            }
        }
    }
}
