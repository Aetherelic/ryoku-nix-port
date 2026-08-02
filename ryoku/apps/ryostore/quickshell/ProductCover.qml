import QtQuick
import Ryoku.Ui.Singletons
import "lib/store.js" as StoreLogic

Item {
    id: cover

    required property var item
    property bool stage: false
    property bool selected: false
    property bool active: true

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

    Rectangle {
        anchors.fill: parent
        color: cover.coverSurface
        gradient: Gradient {
            GradientStop {
                position: 0
                color: Qt.rgba(cover.coverAccent.r, cover.coverAccent.g,
                               cover.coverAccent.b, 0.42)
            }
            GradientStop { position: 0.54; color: cover.coverSurface }
            GradientStop {
                position: 1
                color: Qt.darker(cover.coverSurface, 1.7)
            }
        }
    }

    Rectangle {
        width: parent.width * 0.82
        height: width
        anchors.centerIn: parent
        visible: !cover.hasArtwork
        rotation: -18
        radius: width / 2
        color: "transparent"
        border.width: Math.max(1, Tokens.border)
        border.color: Qt.rgba(cover.coverAccent.r, cover.coverAccent.g,
                              cover.coverAccent.b, 0.45)
    }

    Text {
        anchors.centerIn: parent
        visible: !cover.hasArtwork
        text: cover.coverTitle.slice(0, 2).toUpperCase()
        color: Qt.rgba(cover.coverAccent.r, cover.coverAccent.g,
                       cover.coverAccent.b, 0.78)
        font.family: Tokens.display
        font.pixelSize: Math.max(Tokens.fHero, Math.min(parent.width, parent.height) * 0.28)
        font.weight: Font.Black
        font.letterSpacing: -2
    }

    ProductMedia {
        anchors.fill: parent
        source: cover.hasArtwork ? cover.item.art : ""
        immersive: cover.stage
        active: cover.active
    }

    Rectangle {
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: Math.min(parent.height * 0.56, 124)
        visible: cover.hasIdentity && !cover.stage
        gradient: Gradient {
            GradientStop { position: 0; color: "transparent" }
            GradientStop { position: 0.62; color: "#b8000000" }
            GradientStop { position: 1; color: "#ed000000" }
        }
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
            color: "#f5f3ef"
            font.family: Tokens.display
            font.pixelSize: Tokens.fRow
            font.weight: Font.DemiBold
            elide: Text.ElideRight
        }

        Text {
            width: parent.width
            text: String(cover.item && (cover.item.categoryName || cover.item.category) || "").toUpperCase()
            color: "#b8ffffff"
            font.family: Tokens.mono
            font.pixelSize: Tokens.fMicro
            font.letterSpacing: Tokens.trackLabel
            elide: Text.ElideRight
        }
    }

    Rectangle {
        anchors.fill: parent
        color: "transparent"
        border.width: cover.selected ? Tokens.border * 2 : (cover.stage ? 0 : Tokens.border)
        border.color: cover.selected ? Tokens.ink : "#24ffffff"
    }
}
