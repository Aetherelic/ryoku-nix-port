pragma ComponentBehavior: Bound
import QtQuick
import "Singletons"

// Drag guides for the desktop widgets: a faint grid on the dragged slot's snap
// step, a vertical and horizontal centre guide that light up (accent, thicker)
// as the slot's centre nears the screen centre, and transient accent lines
// flashed on release to mark the edges it snapped to. Repeater + Rectangle, no
// Canvas: the grid rectangles only exist while a slot is dragging (model 0 at
// rest), so a 4K desktop pays nothing when idle. Purely visual -- no MouseArea,
// so it never captures a click even though it sits under the widgets. Motion is
// gated on reduce-motion the way the slots gate their shadows on Performance:
// the guides still show (functional feedback) but their transitions cut instant.
Item {
    id: guides

    // driven by the host: whether a slot is dragging, its snap step, and where
    // its centre sits in monitor pixels. `active` gates the grid + centre guides.
    property bool active: false
    property real gridSize: 32
    property real dragCentreX: 0
    property real dragCentreY: 0

    // the reference lights a centre guide when the slot's centre is within half a
    // grid step of the screen centre; the release flash uses the same window.
    readonly property bool centreX: guides.active
        && Math.abs(guides.dragCentreX - guides.width / 2) < guides.gridSize / 2
    readonly property bool centreY: guides.active
        && Math.abs(guides.dragCentreY - guides.height / 2) < guides.gridSize / 2

    readonly property int animDur: Performance.reduceMotion ? 0 : 180

    // the grid + centre guides fade with `active`; the release flash (below) is
    // parented to this root, not here, so it outlives this fade-out.
    Item {
        id: overlay
        anchors.fill: parent
        opacity: guides.active ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: guides.animDur; easing.type: Easing.OutCubic } }

        // faint grid on the snap step, strictly inside the screen edges.
        Repeater {
            model: guides.active ? Math.max(0, Math.ceil(guides.width / guides.gridSize) - 1) : 0
            delegate: Rectangle {
                required property int index
                x: Math.round((index + 1) * guides.gridSize)
                width: 1
                height: guides.height
                color: Scheme.onSurfaceVariant
                opacity: 0.10
            }
        }
        Repeater {
            model: guides.active ? Math.max(0, Math.ceil(guides.height / guides.gridSize) - 1) : 0
            delegate: Rectangle {
                required property int index
                y: Math.round((index + 1) * guides.gridSize)
                width: guides.width
                height: 1
                color: Scheme.onSurfaceVariant
                opacity: 0.10
            }
        }

        // centre guides: quiet ink at rest, accent and thicker once the slot's
        // centre snaps to the screen centre.
        Rectangle {
            x: Math.round(guides.width / 2 - width / 2)
            width: guides.centreX ? 2 : 1
            height: guides.height
            color: guides.centreX ? Scheme.accent : Scheme.onSurfaceVariant
            opacity: guides.centreX ? 1 : 0.4
            Behavior on width { NumberAnimation { duration: guides.animDur; easing.type: Easing.OutCubic } }
            Behavior on color { ColorAnimation { duration: guides.animDur } }
            Behavior on opacity { NumberAnimation { duration: guides.animDur; easing.type: Easing.OutCubic } }
        }
        Rectangle {
            y: Math.round(guides.height / 2 - height / 2)
            width: guides.width
            height: guides.centreY ? 2 : 1
            color: guides.centreY ? Scheme.accent : Scheme.onSurfaceVariant
            opacity: guides.centreY ? 1 : 0.4
            Behavior on height { NumberAnimation { duration: guides.animDur; easing.type: Easing.OutCubic } }
            Behavior on color { ColorAnimation { duration: guides.animDur } }
            Behavior on opacity { NumberAnimation { duration: guides.animDur; easing.type: Easing.OutCubic } }
        }
    }

    // one transient accent line per snapped position, fading out over ~1.2 s.
    // parented to the root (not `overlay`) so it survives the overlay fade-out
    // the drop triggers. reduce-motion cuts the fade to instant, so no line
    // lingers repainting.
    Component {
        id: flashLine
        Rectangle {
            id: fl
            property bool vertical: true
            property real pos: 0
            x: fl.vertical ? Math.round(fl.pos) : 0
            y: fl.vertical ? 0 : Math.round(fl.pos)
            width: fl.vertical ? 2 : guides.width
            height: fl.vertical ? guides.height : 2
            color: Scheme.accent
            NumberAnimation on opacity {
                from: 0.9
                to: 0
                duration: Performance.reduceMotion ? 0 : 1200
                easing.type: Easing.OutCubic
                running: true
                onFinished: fl.destroy()
            }
        }
    }

    // flash the given vertical x's and horizontal y's (monitor pixels).
    function flash(verticals, horizontals) {
        for (let i = 0; i < verticals.length; ++i)
            flashLine.createObject(guides, { "vertical": true, "pos": verticals[i] });
        for (let i = 0; i < horizontals.length; ++i)
            flashLine.createObject(guides, { "vertical": false, "pos": horizontals[i] });
    }
}
