pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Hyprland
import "../../Singletons"

Item {
    id: root

    required property string edge
    required property real scale
    signal menuRequested(string id, rect ownerRect)

    readonly property bool horizontal: edge === "top" || edge === "bottom"
    readonly property var ids: {
        const result = [];
        const all = Hyprland.workspaces.values;
        for (let i = 0; i < all.length; ++i)
            if (all[i] && all[i].id > 0) result.push(all[i].id);
        if (!result.includes(Workspaces.activeId)) result.push(Workspaces.activeId);
        return result.sort((a, b) => a - b);
    }
    implicitWidth: horizontal ? strip.implicitWidth : 28 * scale
    implicitHeight: horizontal ? 28 * scale : strip.implicitHeight

    Grid {
        id: strip
        anchors.centerIn: parent
        columns: root.horizontal ? Math.max(1, root.ids.length) : 1
        spacing: 4 * root.scale

        Repeater {
            model: root.ids

            delegate: Item {
                required property int modelData
                width: 24 * root.scale
                height: 24 * root.scale

                Rectangle {
                    anchors.fill: parent
                    visible: modelData === Workspaces.activeId
                    radius: 3 * root.scale
                    color: Theme.onSurface
                }

                Text {
                    anchors.centerIn: parent
                    text: modelData
                    color: modelData === Workspaces.activeId ? Theme.surfaceContainerLow : Theme.onSurface
                    font {
                        family: Theme.fontPrimary
                        pixelSize: 11 * root.scale
                        weight: Font.DemiBold
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: Hyprland.dispatch('hl.dsp.workspace.move({ workspace = ' + modelData + ', monitor = "current" })')
                }
            }
        }
    }
}
