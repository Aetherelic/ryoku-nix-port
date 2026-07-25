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
    required property var hub
    signal staged(var next)

    readonly property var rail: root.config.rails[root.edge]
    spacing: Tokens.s2

    CatalogLabels { id: labels }

    Text { text: qsTr("%1 rail").arg(labels.edge(root.edge)); font.family: Tokens.ui }
    RowLayout {
        Layout.fillWidth: true
        Text { text: qsTr("Enabled") }
        Sw { on: root.rail.enabled; onToggled: value => root.staged(Model.setRail(root.config, root.edge, { enabled: value })) }
        Text { text: qsTr("Reveal") }
        Sw { on: root.rail.reveal; onToggled: value => root.staged(Model.setRail(root.config, root.edge, { reveal: value })) }
        Text { text: qsTr("Size") }
        Text { text: root.rail.size; font.family: Tokens.mono }
        Step {
            from: root.edge === "top" || root.edge === "bottom" ? 16 : 24
            to: root.edge === "top" || root.edge === "bottom" ? 96 : 112
            value: root.rail.size
            onModified: value => root.staged(Model.setRail(root.config, root.edge, { size: value }))
        }
    }
}