pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
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
                id: entry
                required property string modelData
                width: 28 * root.scale
                height: 28 * root.scale

                // The desktop entry owns the real icon; the window class is the
                // fallback lookup, and its initial is the last resort so an
                // unmatched client still reads as something.
                readonly property string iconSource: {
                    const desktop = DesktopEntries.heuristicLookup(entry.modelData);
                    const byEntry = (desktop && desktop.icon) ? Quickshell.iconPath(desktop.icon, true) : "";
                    return byEntry !== "" ? byEntry : Quickshell.iconPath(entry.modelData, true);
                }

                Rectangle {
                    anchors.fill: parent
                    visible: area.containsMouse
                    radius: 3 * root.scale
                    color: Qt.alpha(Theme.cream, 0.14)
                }

                Image {
                    anchors.centerIn: parent
                    width: 20 * root.scale
                    height: 20 * root.scale
                    visible: entry.iconSource !== ""
                    source: entry.iconSource
                    sourceSize.width: width
                    sourceSize.height: height
                    smooth: true
                    asynchronous: true
                }

                Text {
                    anchors.centerIn: parent
                    visible: entry.iconSource === ""
                    text: entry.modelData.slice(0, 1).toUpperCase()
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
                        if (event.button === Qt.LeftButton) root.activate(entry.modelData);
                        else if (root.pinned.includes(entry.modelData)) root.unpin(entry.modelData);
                        else root.pin(entry.modelData);
                    }
                }
            }
        }
    }
}
