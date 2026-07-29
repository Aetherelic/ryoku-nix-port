pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "../../../Singletons"

// Obi tray: a live row of SNI icons from the daemon `tray` topic (Tray
// singleton). Left click activates the item, right click asks for its menu.
// Hidden while empty. Mirrors iNiR's SysTray row, paper-and-ink monochrome.
Row {
    id: root
    spacing: 8
    visible: Tray.items.length > 0

    function itemSource(it) {
        if (it.iconPath && it.iconPath.length > 0)
            return it.iconPath.indexOf("/") === 0 ? ("file://" + it.iconPath) : it.iconPath;
        if (it.iconName && it.iconName.length > 0)
            return Quickshell.iconPath(it.iconName, "application-x-executable-symbolic");
        return Quickshell.iconPath("application-x-executable-symbolic", true);
    }

    Repeater {
        model: Tray.items

        delegate: Item {
            id: cell
            required property var modelData

            width: 18
            height: 26

            Image {
                anchors.centerIn: parent
                width: 18
                height: 18
                sourceSize.width: width
                sourceSize.height: height
                smooth: true
                asynchronous: true
                source: root.itemSource(cell.modelData)
                scale: area.pressed ? 0.82 : 1.0
                opacity: area.pressed ? 0.72 : 1.0
                Behavior on scale {
                    enabled: !Motion.reduce
                    NumberAnimation { duration: Motion.fast; easing.type: Motion.easeStandard }
                }
                Behavior on opacity {
                    enabled: !Motion.reduce
                    NumberAnimation { duration: Motion.fast; easing.type: Motion.easeStandard }
                }
            }

            MouseArea {
                id: area
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
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
