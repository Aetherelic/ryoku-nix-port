import QtQuick
import "../kit"
import "../../modules"
import Ryoku.Ui.Singletons

// Workspaces editor: pick how many workspaces the bar shows (COUNT) and how
// their markers look (MARKER), with a live preview row that mirrors the bar's
// own WorkspaceWidget rendering. Reads/writes root.workspaceMode + workspaceStyle.
Item {
    id: page
    property var root: null
    property var cc: null

    // Sample ids for the preview: "active" shows a representative trio; the fixed
    // modes show the full 1..N range. Focused = 1, occupied = 2/3, rest empty.
    readonly property var previewList: {
        if (!page.root) return []
        var m = page.root.workspaceMode
        if (m === "active") return [1, 2, 3]
        var n = m === "5" ? 5 : 10
        var list = []
        for (var j = 1; j <= n; j++) list.push(j)
        return list
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
            width: parent.width
            spacing: page.cc ? page.cc.tokens.sectionGap : 16

            CcSection {
                width: parent.width
                root: page.root
                title: I18n.tr("COUNT")
                desc: I18n.tr("How many workspaces the bar shows")
                CcSeg {
                    root: page.root
                    options: [{ key: "active", label: "Active" }, { key: "5", label: "1-5" }, { key: "10", label: "1-10" }]
                    current: page.root ? page.root.workspaceMode : ""
                    onChose: (key) => { if (page.root) page.root.workspaceMode = key }
                }
            }

            CcSection {
                width: parent.width
                root: page.root
                title: I18n.tr("MARKER")
                desc: I18n.tr("The shape each workspace uses in the bar")
                CcSeg {
                    root: page.root
                    options: page.root ? page.root.workspaceStyleOptions : []
                    current: page.root ? page.root.workspaceStyle : ""
                    onChose: (key) => { if (page.root) page.root.workspaceStyle = key }
                }
            }

            CcSection {
                width: parent.width
                root: page.root
                title: I18n.tr("PREVIEW")

                // A bar-like pill wrapping the live marker row, mirroring the
                // real WorkspaceWidget (default glow+dot / numbers badge / magic glyph).
                Rectangle {
                    height: 44
                    width: Math.round(previewRow.implicitWidth) + 24
                    radius: page.root ? page.root.pillRadius : 12
                    color: page.root ? page.root.pill : "transparent"
                    border.width: 1
                    border.color: page.root ? page.root.sep : "transparent"

                    Row {
                        id: previewRow
                        anchors.centerIn: parent
                        spacing: 5

                        Repeater {
                            model: page.previewList

                            delegate: Item {
                                id: cell
                                required property int modelData
                                required property int index
                                readonly property string style: page.root ? page.root.workspaceStyle : "default"
                                readonly property color seal: page.root ? page.root.seal : "#888888"
                                readonly property bool isFocused: modelData === 1
                                readonly property bool isOccupied: modelData === 2 || modelData === 3
                                readonly property bool isEmpty: !isFocused && !isOccupied

                                implicitWidth: style === "numbers" ? 22
                                             : style === "magic"   ? (isFocused ? 20 : 18)
                                             : style === "kanji"   ? 22
                                             : style === "rings"   ? 20
                                             : style === "aurora"  ? (isFocused ? 34 : 12)
                                             : (isFocused ? 32 : 16)
                                implicitHeight: 28

                                Behavior on implicitWidth { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

                                // DEFAULT - glow + dot
                                Rectangle {
                                    visible: cell.style === "default"
                                    anchors.centerIn: parent
                                    width: cell.isFocused ? 34 : 16
                                    height: 16
                                    radius: 8
                                    color: cell.isFocused  ? Qt.rgba(cell.seal.r, cell.seal.g, cell.seal.b, 0.20)
                                         : cell.isOccupied ? Qt.rgba(cell.seal.r, cell.seal.g, cell.seal.b, 0.18)
                                                           : Qt.rgba(cell.seal.r, cell.seal.g, cell.seal.b, 0.06)
                                    Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                                    Behavior on color { ColorAnimation { duration: 200 } }
                                }
                                Rectangle {
                                    visible: cell.style === "default"
                                    anchors.centerIn: parent
                                    width: cell.isFocused ? 26 : 8
                                    height: 8
                                    radius: 4
                                    color: cell.isEmpty ? Qt.rgba(cell.seal.r, cell.seal.g, cell.seal.b, 0.25) : cell.seal
                                    Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                                    Behavior on color { ColorAnimation { duration: 200 } }
                                }

                                // NUMBERS - digit on a rounded badge
                                Rectangle {
                                    visible: cell.style === "numbers"
                                    anchors.centerIn: parent
                                    width: 20
                                    height: 20
                                    radius: height / 2
                                    color: cell.isFocused  ? Qt.rgba(cell.seal.r, cell.seal.g, cell.seal.b, 0.30)
                                         : cell.isOccupied ? Qt.rgba(cell.seal.r, cell.seal.g, cell.seal.b, 0.12)
                                                           : Qt.rgba(cell.seal.r, cell.seal.g, cell.seal.b, 0.04)
                                    Behavior on color { ColorAnimation { duration: 200 } }
                                    UiText {
                                        anchors.centerIn: parent
                                        text: cell.modelData
                                        color: cell.isFocused  ? Qt.lighter(cell.seal, 1.3)
                                             : cell.isOccupied ? Qt.rgba(cell.seal.r, cell.seal.g, cell.seal.b, 0.5)
                                                               : Qt.rgba(cell.seal.r, cell.seal.g, cell.seal.b, 0.28)
                                        font.family: page.root ? page.root.mono : "monospace"
                                        font.pixelSize: cell.isFocused ? 13 : 12
                                        font.weight: cell.isFocused ? Font.Bold : Font.Normal
                                    }
                                }

                                // MAGIC - sparkle glyphs (filled / hollow / dot)
                                Text {
                                    visible: cell.style === "magic"
                                    anchors.centerIn: parent
                                    anchors.verticalCenterOffset: cell.isFocused ? 0 : 1
                                    text: cell.isFocused  ? String.fromCodePoint(0x2726)
                                        : cell.isOccupied ? String.fromCodePoint(0x2727)
                                                          : String.fromCodePoint(0x00B7)
                                    color: cell.isFocused  ? cell.seal
                                         : cell.isOccupied ? Qt.rgba(cell.seal.r, cell.seal.g, cell.seal.b, 0.7)
                                                           : Qt.rgba(cell.seal.r, cell.seal.g, cell.seal.b, 0.3)
                                    font.family: "Adwaita Mono"
                                    // Mirrors WorkspaceWidget's real marker sizes; a
                                    // preview that drifts from the bar is worse than none.
                                    font.pixelSize: cell.isFocused ? 22 : 18
                                    renderType: Text.NativeRendering
                                    Behavior on color { ColorAnimation { duration: 200 } }
                                }

                                // KANJI - 一..十 numerals
                                Text {
                                    visible: cell.style === "kanji"
                                    anchors.centerIn: parent
                                    text: ["一", "二", "三", "四", "五"][cell.index] || ""
                                    color: cell.isFocused  ? cell.seal
                                         : cell.isOccupied ? Qt.rgba(cell.seal.r, cell.seal.g, cell.seal.b, 0.7)
                                                           : Qt.rgba(cell.seal.r, cell.seal.g, cell.seal.b, 0.3)
                                    font.family: "Noto Sans CJK JP"
                                    font.pixelSize: cell.isFocused ? 15 : 13
                                    renderType: Text.NativeRendering
                                }

                                // FRAME - numerals with an outline behind the focused cell
                                Rectangle {
                                    visible: cell.style === "rings"
                                    anchors.centerIn: parent
                                    width: 20
                                    height: 20
                                    radius: page.root ? page.root.tileRadius : 6
                                    color: "transparent"
                                    border.width: cell.isFocused ? 1 : 0
                                    border.color: cell.seal
                                }
                                Text {
                                    visible: cell.style === "rings"
                                    anchors.centerIn: parent
                                    text: String(cell.index + 1)
                                    color: cell.seal
                                    opacity: cell.isFocused ? 1.0 : cell.isOccupied ? 0.64 : 0.24
                                    font.family: page.root ? page.root.mono : "monospace"
                                    font.pixelSize: 12
                                    renderType: Text.QtRendering
                                }

                                // AURORA - one flat light streak
                                Rectangle {
                                    visible: cell.style === "aurora"
                                    anchors.centerIn: parent
                                    width: cell.isFocused ? 28 : (cell.isOccupied ? 6 : 4)
                                    height: cell.isFocused ? 3 : (cell.isOccupied ? 6 : 4)
                                    radius: height / 2
                                    color: cell.seal
                                    opacity: cell.isFocused ? 0.92 : cell.isOccupied ? 0.62 : 0.18
                                    antialiasing: true
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
