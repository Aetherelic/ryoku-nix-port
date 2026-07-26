pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Ryoku.Ui
import Ryoku.Ui.Singletons
import "../barstudio"
import Ryoku.FrameBars
import "../barstudio/BarStudioModel.js" as Model

Item {
    id: page
    required property var hub
    readonly property bool fullBleed: true
    readonly property var config: page.hub ? page.hub.val("frameBars") : null

    function stage(next) {
        if (page.hub && next) page.hub.edit("frameBars", next);
    }

    CatalogLabels { id: labels }

    ScrollView {
        anchors.fill: parent
        contentWidth: availableWidth
        ColumnLayout {
            width: parent.width
            spacing: Tokens.s4

            Text {
                Layout.fillWidth: true
                text: qsTr("Bar Studio")
                font.family: Tokens.display
                font.pixelSize: Tokens.fTitle
                wrapMode: Text.Wrap
            }
            Text {
                Layout.fillWidth: true
                text: qsTr("Arrange the bounded frame rails, menus, surfaces, styles, and catalogue.")
                wrapMode: Text.Wrap
            }
            RowLayout {
                Layout.fillWidth: true
                Text { text: qsTr("Styles") }
                Btn { text: labels.style("ok-frame"); primary: page.config.style === "ok-frame"; onAct: page.stage(Model.setStyle(page.config, "ok-frame")) }
                Btn { text: labels.style("ryoku-frame"); primary: page.config.style === "ryoku-frame"; onAct: page.stage(Model.setStyle(page.config, "ryoku-frame")) }
            }
            Text { text: qsTr("Rails"); font.family: Tokens.ui; font.pixelSize: Tokens.fValue }
            Repeater {
                model: ["top", "left", "bottom", "right"]
                delegate: ColumnLayout {
                    required property string modelData
                    Layout.fillWidth: true
                    RailEditor { Layout.fillWidth: true; config: page.config; edge: modelData; hub: page.hub; onStaged: next => page.stage(next) }
                    ZoneEditor { Layout.fillWidth: true; config: page.config; edge: modelData; catalog: BarCatalog; onStaged: next => page.stage(next) }
                }
            }
            Text { text: qsTr("Menus"); font.family: Tokens.ui; font.pixelSize: Tokens.fValue }
            MenuEditor { Layout.fillWidth: true; config: page.config; catalog: MenuCatalog; onStaged: next => page.stage(next) }
            Text { text: qsTr("Frame Surfaces"); font.family: Tokens.ui; font.pixelSize: Tokens.fValue }
            SurfaceEditor { Layout.fillWidth: true; config: page.config; catalog: MenuCatalog; onStaged: next => page.stage(next) }
            Text { text: qsTr("Catalogue"); font.family: Tokens.ui; font.pixelSize: Tokens.fValue }
            CatalogPanel { Layout.fillWidth: true; barCatalog: BarCatalog; menuCatalog: MenuCatalog }
        }
    }
}