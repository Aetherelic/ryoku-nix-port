pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Ryoku.Ui.Singletons

ColumnLayout {
    id: root
    required property var barCatalog
    required property var menuCatalog
    spacing: Tokens.s2

    CatalogLabels { id: labels }

    Text { text: qsTr("Catalogue"); font.family: Tokens.ui }
    Text {
        Layout.fillWidth: true
        wrapMode: Text.Wrap
        text: qsTr("Only catalogued widgets, menus, anchors, panes, and frame surfaces can be saved.")
    }
    Text { Layout.fillWidth: true; wrapMode: Text.Wrap; text: qsTr("Bar widgets: %1").arg(root.barCatalog.ids().map(id => labels.item(id)).join(", ")) }
    Text { Layout.fillWidth: true; wrapMode: Text.Wrap; text: qsTr("Menu widgets: %1").arg(root.menuCatalog.widgetIds().map(id => labels.item(id)).join(", ")) }
}