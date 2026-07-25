pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Services.SystemTray
import Quickshell.Widgets

Item {
    id: root

    required property string edge
    required property real scale
    signal menuRequested(string id, rect ownerRect)

    readonly property bool horizontal: edge === "top" || edge === "bottom"
    implicitWidth: horizontal ? tray.implicitWidth : 24 * scale
    implicitHeight: horizontal ? 24 * scale : tray.implicitHeight

    Grid {
        id: tray
        anchors.centerIn: parent
        columns: root.horizontal ? Math.max(1, SystemTray.items.values.length) : 1
        spacing: 5 * root.scale

        Repeater {
            model: SystemTray.items

            delegate: Item {
                required property var modelData
                width: 18 * root.scale
                height: 18 * root.scale

                IconImage {
                    anchors.fill: parent
                    source: modelData ? modelData.icon : ""
                }

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onClicked: event => {
                        if (!modelData) return;
                        if (event.button === Qt.LeftButton) modelData.activate();
                        root.menuRequested("tray", Qt.rect(0, 0, root.width, root.height));
                    }
                }
            }
        }
    }
}
