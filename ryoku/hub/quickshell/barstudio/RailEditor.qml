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
    required property var hub
    signal staged(var next)

    readonly property var rail: root.config.rails[root.edge]
    spacing: Tokens.s2

    Label { text: qsTr("%1 rail").arg(root.edge); font: Tokens.ui }
    RowLayout {
        Layout.fillWidth: true
        Switch {
            text: qsTr("Enabled")
            checked: root.rail.enabled
            onToggled: root.staged(Model.setRail(root.config, root.edge, { enabled: checked }))
        }
        Switch {
            text: qsTr("Reveal")
            checked: root.rail.reveal
            onToggled: root.staged(Model.setRail(root.config, root.edge, { reveal: checked }))
        }
        Label { text: qsTr("Size") }
        SpinBox {
            from: root.edge === "top" || root.edge === "bottom" ? 16 : 24
            to: root.edge === "top" || root.edge === "bottom" ? 96 : 112
            value: root.rail.size
            onValueModified: root.staged(Model.setRail(root.config, root.edge, { size: value }))
        }
    }
}
