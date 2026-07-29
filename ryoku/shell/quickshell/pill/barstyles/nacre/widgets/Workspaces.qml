pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Hyprland
import "../../../Singletons"

Item {
    id: root

    property real barHeight: 40
    readonly property int activeId: Workspaces.activeId
    readonly property int base: Math.floor((root.activeId - 1) / 10) * 10

    function occupied(id) {
        const toplevels = Hyprland.toplevels ? Hyprland.toplevels.values : [];
        for (const toplevel of toplevels) {
            const object = toplevel && toplevel.lastIpcObject || {};
            if (object.workspace && object.workspace.id === id)
                return true;
        }
        return false;
    }

    readonly property var entries: {
        const output = [];
        if (Config.normalizedNacre.occupiedWorkspaces) {
            for (let index = 1; index <= 10; index++) {
                const id = root.base + index;
                if (id === root.activeId || root.occupied(id))
                    output.push(id);
            }
        } else {
            let count = 5;
            for (let index = 10; index > 5; index--) {
                const id = root.base + index;
                if (id === root.activeId || root.occupied(id)) {
                    count = index;
                    break;
                }
            }
            for (let index = 1; index <= count; index++)
                output.push(root.base + index);
        }
        return output.length ? output : [root.activeId];
    }

    implicitWidth: content.implicitWidth
    implicitHeight: 26

    WheelHandler {
        onWheel: event => Hyprland.dispatch(event.angleDelta.y > 0 ? "workspace r-1" : "workspace r+1")
    }

    Row {
        id: content
        anchors.centerIn: parent
        spacing: 5

        Repeater {
            model: root.entries
            delegate: Rectangle {
                id: ring

                required property int modelData
                readonly property bool active: ring.modelData === root.activeId

                anchors.verticalCenter: parent.verticalCenter
                width: ring.active ? 10 : 7
                height: width
                radius: width / 2
                color: "transparent"
                border.width: ring.active ? 2 : 1
                border.color: ring.active ? Theme.primary
                    : root.occupied(ring.modelData) ? Theme.onSurface : Theme.onSurfaceVariant

                Behavior on width {
                    NumberAnimation { duration: Motion.fast; easing.type: Motion.easeStandard }
                }
                Behavior on border.color {
                    ColorAnimation { duration: Motion.fast }
                }
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -5
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Hyprland.dispatch('hl.dsp.focus({ workspace = "' + ring.modelData + '" })')
                }
            }
        }
    }
}
