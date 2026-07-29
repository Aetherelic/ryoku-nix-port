pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import "../../../Singletons"

// Obi workspaces: a centred row of kanji numerals, one per live Hyprland
// workspace. The focused one is a filled pill, occupied ones read solid, empty
// ones dim. Click switches; wheel cycles. This is the bar's centre piece.
Item {
    id: root

    property real slot: 26
    readonly property var kanji: ["", "一", "二", "三", "四", "五", "六", "七", "八", "九", "十"]
    readonly property int activeId: Workspaces.activeId

    readonly property var entries: {
        const list = Hyprland.workspaces ? Hyprland.workspaces.values : [];
        const out = [];
        const seen = {};
        for (let i = 0; i < list.length; i++) {
            const w = list[i];
            if (!w)
                continue;
            const o = w.lastIpcObject || {};
            const id = (typeof w.id === "number" && w.id !== 0) ? w.id : (typeof o.id === "number" ? o.id : 0);
            if (id <= 0)
                continue;
            const name = (typeof w.name === "string" && w.name.length) ? w.name : (o.name || "");
            if (name.indexOf("special") === 0)
                continue;
            if (seen[id])
                continue;
            seen[id] = true;
            out.push(id);
        }
        if (out.length === 0 && root.activeId > 0)
            out.push(root.activeId);
        out.sort((a, b) => a - b);
        return out;
    }

    function label(id) { return (id >= 1 && id <= 10) ? root.kanji[id] : String(id); }
    function focus(id) { Hyprland.dispatch('hl.dsp.focus({ workspace = "' + id + '" })'); }
    function occupied(id) {
        const tls = Hyprland.toplevels ? Hyprland.toplevels.values : [];
        for (let i = 0; i < tls.length; i++) {
            const o = tls[i] && tls[i].lastIpcObject || {};
            if (o.workspace && o.workspace.id === id)
                return true;
        }
        return false;
    }

    implicitWidth: rowr.implicitWidth
    implicitHeight: root.slot

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        onWheel: e => Hyprland.dispatch(e.angleDelta.y > 0 ? "workspace r-1" : "workspace r+1")
    }

    Row {
        id: rowr
        anchors.centerIn: parent
        spacing: 3

        Repeater {
            model: root.entries

            delegate: Rectangle {
                id: cell
                required property var modelData
                readonly property int wsId: cell.modelData
                readonly property bool active: cell.wsId === root.activeId
                readonly property bool occ: root.occupied(cell.wsId)

                width: root.slot
                height: root.slot
                radius: root.slot / 2
                color: cell.active ? Theme.primary
                    : cell.occ ? Qt.rgba(Theme.onSurface.r, Theme.onSurface.g, Theme.onSurface.b, 0.10)
                    : "transparent"
                Behavior on color { ColorAnimation { duration: Motion.fast } }

                Text {
                    anchors.centerIn: parent
                    text: root.label(cell.wsId)
                    color: cell.active ? Theme.onPrimary : (cell.occ ? Theme.onSurface : Theme.onSurfaceVariant)
                    font.family: Theme.fontJp
                    font.pixelSize: 15
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.focus(cell.wsId)
                }
            }
        }
    }
}
