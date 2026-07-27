pragma ComponentBehavior: Bound

import QtQuick
import Ryoku.Ui
import Ryoku.Ui.Singletons
import "BarStudioModel.js" as Model

// The selected rail's own settings, as cells: visibility, hover reveal, and
// thickness. The zones and their widgets are ZoneEditor's. `committed` is the
// on-disk config, so a pending edit shows the changed edge and struck default
// exactly like the schema sheet.
Flow {
    id: root
    required property var config
    required property string edge
    property var committed: null
    signal staged(var next)

    readonly property var rail: root.config.rails[root.edge]
    readonly property var was: root.committed && root.committed.rails ? root.committed.rails[root.edge] : null
    readonly property bool horizontal: root.edge === "top" || root.edge === "bottom"

    spacing: Tokens.s2

    // Section.span's geometry, kept identical so these cells pack like the
    // sheet's: 12 columns, the shared gutter, the same usable minimum.
    readonly property real colWidth: (width - 11 * spacing) / 12
    function span(n) { return Math.min(width, Math.max(n * colWidth + (n - 1) * spacing, 290)) }

    CatalogLabels { id: labels }

    Cell {
        width: root.span(4)
        controlWidth: 54
        label: qsTr("Show this rail")
        value: root.rail.enabled ? qsTr("ON") : qsTr("OFF")
        def: root.was ? (root.was.enabled ? qsTr("ON") : qsTr("OFF")) : ""
        changed: !!root.was && root.rail.enabled !== root.was.enabled
        desc: qsTr("Draw the %1 rail on the frame.").arg(labels.edge(root.edge).toLowerCase())
        source: "shell.json"
        Sw {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            on: root.rail.enabled
            onToggled: value => root.staged(Model.setRail(root.config, root.edge, { enabled: value }))
        }
    }
    Cell {
        width: root.span(4)
        controlWidth: 54
        label: qsTr("Reveal on hover")
        value: root.rail.reveal ? qsTr("ON") : qsTr("OFF")
        def: root.was ? (root.was.reveal ? qsTr("ON") : qsTr("OFF")) : ""
        changed: !!root.was && root.rail.reveal !== root.was.reveal
        desc: qsTr("Slide the rail in when the pointer touches this edge.")
        source: "shell.json"
        Sw {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            on: root.rail.reveal
            onToggled: value => root.staged(Model.setRail(root.config, root.edge, { reveal: value }))
        }
    }
    Cell {
        width: root.span(4)
        controlWidth: 58
        label: qsTr("Thickness")
        unit: "px"
        value: String(root.rail.size)
        def: root.was ? String(root.was.size) : ""
        changed: !!root.was && root.rail.size !== root.was.size
        desc: qsTr("How far the rail stands into the screen.")
        source: "shell.json"
        Step {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            from: root.horizontal ? 16 : 24
            to: root.horizontal ? 96 : 112
            value: root.rail.size
            onModified: value => root.staged(Model.setRail(root.config, root.edge, { size: value }))
        }
    }
}
