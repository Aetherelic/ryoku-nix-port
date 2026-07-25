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
    property string selectedId: "stash"

    readonly property var surface: root.config.surfaces[root.selectedId]
    readonly property var bounded: root.catalog.surface(root.selectedId)
    readonly property var surfaceIds: ["stash", "system"]
    readonly property var surfaceLabels: root.surfaceIds.map(id => labels.surface(id))
    readonly property var anchorIds: root.catalog.anchors()
    readonly property var anchorLabels: root.anchorIds.map(id => labels.anchor(id))
    spacing: Tokens.s2

    CatalogLabels { id: labels }

    RowLayout {
        Layout.fillWidth: true
        Text { text: qsTr("Frame surface") }
        Seg {
            options: root.surfaceLabels
            current: labels.surface(root.selectedId)
            onChose: label => root.selectedId = root.surfaceIds.find(id => labels.surface(id) === label) || root.selectedId
        }
        Chips {
            options: root.anchorLabels
            current: labels.anchor(root.surface.anchor)
            onChose: label => root.staged(Model.setSurface(root.config, root.selectedId, { anchor: root.anchorIds.find(id => labels.anchor(id) === label) || root.surface.anchor }, root.catalog))
        }
        Text { text: root.surface.minWidth; font.family: Tokens.mono }
        Step {
            from: 1
            to: 10000
            value: root.surface.minWidth
            onModified: value => root.staged(Model.setSurface(root.config, root.selectedId, { minWidth: value }, root.catalog))
        }
    }
    Repeater {
        model: root.bounded.panes
        delegate: RowLayout {
            required property string modelData
            Text { text: labels.pane(modelData) }
            Sw {
                on: root.surface.panes.includes(modelData)
                onToggled: checked => {
                    const panes = root.surface.panes.slice();
                    const i = panes.indexOf(modelData);
                    if (checked && i < 0) panes.push(modelData);
                    if (!checked && i >= 0) panes.splice(i, 1);
                    root.staged(Model.setSurface(root.config, root.selectedId, { panes: panes }, root.catalog));
                }
            }
        }
    }
}