import QtQuick
import Ryoku.Ui.Singletons
import "lib/store.js" as StoreLogic

Item {
    id: cover

    required property var item
    property bool stage: false
    property bool selected: false

    readonly property bool hasArtwork: String(item && item.art || "") !== ""
    readonly property bool hasIdentity: Boolean(item && (item.id || item.name))
    readonly property string coverTitle: String(item && (item.name || item.id) || "Untitled")
    readonly property color coverSurface: item && item.surface ? item.surface : Tokens.paperLift
    readonly property color coverAccent: item && item.accent ? item.accent : Tokens.inkDim

    clip: true
    Accessible.role: Accessible.Graphic
    Accessible.ignored: !cover.hasIdentity
    Accessible.name: [
        coverTitle,
        String(item && (item.categoryName || item.category) || ""),
        StoreLogic.statusLabels(item).join(", ")
    ].filter(Boolean).join(", ")

    Image {
        anchors.fill: parent
        visible: cover.hasArtwork
        source: cover.hasArtwork ? cover.item.art : ""
        sourceSize: Qt.size(Math.max(1, width), Math.max(1, height))
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
    }

    Rectangle {
        anchors.fill: parent
        visible: !cover.hasArtwork
        color: cover.coverSurface

        Rectangle {
            anchors { top: parent.top; bottom: parent.bottom; left: parent.left }
            width: 5
            color: cover.coverAccent
        }

        Column {
            objectName: "ryostore-cover-metadata"
            visible: cover.hasIdentity && !cover.stage
            x: Tokens.s3
            width: parent.width - Tokens.s3 * 2
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Tokens.s3
            spacing: Tokens.s1

            Text {
                width: parent.width
                text: cover.coverTitle
                color: Tokens.ink
                font.family: Tokens.display
                font.pixelSize: Tokens.fRow
                font.weight: Font.Medium
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                text: String(cover.item && (cover.item.categoryName || cover.item.category) || "").toUpperCase()
                color: Tokens.inkDim
                font.family: Tokens.mono
                font.pixelSize: Tokens.fMicro
                font.letterSpacing: Tokens.trackLabel
                elide: Text.ElideRight
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        color: "transparent"
        border.width: cover.selected ? Tokens.border * 2 : 0
        border.color: Tokens.ink
    }
}
