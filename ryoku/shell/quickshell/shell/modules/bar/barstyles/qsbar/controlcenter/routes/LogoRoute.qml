import QtQuick
import "../kit"
import "../../modules"
import Ryoku.Ui
import Ryoku.Ui.Singletons

// LOGO route (id "logo"): choose the launcher mark. First the format - a
// wordmark or a kanji glyph (launcherLogoMode "text" | "icon") - then a grid of
// the chosen format's options (launcherLogoText / launcherLogoIcon). Only the
// grid for the active format shows, because the other format's options cannot
// apply. Every tile previews the option exactly as LauncherWidget.qml draws it,
// so the choice is honest, and each tile shows the mark once - never the mark
// beside a text copy of its own name.
Item {
    id: page
    property var root: null
    property var cc: null
    readonly property var tk: cc ? cc.tokens : null
    readonly property real colW: tk ? Math.min(page.width, tk.contentW) : page.width

    readonly property string mode: page.root ? String(page.root.launcherLogoMode || "text") : "text"
    readonly property var activeOptions: page.root
        ? (page.mode === "icon" ? page.root.launcherLogoIconOptions : page.root.launcherLogoTextOptions)
        : []

    implicitHeight: col.implicitHeight

    // A hairline preview card whose selection reads as a bone ring plus a bone
    // corner tag, so the chosen mark stays legible instead of being swallowed by
    // an inverted plate. Emphasis is inversion elsewhere; here the mark IS data,
    // so the card keeps paper and only the frame carries the state.
    component MarkTag: Rectangle {
        property bool on: false
        visible: on
        anchors.right: parent.right
        anchors.top: parent.top
        width: page.tk ? page.tk.gap : 12
        height: width
        radius: page.tk ? Tokens.radius / 2 : 2
        color: page.tk ? Tokens.bone : "#cdc4ba"
    }

    Flickable {
        id: flick
        anchors.fill: parent
        contentWidth: width
        contentHeight: col.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: col
            width: page.colW
            spacing: page.tk ? page.tk.sectionGap : 24

            // ── format ──────────────────────────────────────────────────────
            Entrance {
                width: page.colW
                index: 0
                SettingCard {
                    width: page.colW
                    title: "Mark"
                    kana: "\u5370"

                    Row {
                    width: parent.width
                        spacing: page.tk ? page.tk.colGap : 16

                        Repeater {
                            model: [
                                { mode: "text", label: "Wordmark", glyph: "RYOKU" },
                                { mode: "icon", label: "Glyph",    glyph: "\u529b" }
                            ]

                            delegate: Rectangle {
                                id: markCard
                                required property var modelData
                                readonly property bool selected: page.mode === modelData.mode
                                readonly property bool iconMode: modelData.mode === "icon"

                            width: (parent.width - (page.tk ? page.tk.colGap : 16)) / 2
                                height: page.tk ? page.tk.rowH * 3 : 120
                                radius: page.tk ? Tokens.radius : 6
                                color: markCardMa.containsMouse ? (page.tk ? Tokens.tint5 : "#111111") : "transparent"
                                border.width: markCard.selected ? 2 : 1
                                border.color: markCard.selected ? (page.tk ? Tokens.bone : "#cdc4ba")
                                    : markCardMa.containsMouse ? (page.tk ? Tokens.ink : "#cccccc")
                                    : (page.tk ? Tokens.line : "#333333")
                                Behavior on border.color { ColorAnimation { duration: page.tk ? Tokens.move : 160 } }
                                Behavior on color { ColorAnimation { duration: page.tk ? Tokens.move : 160 } }

                                MarkTag { on: markCard.selected }

                                // The real launcher pill, faithful to LauncherWidget.qml (data).
                                Rectangle {
                                    id: pill
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.verticalCenterOffset: page.tk ? -page.tk.gap : -12
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

                                // The format's name - the fact this card chooses, not
                                // a second copy of the mark.
                                UiText {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    anchors.bottom: parent.bottom
                                    anchors.bottomMargin: page.tk ? page.tk.gap : 12
                                    text: I18n.tr(markCard.modelData.label)
                                    color: page.tk ? (markCard.selected ? Tokens.ink : Tokens.inkMuted) : "#cccccc"
                                    font.family: page.tk ? Tokens.mono : "monospace"
                                    font.pixelSize: page.tk ? Tokens.fSmall : 13
                                    font.letterSpacing: page.tk ? Tokens.trackLabel : 1
                                    font.weight: markCard.selected ? Font.DemiBold : Font.Normal
                                }

                                MouseArea {
                                    id: markCardMa
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
            }

            // ── the active format's options ───────────────────────────────────
            Entrance {
                width: page.colW
                index: 1
                SettingCard {
                    width: page.colW
                    title: page.mode === "icon" ? "GLYPH" : "WORDMARK"
                    kana: page.mode === "icon" ? "\u7d0b" : "\u6587\u5b57"

                    Grid {
                        id: optGrid
                    width: parent.width
                        columns: 4
                        columnSpacing: page.tk ? page.tk.colGap : 16
                        rowSpacing: page.tk ? page.tk.colGap : 16
                        readonly property real cellW: (width - columnSpacing * (columns - 1)) / columns

                        Repeater {
                            model: page.activeOptions

                            delegate: Rectangle {
                                id: optCard
                                required property string modelData
                                readonly property bool iconMode: page.mode === "icon"
                                readonly property bool selected: (iconMode
                                    ? (page.root ? page.root.launcherLogoIcon : "")
                                    : (page.root ? page.root.launcherLogoText : "")) === modelData

                            width: optGrid.cellW
                                height: page.tk ? page.tk.rowH * 2 : 80
                                radius: page.tk ? Tokens.radius : 6
                                color: optMa.containsMouse ? (page.tk ? Tokens.tint5 : "#111111") : "transparent"
                                border.width: optCard.selected ? 2 : 1
                                border.color: optCard.selected ? (page.tk ? Tokens.bone : "#cdc4ba")
                                    : optMa.containsMouse ? (page.tk ? Tokens.ink : "#cccccc")
                                    : (page.tk ? Tokens.line : "#333333")
                                Behavior on border.color { ColorAnimation { duration: page.tk ? Tokens.move : 160 } }
                                Behavior on color { ColorAnimation { duration: page.tk ? Tokens.move : 160 } }

                                MarkTag { on: optCard.selected }

                                // The mark, previewed once, exactly as the bar draws it (data).
                                Text {
                                    id: optMark
                                    anchors.centerIn: parent
                                width: parent.width - (page.tk ? page.tk.gap * 2 : 14)
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
    }

    CcScrollRail { root: page.root; flick: flick; z: 5 }
}
