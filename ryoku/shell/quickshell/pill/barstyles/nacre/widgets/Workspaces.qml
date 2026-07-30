pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Hyprland
import "../../../Singletons"

Item {
    id: root

    property real barHeight: 40
    property string workspaceStyle: Config.normalizedNacre.workspaceStyle
    readonly property var kanji: ["", "一", "二", "三", "四", "五", "六", "七", "八", "九", "十"]
    readonly property int activeId: Workspaces.activeId
    readonly property int base: Math.floor((root.activeId - 1) / 10) * 10

    function label(id) {
        if (root.workspaceStyle === "dots")
            return "";
        if (root.workspaceStyle === "kanji" && id >= 1 && id <= 10)
            return root.kanji[id];
        return String(id);
    }

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
        spacing: root.workspaceStyle === "dots" ? 5 : 3

        Repeater {
            model: root.entries
            delegate: Rectangle {
                id: ring

                required property int modelData
                readonly property bool active: ring.modelData === root.activeId
                readonly property bool occupied: root.occupied(ring.modelData)
                readonly property bool dotMode: root.workspaceStyle === "dots"

                anchors.verticalCenter: parent.verticalCenter
                width: ring.dotMode ? (ring.active ? 10 : 7) : 26
                height: width
                radius: width / 2
                color: ring.dotMode ? "transparent"
                    : ring.active ? Theme.primary
                    : ring.occupied
                        ? Qt.rgba(Theme.onSurface.r, Theme.onSurface.g, Theme.onSurface.b, 0.10)
                        : "transparent"
                border.width: ring.dotMode ? (ring.active ? 2 : 1) : 0
                border.color: ring.active ? Theme.primary
                    : ring.occupied ? Theme.onSurface : Theme.onSurfaceVariant

                Behavior on width {
                    NumberAnimation { duration: Motion.fast; easing.type: Motion.easeStandard }
                }
                Behavior on color {
                    ColorAnimation { duration: Motion.fast }
                }
                Behavior on border.color {
                    ColorAnimation { duration: Motion.fast }
                }
                Text {
                    anchors.centerIn: parent
                    visible: !ring.dotMode
                    text: root.label(ring.modelData)
                    color: ring.active ? Theme.onPrimary
                        : ring.occupied ? Theme.onSurface : Theme.onSurfaceVariant
                    font.family: root.workspaceStyle === "kanji" ? Theme.fontJp : Theme.mono
                    font.pixelSize: root.workspaceStyle === "kanji" ? 15 : Theme.fontSm
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
