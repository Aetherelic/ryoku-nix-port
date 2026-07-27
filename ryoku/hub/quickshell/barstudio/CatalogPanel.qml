pragma ComponentBehavior: Bound

import QtQuick
import Ryoku.Ui.Singletons

// The catalogue, stated: what the studio can save. Two wrapped tag flows, one
// for the rail widgets and one for the menu widgets; tags are ink, not
// controls, so they carry no hover grammar.
Column {
    id: root
    required property var barCatalog
    required property var menuCatalog
    spacing: Tokens.s3

    CatalogLabels { id: labels }

    Text {
        width: parent.width
        wrapMode: Text.WordWrap
        text: qsTr("Only catalogued widgets, menus, anchors, panes and frame surfaces can be saved; anything else is dropped on write.")
        color: Tokens.inkMuted
        font.family: Tokens.ui
        font.pixelSize: Tokens.fSmall
    }

    StripHead { width: parent.width; label: qsTr("BAR WIDGETS"); count: String(root.barCatalog.ids().length) }
    Flow {
        width: parent.width
        spacing: 5
        Repeater {
            model: root.barCatalog.ids()
            delegate: Rectangle {
                required property string modelData
                width: tag.implicitWidth + 16
                height: 22
                radius: Tokens.radius
                color: "transparent"
                border.width: Tokens.border
                border.color: Tokens.lineSoft
                Text {
                    id: tag
                    anchors.centerIn: parent
                    text: labels.item(parent.modelData)
                    color: Tokens.inkMuted
                    font.family: Tokens.ui
                    font.pixelSize: 10
                }
            }
        }
    }

    StripHead { width: parent.width; label: qsTr("MENU WIDGETS"); count: String(root.menuCatalog.widgetIds().length) }
    Flow {
        width: parent.width
        spacing: 5
        Repeater {
            model: root.menuCatalog.widgetIds()
            delegate: Rectangle {
                required property string modelData
                width: tag.implicitWidth + 16
                height: 22
                radius: Tokens.radius
                color: "transparent"
                border.width: Tokens.border
                border.color: Tokens.lineSoft
                Text {
                    id: tag
                    anchors.centerIn: parent
                    text: labels.item(parent.modelData)
                    color: Tokens.inkMuted
                    font.family: Tokens.ui
                    font.pixelSize: 10
                }
            }
        }
    }
}
