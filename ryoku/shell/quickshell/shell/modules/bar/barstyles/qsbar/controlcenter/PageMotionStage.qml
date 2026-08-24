import QtQuick
import "../modules"
import Ryoku.Ui.Singletons

// Hosts the active route in a Loader and animates the change. The outgoing page
// leaves quickly (nobody reads a page that is going away); the incoming one takes
// the house spatial curve, rising and settling rather than cutting in, because the
// plate is resizing underneath it at the same time and the two motions have to
// read as one gesture. No scale: a settings page that zooms reads as a slideshow.
// Loaded pages get `root` and `cc` as initial properties, and report their natural
// height back through `pageHeight` so the plate can size itself.
Item {
    id: stage
    property var root
    property var cc
    property url pageUrl
    property int outMs: 150
    property int inMs: 200

    readonly property var item: ld.item
    // 0 until a page reports a height; the plate falls back to the rail's.
    readonly property real pageHeight: (ld.item && ld.item.implicitHeight > 0) ? ld.item.implicitHeight : 0

    onPageUrlChanged: seq.restart()

    Loader {
        id: ld
        anchors.fill: parent
        transformOrigin: Item.Center
        onLoaded: {
            if (item) {
                if (item.hasOwnProperty("root")) item.root = stage.root
                if (item.hasOwnProperty("cc")) item.cc = stage.cc
            }
        }
    }

    SequentialAnimation {
        id: seq
        ParallelAnimation {
            NumberAnimation { target: ld; property: "opacity"; to: 0; duration: stage.outMs; easing.type: Easing.OutCubic }
            NumberAnimation { target: ld; property: "y"; to: -6; duration: stage.outMs; easing.type: Easing.OutCubic }
        }
        ScriptAction {
            script: {
                if (String(stage.pageUrl) !== "") ld.setSource(stage.pageUrl, { root: stage.root, cc: stage.cc })
                else ld.source = ""
                ld.y = 14
            }
        }
        ParallelAnimation {
            NumberAnimation { target: ld; property: "opacity"; to: 1.0; duration: stage.inMs; easing.type: Easing.OutCubic }
            NumberAnimation {
                target: ld; property: "y"; to: 0; duration: stage.inMs
                easing.type: Easing.Bezier
                easing.bezierCurve: Tokens.curveDefaultSpatial
            }
        }
    }
}
