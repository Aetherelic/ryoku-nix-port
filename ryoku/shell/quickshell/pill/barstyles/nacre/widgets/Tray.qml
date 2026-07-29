pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "../../../Singletons"
import "../../.." as Pill

Item {
    id: root

    property real barHeight: 40

    implicitWidth: content.implicitWidth
    implicitHeight: 26
    visible: Tray.items.length > 0

    function source(item) {
        if (item.iconPath && item.iconPath.length)
            return item.iconPath.indexOf("/") === 0 ? "file://" + item.iconPath : item.iconPath;
        if (item.iconName && item.iconName.length)
            return Quickshell.iconPath(item.iconName, "application-x-executable-symbolic");
        return Quickshell.iconPath("application-x-executable-symbolic", true);
    }

    Row {
        id: content
        anchors.centerIn: parent
        spacing: 7

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
                    source: root.source(cell.modelData)
                    scale: mouse.pressed ? 0.82 : 1

                    Behavior on scale {
                        enabled: !Motion.reduce
                        NumberAnimation { duration: Motion.fast; easing.type: Motion.easeStandard }
                    }
                }
                MouseArea {
                    id: mouse
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: event => {
                        const item = cell.modelData;
                        if (event.button === Qt.LeftButton) {
                            const point = cell.mapToGlobal(0, cell.height);
                            Tray.activate(item.service, Math.round(point.x), Math.round(point.y));
                        } else if (item.menu) {
                            trayMenu.openFor(item, cell);
                        } else {
                            const point = cell.mapToGlobal(0, cell.height);
                            Tray.contextMenu(item.service, Math.round(point.x), Math.round(point.y));
                        }
                    }
                }
            }
        }
    }

    Pill.TrayMenu {
        id: trayMenu
        edge: "top"
    }
}
