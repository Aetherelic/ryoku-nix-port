pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "../../Singletons"

// System tray. State comes from the daemon `tray` topic (Tray singleton), never
// D-Bus directly. The root self-hides while there are no items; a toggle button
// reveals/collapses the item strip, and each item shows the server-resolved icon
// (iconPath file, else iconName theme lookup, else the generic fallback). Left
// click asks the item to act, right click asks for its menu. Contract 04
// sec 2.1, 3.2 (system_tray, system_tray_item).
Item {
    id: root

    required property string edge
    required property real scale

    readonly property var items: Tray.items
    readonly property bool horizontal: edge === "top" || edge === "bottom"
    readonly property real cross: 48 * scale
    property bool revealed: false

    readonly property bool selfShown: items.length > 0
    visible: selfShown
    implicitWidth: selfShown ? (horizontal ? line.implicitWidth : cross) : 0
    implicitHeight: selfShown ? (horizontal ? cross : line.implicitHeight) : 0

    function itemSource(it) {
        if (it.iconPath && it.iconPath.length > 0)
            return it.iconPath.indexOf("/") === 0 ? ("file://" + it.iconPath) : it.iconPath;
        if (it.iconName && it.iconName.length > 0)
            return Quickshell.iconPath(it.iconName, "application-x-executable-symbolic");
        return Quickshell.iconPath("application-x-executable-symbolic", true);
    }

    Loader {
        id: line
        anchors.centerIn: parent
        sourceComponent: root.horizontal ? rowComp : colComp
    }

    Component {
        id: rowComp
        Row {
            spacing: 0
            RailButton {
                edge: root.edge
                scale: root.scale
                icon: "tray"
                onClicked: root.revealed = !root.revealed
            }
            Item {
                clip: true
                height: root.cross
                width: root.revealed ? strip.implicitWidth : 0
                Behavior on width { NumberAnimation { duration: Motion.barReveal; easing.type: Motion.barRevealCurve } }
                Row { id: strip; spacing: 0; Repeater { model: root.items; delegate: itemComp } }
            }
        }
    }
    Component {
        id: colComp
        Column {
            spacing: 0
            RailButton {
                edge: root.edge
                scale: root.scale
                icon: "tray"
                onClicked: root.revealed = !root.revealed
            }
            Item {
                clip: true
                width: root.cross
                height: root.revealed ? strip.implicitHeight : 0
                Behavior on height { NumberAnimation { duration: Motion.barReveal; easing.type: Motion.barRevealCurve } }
                Column { id: strip; spacing: 0; Repeater { model: root.items; delegate: itemComp } }
            }
        }
    }

    Component {
        id: itemComp
        Item {
            id: cell
            required property var modelData
            readonly property real along: Math.max(36 * root.scale, Theme.iconMd * root.scale + 20 * root.scale)
            width: root.horizontal ? along : root.cross
            height: root.horizontal ? root.cross : along

            Rectangle {
                anchors.fill: parent
                radius: Theme.radiusWidget
                color: area.containsMouse
                    ? Qt.rgba(Theme.onSurface.r, Theme.onSurface.g, Theme.onSurface.b, 0.08)
                    : "transparent"
            }

            Image {
                anchors.centerIn: parent
                width: Theme.iconMd * root.scale
                height: Theme.iconMd * root.scale
                sourceSize.width: width
                sourceSize.height: height
                smooth: true
                asynchronous: true
                source: root.itemSource(cell.modelData)
            }

            MouseArea {
                id: area
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                hoverEnabled: true
                onClicked: event => {
                    const svc = cell.modelData.service;
                    const g = cell.mapToGlobal(0, cell.height);
                    if (event.button === Qt.LeftButton)
                        Tray.activate(svc, Math.round(g.x), Math.round(g.y));
                    else
                        Tray.contextMenu(svc, Math.round(g.x), Math.round(g.y));
                }
            }
        }
    }
}
