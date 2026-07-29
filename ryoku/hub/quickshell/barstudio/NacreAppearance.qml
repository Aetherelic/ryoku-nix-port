import QtQuick
import Ryoku.Ui
import Ryoku.Ui.Singletons

Grid {
    id: root

    required property var config
    signal changed(string key, var value)

    columns: 2
    columnSpacing: Tokens.s2
    rowSpacing: Tokens.s2

    component SliderCell: Cell {
        id: cell

        property real minimum: 0
        property real maximum: 100
        property real setting: 0
        property string key: ""

        width: (root.width - Tokens.s2) / 2
        height: implicitHeight
        controlWidth: 160
        value: String(cell.key === "opacity" ? Math.round(cell.setting * 100) : cell.setting)
        unit: cell.key === "opacity" ? "%" : "px"
        source: "shell.json"

        Slid {
            width: parent.width
            from: cell.minimum
            to: cell.maximum
            value: cell.setting
            onModified: value => root.changed(cell.key, value)
        }
    }

    SliderCell {
        label: qsTr("Bar height")
        key: "height"
        minimum: 32
        maximum: 56
        setting: root.config.height
    }
    SliderCell {
        label: qsTr("Island opacity")
        key: "opacity"
        minimum: 0.45
        maximum: 1
        setting: root.config.opacity
    }
    SliderCell {
        label: qsTr("Island padding")
        key: "padding"
        minimum: 6
        maximum: 24
        setting: root.config.padding
    }
    SliderCell {
        label: qsTr("Widget spacing")
        key: "spacing"
        minimum: 2
        maximum: 18
        setting: root.config.spacing
    }
    SliderCell {
        label: qsTr("Island gap")
        key: "islandGap"
        minimum: 6
        maximum: 32
        setting: root.config.islandGap
    }
    Cell {
        width: (root.width - Tokens.s2) / 2
        height: implicitHeight
        controlWidth: 54
        label: qsTr("Desktop frame")
        value: root.config.frame ? qsTr("ON") : qsTr("OFF")
        source: "shell.json"

        Sw {
            objectName: "nacre-frame"
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            on: root.config.frame
            onToggled: value => root.changed("frame", value)
        }
    }
    Cell {
        width: (root.width - Tokens.s2) / 2
        height: implicitHeight
        controlWidth: 54
        label: qsTr("Occupied workspaces")
        value: root.config.occupiedWorkspaces ? qsTr("ON") : qsTr("OFF")
        source: "shell.json"

        Sw {
            objectName: "nacre-occupied-workspaces"
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            on: root.config.occupiedWorkspaces
            onToggled: value => root.changed("occupiedWorkspaces", value)
        }
    }
}
