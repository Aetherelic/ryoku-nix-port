import QtQuick
import "../modules"
import Ryoku.Ui.Singletons

// Hosts the active route in a Loader and slides the change laterally. The
// outgoing page leaves to the left and the incoming one enters from the right on
// the house spatial curve, so a route change reads as one continuous move rather
// than a cut or a cross-fade. The swap happens while the page is off the plate,
// so there is no seam and no flicker. No scale (a settings page that zooms reads
// as a slideshow) and no opacity fade. Loaded pages get `root` and `cc` as
// initial properties, and report their natural height back through `pageHeight`
// so the plate can size itself.
Item {
    id: stage
    property var root
    property var cc
    property url pageUrl
    property int outMs: 160
    property int inMs: 240
    clip: true

    readonly property var item: ld.item
    // 0 until a page reports a height; the plate falls back to the rail's.
    readonly property real pageHeight: (ld.item && ld.item.implicitHeight > 0) ? ld.item.implicitHeight : 0

    onPageUrlChanged: seq.restart()

    Loader {
        id: ld
        width: stage.width
        height: stage.height
        onLoaded: {
            if (item) {
                if (item.hasOwnProperty("root")) item.root = stage.root
                if (item.hasOwnProperty("cc")) item.cc = stage.cc
            }
        }
    }

    SequentialAnimation {
        id: seq
        NumberAnimation { target: ld; property: "x"; to: -stage.width; duration: stage.outMs; easing.type: Easing.InCubic }
        ScriptAction {
            script: {
                if (String(stage.pageUrl) !== "") ld.setSource(stage.pageUrl, { root: stage.root, cc: stage.cc })
                else ld.source = ""
                ld.x = stage.width
            }
        }
        NumberAnimation {
            target: ld; property: "x"; to: 0; duration: stage.inMs
            easing.type: Easing.Bezier
            easing.bezierCurve: Tokens.curveDefaultSpatial
        }
    }
}
