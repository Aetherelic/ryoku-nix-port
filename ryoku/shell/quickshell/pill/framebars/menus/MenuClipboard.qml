import QtQuick
import Quickshell.Io
import "../../Singletons"

Item {
    id: root

    required property real s
    required property bool open
    signal requestClose()

    implicitWidth: 320 * s
    implicitHeight: title.implicitHeight + list.implicitHeight + 20 * s

    function clearHistory() {
        history.clear();
    }

    onOpenChanged: if (!open) clearHistory()
    Component.onDestruction: clearHistory()

    ListModel {
        id: history
    }

    Text {
        id: title
        anchors.left: parent.left
        anchors.right: parent.right
        text: qsTr("Clipboard history")
        color: Theme.bright
        font.family: Theme.display
        font.pixelSize: 18 * root.s
    }

    Column {
        id: list
        anchors {
            top: title.bottom
            left: parent.left
            right: parent.right
            topMargin: 10 * root.s
        }
        spacing: 4 * root.s

        Repeater {
            model: history

            delegate: Rectangle {
                required property string entryId
                required property string label

                width: list.width
                height: labelText.implicitHeight + 12 * root.s
                radius: Theme.radius
                color: mouse.containsMouse ? Theme.frameBg : Theme.tileBg

                Text {
                    id: labelText
                    anchors {
                        verticalCenter: parent.verticalCenter
                        left: parent.left
                        right: parent.right
                        margins: 6 * root.s
                    }
                    text: model.label
                    color: Theme.bright
                    font.family: Theme.font
                    font.pixelSize: 11 * root.s
                    elide: Text.ElideRight
                }

                MouseArea {
                    id: mouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                        copy.command = ["sh", "-c", "cliphist decode \"$1\" | wl-copy", "_", model.entryId];
                        copy.running = true;
                        root.requestClose();
                    }
                }
            }
        }

        Text {
            visible: root.open && history.count === 0 && !cliphist.running
            width: list.width
            text: qsTr("No clipboard history")
            color: Theme.dim
            font.family: Theme.font
            font.pixelSize: 11 * root.s
        }
    }

    Process {
        id: cliphist
        command: ["cliphist", "list"]
        running: root.open
        stdout: StdioCollector {
            onStreamFinished: {
                if (!root.open)
                    return;
                history.clear();
                for (const line of text.split("\n")) {
                    const tab = line.indexOf("\t");
                    if (tab > 0)
                        history.append({ entryId: line.slice(0, tab), label: line.slice(tab + 1) });
                }
            }
        }
    }

    Process {
        id: copy
    }
}
