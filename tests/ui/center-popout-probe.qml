import QtQuick
import Quickshell
import Ryoku.Blobs
import "modules/bar/popouts" as BarPopouts

// A framePopout placed at "center" (Hub placement editor, plugins.json
// `framePopout: { edge: "center" }`) must float in the middle of its screen
// instead of docking to an edge: body and input mask centred on both axes, no
// hover band when `hoverOpen` is off, and an edge popout unchanged beside it.
ShellRoot {
    id: root

    readonly property real span: 1000
    readonly property real tall: 600

    BlobGroup { id: probeGroup }

    Item {
        id: stage
        width: root.span
        height: root.tall

        BarPopouts.Popout {
            id: centred
            group: probeGroup
            frameThickness: 16
            centered: true
            hoverOpen: false
            openW: 320
            openH: 200
            pinned: true
        }

        BarPopouts.Popout {
            id: docked
            group: probeGroup
            frameThickness: 16
            edge: "right"
            align: "start"
            openW: 320
            openH: 200
            pinned: true
        }
    }

    function near(actual, expected, what) {
        if (Math.abs(actual - expected) > 0.5)
            throw new Error("CENTER-POPOUT-PROBE-FAIL " + what + ": " + actual + " != " + expected);
    }

    // one tick after the open transition settles (prog 1), so the body geometry
    // is the resting open geometry, not a frame of the melt.
    Timer {
        interval: 600
        running: true
        onTriggered: {
            root.near(centred.prog, 1, "centred prog");
            root.near(centred.maskX, (root.span - centred.openW) / 2, "centred maskX");
            root.near(centred.maskY, (root.tall - centred.openH) / 2, "centred maskY");
            root.near(centred.bodyX, (root.span - centred.openW) / 2, "centred bodyX");
            root.near(centred.bodyY, (root.tall - centred.openH) / 2, "centred bodyY");
            root.near(centred.triggerW, 0, "centred triggerW");
            root.near(centred.triggerH, 0, "centred triggerH");
            if (centred.hugLeft || centred.hugRight)
                throw new Error("CENTER-POPOUT-PROBE-FAIL centred hugs a wall");

            // the edge case still docks: right edge, body inset by the frame.
            root.near(docked.maskX, root.span - docked.frameThickness - docked.openW, "docked maskX");
            if (docked.triggerW <= 0)
                throw new Error("CENTER-POPOUT-PROBE-FAIL docked popout lost its hover band");

            console.log("CENTER-POPOUT-PROBE-PASS");
            Qt.quit();
        }
    }
}
