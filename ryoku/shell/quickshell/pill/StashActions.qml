pragma ComponentBehavior: Bound

import QtQuick
import "Singletons"

// stash action bar, bottom of the section. five tiles full-width: Send all,
// Text, Download, Compress, Install. one hairline in the middle gap splits
// outgoing actions from the ones that manage what's already here. tiles that
// act on files dim when the stash is empty; Text + Download stay live since
// they bring content in. lift + light on hover, deck idiom.
Item {
    id: root

    property real s: 1
    property bool hasFiles: false
    property bool hasMedia: false
    property bool hasInstallable: false

    signal sendAll()
    signal sendText()
    signal download()
    signal compress()
    signal install()

    implicitHeight: 50 * s

    component ActionTile: Item {
        id: t

        property string glyph: ""
        property string label: ""
        property bool active: true

        signal triggered()

        readonly property bool lit: area.containsMouse && t.active

        height: 50 * root.s
        opacity: active ? 1 : 0.3

        Behavior on opacity { NumberAnimation { duration: Motion.fast; easing.type: Motion.easeStandard } }

        transform: Translate {
            y: t.lit ? -2 * root.s : 0
            Behavior on y { NumberAnimation { duration: Motion.fast; easing.type: Motion.easeStandard } }
        }

        Rectangle {
            id: chip
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            width: 40 * root.s
            height: 34 * root.s
            radius: Theme.radiusWidget
            color: t.lit ? Theme.frameBg : Theme.surfaceContainerHigh
            border.width: 1
            border.color: t.lit ? Theme.frameBorder : Theme.outline

            Behavior on color { ColorAnimation { duration: Motion.fast } }
            Behavior on border.color { ColorAnimation { duration: Motion.fast } }

            GlyphIcon {
                anchors.centerIn: parent
                width: 17 * root.s
                height: 17 * root.s
                name: t.glyph
                color: t.lit ? Theme.onSurface : Theme.onSurfaceVariant
                stroke: 1.7
            }
        }

        Text {
            anchors.top: chip.bottom
            anchors.topMargin: 5 * root.s
            anchors.horizontalCenter: parent.horizontalCenter
            text: t.label
            color: t.lit ? Theme.onSurface : Theme.onSurfaceVariant
            font.family: Theme.fontPrimary
            font.pixelSize: 8.5 * root.s
            font.weight: Font.DemiBold
            font.capitalization: Font.AllUppercase
            font.letterSpacing: 0.6 * root.s
        }

        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            enabled: t.active
            cursorShape: Qt.PointingHandCursor
            onClicked: t.triggered()
        }
    }

    // five tiles, each a fifth of the width, so chips space evenly.
    Row {
        anchors.fill: parent

        ActionTile {
            width: root.width / 5
            glyph: "send"
            label: "Send all"
            active: root.hasFiles
            onTriggered: root.sendAll()
        }
        ActionTile {
            width: root.width / 5
            glyph: "text"
            label: "Text"
            onTriggered: root.sendText()
        }
        ActionTile {
            width: root.width / 5
            glyph: "download"
            label: "Download"
            onTriggered: root.download()
        }
        ActionTile {
            width: root.width / 5
            glyph: "compress"
            label: "Compress"
            active: root.hasMedia
            onTriggered: root.compress()
        }
        ActionTile {
            width: root.width / 5
            glyph: "install"
            label: "Install"
            active: root.hasInstallable
            onTriggered: root.install()
        }
    }

    // hairline in the middle gap: outgoing (Send, Text) | manage (rest).
    Rectangle {
        x: root.width * 0.4 - width / 2
        y: 6 * root.s
        width: 1
        height: 22 * root.s
        color: Theme.outlineVariant
    }
}
