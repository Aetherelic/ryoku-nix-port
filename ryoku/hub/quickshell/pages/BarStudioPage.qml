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
                Btn { text: labels.style("slate-frame"); primary: page.config.style === "slate-frame"; onAct: page.stage(Model.setStyle(page.config, "slate-frame")) }
                Btn { text: labels.style("ryoku-frame"); primary: page.config.style === "ryoku-frame"; onAct: page.stage(Model.setStyle(page.config, "ryoku-frame")) }
            }
            // Frame appearance: the running shell reads these top-level
            // shell.json keys (pill/Singletons/Config.qml -> Theme.qml) for the
            // frame's draw toggle, corner radii, border, window opacity and
            // interface font. The frame-bars refactor left them without a
            // control; they belong here on the frame's own studio and route
            // through the settings daemon like every other shell key.
            Text { text: qsTr("Frame"); font.family: Tokens.ui; font.pixelSize: Tokens.fValue }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: Tokens.s2
                RowLayout {
                    Layout.fillWidth: true
                    Text { text: qsTr("Draw frame"); Layout.fillWidth: true }
                    Sw {
                        on: page.hub ? !!page.hub.val("frameEnabled") : true
                        onToggled: v => { if (page.hub) page.hub.edit("frameEnabled", v); }
                    }
                }
                RowLayout {
                    Layout.fillWidth: true
                    Text { text: qsTr("Widget radius"); Layout.fillWidth: true }
                    Text { text: page.hub ? String(page.hub.val("roundness")) : ""; font.family: Tokens.mono }
                    Step {
                        from: 0; to: 1000
                        value: page.hub ? (Number(page.hub.val("roundness")) || 0) : 0
                        onModified: v => { if (page.hub) page.hub.edit("roundness", v); }
                    }
                }
                RowLayout {
                    Layout.fillWidth: true
                    Text { text: qsTr("Window radius"); Layout.fillWidth: true }
                    Text { text: page.hub ? String(page.hub.val("frameRadius")) : ""; font.family: Tokens.mono }
                    Step {
                        from: 0; to: 1000
                        value: page.hub ? (Number(page.hub.val("frameRadius")) || 0) : 0
                        onModified: v => { if (page.hub) page.hub.edit("frameRadius", v); }
                    }
                }
                RowLayout {
                    Layout.fillWidth: true
                    Text { text: qsTr("Border width"); Layout.fillWidth: true }
                    Text { text: page.hub ? String(page.hub.val("frameBorder")) : ""; font.family: Tokens.mono }
                    Step {
                        from: 0; to: 200
                        value: page.hub ? (Number(page.hub.val("frameBorder")) || 0) : 0
                        onModified: v => { if (page.hub) page.hub.edit("frameBorder", v); }
                    }
                }
                RowLayout {
                    Layout.fillWidth: true
                    Text { text: qsTr("Window opacity"); Layout.fillWidth: true }
                    Slid {
                        Layout.preferredWidth: 160
                        from: 0.5; to: 1.0
                        value: page.hub ? (Number(page.hub.val("frameOpacity")) || 1) : 1
                        onModified: v => { if (page.hub) page.hub.edit("frameOpacity", v); }
                    }
                }
                RowLayout {
                    Layout.fillWidth: true
                    Text { text: qsTr("Interface font"); Layout.fillWidth: true }
                    Rectangle {
                        Layout.preferredWidth: 220
                        Layout.preferredHeight: 30
                        color: "transparent"
                        radius: Tokens.radius
                        border.width: ffi.activeFocus ? 2 : Tokens.border
                        border.color: ffi.activeFocus ? Tokens.ink : Tokens.line
                        TextInput {
                            id: ffi
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            verticalAlignment: Text.AlignVCenter
                            clip: true
                            color: Tokens.ink
                            font.family: Tokens.ui
                            font.pixelSize: 12
                            selectByMouse: true
                            text: page.hub ? String(page.hub.val("fontFamily")) : ""
                            onEditingFinished: { if (page.hub) page.hub.edit("fontFamily", text); }
                        }
                    }
                }
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