pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "Singletons"

// the sidebar's quick-action strip: screen-capture helpers (Lens, Color, OCR,
// QR) plus a Mirror toggle and a Clipboard-history button, as a flat tile row
// with hairline dividers over a Ryoku wave. each capture tile runs a
// self-contained ~/.config/hypr/scripts helper and closes the sidebar
// (requestClose) so the action owns the whole screen; Mirror toggles the Camera
// self-view overlay, and the Clipboard tile emits clipboardRequested.
Item {
    id: tools

    property real s: 1
    signal requestClose()
    signal clipboardRequested()

    implicitHeight: strip.height

    readonly property string scripts: (Quickshell.env("HOME") || "") + "/.config/hypr/scripts/"

    readonly property var items: [
        { "key": "lens",   "glyph": "lens",       "label": "Lens",   "argv": [tools.scripts + "ryoku-cmd-google-lens"] },
        { "key": "color",  "glyph": "eyedropper", "label": "Color",  "argv": [tools.scripts + "ryoku-cmd-color-picker"] },
        { "key": "ocr",    "glyph": "ocr",        "label": "OCR",    "argv": [tools.scripts + "ryoku-cmd-ocr"] },
        { "key": "mirror", "glyph": "webcam",     "label": "Mirror", "cam": true },
        { "key": "qr",     "glyph": "qr",         "label": "QR",     "argv": [tools.scripts + "ryoku-cmd-qr-scan"] },
        { "key": "clip",   "glyph": "clipboard",  "label": "Clipboard", "clip": true }
    ]

    property string hovered: ""
    property var pendingArgv: null

    // tools grab the screen (slurp region, hyprpicker freeze) and the deck
    // holds exclusive focus -- it would be frozen into the pick. close, let
    // the morph settle, then launch.
    function launch(argv) {
        tools.pendingArgv = argv;
        tools.requestClose();
        launchTimer.restart();
    }
    Timer {
        id: launchTimer
        interval: 400
        onTriggered: {
            if (tools.pendingArgv) {
                Quickshell.execDetached(tools.pendingArgv);
                tools.pendingArgv = null;
            }
        }
    }

    Item {
        id: strip
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 58 * tools.s

        // five tiles spread evenly across the full column width, hairline
        // split between each. slot width is derived so the strip fills the
        // column edge-to-edge instead of floating as a centred cluster.
        readonly property real slotW: width / tools.items.length

        Repeater {
            model: tools.items

            delegate: Item {
                id: tile
                required property var modelData
                required property int index

                readonly property bool lit: tools.hovered === tile.modelData.key

                width: strip.slotW
                height: strip.height
                x: index * strip.slotW

                transform: Translate {
                    y: tile.lit ? -3 * tools.s : 0
                    Behavior on y { NumberAnimation { duration: Motion.fast; easing.type: Motion.easeStandard } }
                }

                Rectangle {
                    id: btn
                    anchors.top: parent.top
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 38 * tools.s
                    height: 38 * tools.s
                    radius: Theme.radiusWidget
                    color: tile.lit ? Theme.frameBg : "transparent"
                    border.width: 1
                    border.color: tile.lit ? Theme.frameBorder : Theme.outline
                    Behavior on color { ColorAnimation { duration: Motion.fast } }
                    Behavior on border.color { ColorAnimation { duration: Motion.fast } }

                    GlyphIcon {
                        anchors.centerIn: parent
                        width: 15 * tools.s
                        height: 15 * tools.s
                        name: tile.modelData.glyph
                        color: tile.lit ? Theme.onSurface : Theme.onSurfaceVariant
                        stroke: 1.6
                    }
                }

                Text {
                    anchors.top: btn.bottom
                    anchors.topMargin: 6 * tools.s
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: tile.modelData.label
                    color: tile.lit ? Theme.onSurface : Theme.onSurfaceVariant
                    font.family: Theme.fontPrimary
                    font.pixelSize: 9.5 * tools.s
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: tools.hovered = tile.modelData.key
                    onExited: if (tools.hovered === tile.modelData.key) tools.hovered = ""
                    onClicked: {
                        if (tile.modelData.clip)
                            tools.clipboardRequested();
                        else if (tile.modelData.cam) {
                            Camera.toggle();
                            tools.requestClose();
                        } else {
                            tools.launch(tile.modelData.argv);
                        }
                    }
                }

                // hairline divider on the leading edge of every slot but the first.
                Rectangle {
                    visible: tile.index > 0
                    width: 1
                    height: 22 * tools.s
                    color: Theme.outlineVariant
                    x: 0
                    y: (btn.height - height) / 2
                }
            }
        }
    }
}
