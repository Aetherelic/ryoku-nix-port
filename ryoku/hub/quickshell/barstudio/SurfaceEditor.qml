pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
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
    spacing: Tokens.s2

    RowLayout {
        Layout.fillWidth: true
        Label { text: qsTr("Frame surface") }
        ComboBox { id: surfacePick; model: ["stash", "system"]; onActivated: root.selectedId = currentText }
        ComboBox {
            model: root.catalog.anchors()
            currentIndex: model.indexOf(root.surface.anchor)
            onActivated: root.staged(Model.setSurface(root.config, root.selectedId, { anchor: currentText }, root.catalog))
        }
        SpinBox {
            from: 1
            to: 10000
            value: root.surface.minWidth
            onValueModified: root.staged(Model.setSurface(root.config, root.selectedId, { minWidth: value }, root.catalog))
        }
    }
    Repeater {
        model: root.bounded.panes
        delegate: CheckBox {
            required property string modelData
            text: modelData
            checked: root.surface.panes.includes(modelData)
            onToggled: {
                const panes = root.surface.panes.slice();
                const i = panes.indexOf(modelData);
                if (checked && i < 0) panes.push(modelData);
                if (!checked && i >= 0) panes.splice(i, 1);
                root.staged(Model.setSurface(root.config, root.selectedId, { panes: panes }, root.catalog));
            }
        }
    }
}
