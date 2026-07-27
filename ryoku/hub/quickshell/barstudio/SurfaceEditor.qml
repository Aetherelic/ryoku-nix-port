pragma ComponentBehavior: Bound

import QtQuick
import Ryoku.Ui
import Ryoku.Ui.Singletons
import "BarStudioModel.js" as Model

// The two preserved frame surfaces: pick one, then its anchor, minimum width
// and the panes it hosts. Panes are set membership, so they read as a Multi;
// the toggled pane routes through the same setSurface staging as before.
Flow {
    id: root
    required property var config
    required property var catalog
    property var committed: null
    signal staged(var next)
    property string selectedId: "stash"

    readonly property var surface: root.config.surfaces[root.selectedId]
    readonly property var was: root.committed && root.committed.surfaces ? root.committed.surfaces[root.selectedId] : null
    readonly property var bounded: root.catalog.surface(root.selectedId)
    readonly property var surfaceIds: ["stash", "system"]
    readonly property var surfaceLabels: root.surfaceIds.map(id => labels.surface(id))
    readonly property var anchorIds: root.catalog.anchors()
    readonly property var anchorLabels: root.anchorIds.map(id => labels.anchor(id))
    readonly property var paneLabels: root.bounded.panes.map(id => labels.pane(id))
    readonly property var chosenPanes: root.surface.panes.map(id => labels.pane(id))

    spacing: Tokens.s2

    // Section.span's geometry, kept identical so these cells pack like the sheet's.
    readonly property real colWidth: (width - 11 * spacing) / 12
    function span(n) { return Math.min(width, Math.max(n * colWidth + (n - 1) * spacing, 290)) }

    CatalogLabels { id: labels }

    Cell {
        width: root.span(6)
        controlWidth: 120
        label: qsTr("Surface")
        value: labels.surface(root.selectedId)
        desc: qsTr("The preserved frame body to edit.")
        Seg {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            options: root.surfaceLabels
            current: labels.surface(root.selectedId)
            onChose: label => root.selectedId = root.surfaceIds.find(id => labels.surface(id) === label) || root.selectedId
        }
    }
    Cell {
        width: root.span(6)
        controlWidth: 58
        label: qsTr("Minimum width")
        unit: "px"
        value: String(root.surface.minWidth)
        def: root.was ? String(root.was.minWidth) : ""
        changed: !!root.was && root.surface.minWidth !== root.was.minWidth
        desc: qsTr("The narrowest this surface may draw.")
        source: "shell.json"
        Step {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            from: 1
            to: 10000
            value: root.surface.minWidth
            onModified: value => root.staged(Model.setSurface(root.config, root.selectedId, { minWidth: value }, root.catalog))
        }
    }
    Cell {
        width: root.span(12)
        block: true
        height: neededHeight
        label: qsTr("Anchor")
        value: labels.anchor(root.surface.anchor)
        def: root.was ? labels.anchor(root.was.anchor) : ""
        changed: !!root.was && root.surface.anchor !== root.was.anchor
        desc: qsTr("The frame edge or corner this surface grows from.")
        source: "shell.json"
        Chips {
            width: parent.width
            options: root.anchorLabels
            current: labels.anchor(root.surface.anchor)
            onChose: label => root.staged(Model.setSurface(root.config, root.selectedId, { anchor: root.anchorIds.find(id => labels.anchor(id) === label) || root.surface.anchor }, root.catalog))
        }
    }
    Cell {
        width: root.span(12)
        block: true
        height: neededHeight
        label: qsTr("Panes")
        value: String(root.surface.panes.length)
        unit: qsTr("of %1").arg(root.bounded.panes.length)
        desc: qsTr("The panes this surface hosts, from its bounded set.")
        source: "shell.json"
        Multi {
            width: parent.width
            options: root.paneLabels
            chosen: root.chosenPanes
            onToggled: label => {
                const id = root.bounded.panes[root.paneLabels.indexOf(label)];
                if (!id) return;
                const panes = root.surface.panes.slice();
                const at = panes.indexOf(id);
                if (at >= 0) panes.splice(at, 1); else panes.push(id);
                root.staged(Model.setSurface(root.config, root.selectedId, { panes: panes }, root.catalog));
            }
        }
    }
}
