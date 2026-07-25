pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Ryoku.Ui.Singletons

ColumnLayout {
    id: root
    required property var barCatalog
    required property var menuCatalog
    spacing: Tokens.s2

    Label { text: qsTr("Catalogue"); font: Tokens.ui }
    Label {
        Layout.fillWidth: true
        wrapMode: Text.Wrap
        text: qsTr("Only catalogued widgets, menus, anchors, panes, and frame surfaces can be saved.")
    }
    Label { text: qsTr("Bar widgets: %1").arg(root.barCatalog.ids().join(", ")) }
    Label { text: qsTr("Menu widgets: %1").arg(root.menuCatalog.widgetIds().join(", ")) }
}
