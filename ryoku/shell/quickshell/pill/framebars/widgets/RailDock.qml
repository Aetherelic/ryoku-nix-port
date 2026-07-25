pragma ComponentBehavior: Bound

import QtQuick
import "../../Singletons"
import "../lib/dock.js" as Dock
Item {
    id: root

    required property var pinned
    required property var activeClients
    required property string edge
    required property real scale
    signal activate(string className)
    signal pin(string className)
    signal unpin(string className)
    signal menuRequested(string id, rect ownerRect)
    readonly property bool horizontal: edge === "top" || edge === "bottom"
    readonly property var classes: Dock.resolve(pinned, activeClients)
    implicitWidth: horizontal ? dock.implicitWidth : 34 * scale
    implicitHeight: horizontal ? 34 * scale : dock.implicitHeight

    Grid {
        id: dock
        anchors.centerIn: parent
        columns: root.horizontal ? Math.max(1, root.classes.length) : 1
        spacing: 5 * root.scale

        Repeater {
            model: root.classes

            delegate: Item {
                required property string modelData
                width: 28 * root.scale
                height: 28 * root.scale

                Rectangle {
                    anchors.fill: parent
                    visible: area.containsMouse
                    radius: 3 * root.scale
                    color: Qt.alpha(Theme.cream, 0.14)
                }

                Text {
                    anchors.centerIn: parent
                    text: modelData.slice(0, 1).toUpperCase()
                    color: Theme.cream
                    font {
                        family: Theme.font
                        pixelSize: 12 * root.scale
                        weight: Font.DemiBold
                    }
                }

                MouseArea {
                    id: area
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    hoverEnabled: true
                    onClicked: event => {
                        if (event.button === Qt.LeftButton) root.activate(modelData);
                        else if (root.pinned.includes(modelData)) root.unpin(modelData);
                        else root.pin(modelData);
                        root.menuRequested("dock", Qt.rect(0, 0, root.width, root.height));
                    }
                }
            }
        }
    }
}
