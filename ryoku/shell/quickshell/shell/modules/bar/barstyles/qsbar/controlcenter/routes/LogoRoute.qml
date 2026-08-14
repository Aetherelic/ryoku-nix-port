import QtQuick
import "../kit"
import "../../modules"
import Ryoku.Ui.Singletons

// Logo route - choose the launcher mark shown on the bar: first the format
// (launcherLogoMode "text" wordmark | "icon" glyph), then a grid of the active
// format's options (launcherLogoText / launcherLogoIcon). Every cell previews
// the option as LauncherWidget.qml will draw it, so the choice is honest.
Item {
    id: page
    property var root: null
    property var cc: null

    readonly property string mode: page.root ? String(page.root.launcherLogoMode || "text") : "text"
    readonly property var activeOptions: page.root
        ? (page.mode === "icon" ? page.root.launcherLogoIconOptions : page.root.launcherLogoTextOptions)
        : []

    Flickable {
        id: flick
        anchors.fill: parent
        contentWidth: width
        contentHeight: col.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: col
            width: parent.width
            spacing: page.cc ? page.cc.tokens.sectionGap : 16

            CcSection {
                width: parent.width
                root: page.root
                title: I18n.tr("LAUNCHER MARK")
                desc: I18n.tr("Pick the mark shown in the bar launcher pill")

                Row {
                    width: parent.width
                    spacing: page.cc ? page.cc.tokens.colGap : 14

                    Repeater {
                        model: [
                            { mode: "text", label: "Wordmark", glyph: "RYOKU" },
                            { mode: "icon", label: "Kanji 力",  glyph: "力" }
                        ]

                        delegate: Rectangle {
                            id: markCard
                            required property var modelData
                            readonly property bool selected: page.mode === modelData.mode
                            readonly property bool iconMode: modelData.mode === "icon"

                            width: (parent.width - (page.cc ? page.cc.tokens.colGap : 14)) / 2
                            height: 132
                            radius: page.root ? page.root.tileRadius : 10
                            color: page.root
                                ? (selected || cardMa.containsMouse ? page.root.fillHover : page.root.fillIdle)
                                : "#1a1a1a"
                            border.width: selected ? 2 : 1
                            border.color: page.root
                                ? (selected ? page.root.seal
                                   : (cardMa.containsMouse ? Qt.rgba(page.root.ink.r, page.root.ink.g, page.root.ink.b, 0.28) : page.root.sep))
                                : "#333333"

                            Behavior on border.color { ColorAnimation { duration: 160 } }
                            Behavior on color { ColorAnimation { duration: 160 } }

                            // The real launcher pill, faithful to LauncherWidget.qml.
                            Rectangle {
                                id: pill
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.top: parent.top
                                anchors.topMargin: 30
                                width: mark.implicitWidth + 12
                                height: page.root ? page.root.pillH : 20
                                radius: page.root ? page.root.pillRadius : 8
                                color: page.root ? page.root.pill : "#222222"
                                border.color: page.root ? page.root.pillBorder : "#333333"
                                border.width: page.root ? page.root.pillBorderW : 1

                                Text {
                                    id: mark
                                    anchors.centerIn: parent
                                    text: markCard.modelData.glyph
                                    color: page.root ? page.root.seal : "#c0392b"
                                    renderType: Text.NativeRendering
                                    font.family: markCard.iconMode
                                        ? "Noto Sans CJK JP"
                                        : (page.root ? page.root.mono : "monospace")
                                    // Matches LauncherWidget's real mark size per mode.
                                    font.pixelSize: markCard.iconMode ? 15 : 12
                                    font.weight: Font.Bold
                                    font.letterSpacing: markCard.iconMode ? 0 : 2
                                }
                            }

                            UiText {
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: 14
                                text: I18n.tr(markCard.modelData.label)
                                color: page.root
                                    ? (markCard.selected ? page.root.seal : page.root.ink)
                                    : "#cccccc"
                                font.family: page.root ? page.root.mono : "monospace"
                                font.pixelSize: 12
                                font.letterSpacing: 1
                                font.weight: markCard.selected ? Font.DemiBold : Font.Normal
                            }

                            MouseArea {
                                id: cardMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (page.root) page.root.launcherLogoMode = markCard.modelData.mode
                                }
                            }
                        }
                    }
                }
            }

            CcSection {
                width: parent.width
                root: page.root
                title: I18n.tr(page.mode === "icon" ? "ICON" : "WORDMARK")
                desc: I18n.tr("Pick which mark fills the selected format")

                Flow {
                    width: parent.width
                    spacing: page.cc ? page.cc.tokens.colGap : 14

                    Repeater {
                        model: page.activeOptions

                        delegate: Rectangle {
                            id: optCard
                            required property string modelData
                            readonly property bool iconMode: page.mode === "icon"
                            readonly property bool selected: (iconMode
                                ? (page.root ? page.root.launcherLogoIcon : "")
                                : (page.root ? page.root.launcherLogoText : "")) === modelData

                            width: (parent.width - (page.cc ? page.cc.tokens.colGap : 14) * 3) / 4
                            height: 84
                            radius: page.root ? page.root.tileRadius : 10
                            color: page.root
                                ? (selected || optMa.containsMouse ? page.root.fillHover : page.root.fillIdle)
                                : "#1a1a1a"
                            border.width: selected ? 2 : 1
                            border.color: page.root
                                ? (selected ? page.root.seal
                                   : (optMa.containsMouse ? Qt.rgba(page.root.ink.r, page.root.ink.g, page.root.ink.b, 0.28) : page.root.sep))
                                : "#333333"

                            Behavior on border.color { ColorAnimation { duration: 160 } }
                            Behavior on color { ColorAnimation { duration: 160 } }

                            // Preview the option exactly as the bar will draw it.
                            Text {
                                id: optMark
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.top: parent.top
                                anchors.topMargin: 16
                                width: parent.width - 14
                                horizontalAlignment: Text.AlignHCenter
                                text: optCard.iconMode
                                    ? (page.root ? page.root.launcherLogoIconGlyph(optCard.modelData) : "")
                                    : (page.root ? page.root.launcherLogoTextLabel(optCard.modelData) : optCard.modelData)
                                color: page.root ? page.root.seal : "#c0392b"
                                renderType: Text.NativeRendering
                                font.family: optCard.iconMode
                                    ? (page.root ? page.root.launcherLogoIconFont(optCard.modelData) : "monospace")
                                    : (page.root ? page.root.mono : "monospace")
                                font.pixelSize: optCard.iconMode
                                    ? (page.root ? page.root.launcherLogoIconSize(optCard.modelData) : 15)
                                    : 12
                                font.weight: Font.Bold
                                font.letterSpacing: optCard.iconMode ? 0 : 2
                                fontSizeMode: Text.HorizontalFit
                                minimumPixelSize: 7
                            }

                            UiText {
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: 12
                                width: parent.width - 12
                                horizontalAlignment: Text.AlignHCenter
                                text: optCard.modelData.toUpperCase()
                                color: page.root
                                    ? (optCard.selected ? page.root.seal : page.root.ink)
                                    : "#cccccc"
                                font.family: page.root ? page.root.mono : "monospace"
                                font.pixelSize: 10
                                font.letterSpacing: 1
                                font.weight: optCard.selected ? Font.DemiBold : Font.Normal
                                elide: Text.ElideRight
                            }

                            MouseArea {
                                id: optMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (!page.root) return
                                    if (optCard.iconMode) page.root.launcherLogoIcon = optCard.modelData
                                    else page.root.launcherLogoText = optCard.modelData
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    CcScrollRail { root: page.root; flick: flick; z: 5 }
}
