import QtQuick
import QtQuick.Layouts
import "Singletons"
import Ryoku.Ui.Singletons

Item {
    id: sheet

    property var tools: []

    signal closeRequested()

    readonly property var actions: [
        { key: "Ctrl+C", label: "Copy" },
        { key: "Ctrl+S", label: "Save" },
        { key: "Ctrl+P", label: "Pin" },
        { key: "Ctrl+U", label: "Upload" },
        { key: "Ctrl+B", label: "Beautify" },
        { key: "Enter", label: "Copy and save" },
        { key: "Ctrl+Z", label: "Undo" },
        { key: "Ctrl+Shift+Z", label: "Redo" },
        { key: "Ctrl+A", label: "Whole monitor" },
        { key: "Space", label: "Cycle target" },
        { key: "f", label: "Fill" },
        { key: "k", label: "Sketch" },
        { key: "[ ]", label: "Width" },
        { key: "1..8", label: "Colour" },
        { key: "Del", label: "Delete" },
        { key: "Esc", label: "Back" }
    ]

    focus: visible

    component ShortcutRow: RowLayout {
        id: row
        property string label: ""
        property string key: ""
        spacing: 16
        Text {
            Layout.fillWidth: true
            text: I18n.tr(row.label)
            color: Theme.ink
            font.family: Theme.ui
            font.pixelSize: 13
            elide: Text.ElideRight
        }
        Rectangle {
            radius: 4
            color: Theme.hover
            border.color: Theme.hair
            border.width: 1
            implicitWidth: cap.implicitWidth + 12
            implicitHeight: cap.implicitHeight + 6
            Text {
                id: cap
                anchors.centerIn: parent
                text: row.key
                color: Theme.inkDim
                font.family: Theme.mono
                font.pixelSize: 12
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: sheet.closeRequested()
    }

    Rectangle {
        id: card
        anchors.centerIn: parent
        radius: Theme.radius
        color: Theme.panel
        border.color: Theme.hair
        border.width: 1
        implicitWidth: body.implicitWidth + 40
        implicitHeight: body.implicitHeight + 36

        opacity: sheet.visible ? 1 : 0
        scale: sheet.visible ? 1.0 : 0.97
        Behavior on opacity { NumberAnimation { duration: Theme.snap } }
        Behavior on scale { NumberAnimation { duration: Theme.snap } }

        MouseArea { anchors.fill: parent }

        ColumnLayout {
            id: body
            anchors.centerIn: parent
            spacing: 14

            Text {
                text: I18n.tr("Shortcuts")
                color: Theme.ink
                font.family: Theme.ui
                font.pixelSize: 18
                font.weight: Font.DemiBold
            }

            GridLayout {
                columns: 2
                columnSpacing: 40
                rowSpacing: 8
                Repeater {
                    model: sheet.tools
                    ShortcutRow {
                        Layout.preferredWidth: 200
                        label: modelData.label
                        key: modelData.key
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Theme.hair
            }

            GridLayout {
                columns: 2
                columnSpacing: 40
                rowSpacing: 8
                Repeater {
                    model: sheet.actions
                    ShortcutRow {
                        Layout.preferredWidth: 200
                        label: modelData.label
                        key: modelData.key
                    }
                }
            }
        }
    }

    Keys.onPressed: (e) => {
        if (e.key === Qt.Key_Escape) {
            e.accepted = true;
            sheet.closeRequested();
        }
    }
}
