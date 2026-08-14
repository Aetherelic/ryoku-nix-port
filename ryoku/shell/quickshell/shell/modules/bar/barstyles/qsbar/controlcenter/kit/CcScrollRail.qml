import QtQuick

// The Control Center's one scroll affordance: a slim side rail that appears only
// when content exceeds the viewport. Two-pixel thumb growing to three on hover or
// drag, behind a wider invisible pointer target so it stays grabbable.
Item {
    id: rail

    required property var root
    required property var flick

    readonly property bool overflowing: flick
        && flick.contentHeight > flick.height + 1
    readonly property bool engaged: railMa.containsMouse || railMa.pressed

    anchors.right: parent.right
    anchors.top: parent.top
    anchors.bottom: parent.bottom
    width: 10
    visible: rail.overflowing
    opacity: rail.overflowing ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 120 } }

    Rectangle {
        id: thumb
        anchors.right: parent.right
        anchors.rightMargin: 2
        width: rail.engaged ? 3 : 2
        radius: width / 2
        color: rail.root
            ? Qt.rgba(rail.root.ink.r, rail.root.ink.g, rail.root.ink.b,
                rail.engaged ? 0.42 : 0.24)
            : "transparent"
        height: rail.flick && rail.flick.contentHeight > 0
            ? Math.max(24, rail.height * Math.min(1, rail.flick.height / rail.flick.contentHeight))
            : 0
        y: {
            if (!rail.flick || rail.flick.contentHeight <= rail.flick.height) return 0
            var span = rail.height - height
            var scrolled = rail.flick.contentY
                / (rail.flick.contentHeight - rail.flick.height)
            return Math.max(0, Math.min(span, span * scrolled))
        }
        Behavior on width { NumberAnimation { duration: 120 } }
        Behavior on color { ColorAnimation { duration: 120 } }
    }

    MouseArea {
        id: railMa
        anchors.fill: parent
        hoverEnabled: true
        preventStealing: true
        property real grabOffset: 0

        onPressed: function (mouse) {
            // Grabbing the thumb drags from where it was taken; a click on the
            // bare rail jumps the thumb centre to the pointer.
            if (mouse.y >= thumb.y && mouse.y <= thumb.y + thumb.height)
                grabOffset = mouse.y - thumb.y
            else
                grabOffset = thumb.height / 2
            rail.scrollTo(mouse.y - grabOffset)
        }
        onPositionChanged: function (mouse) {
            if (pressed) rail.scrollTo(mouse.y - grabOffset)
        }
    }

    function scrollTo(thumbY) {
        if (!flick || flick.contentHeight <= flick.height) return
        var span = rail.height - thumb.height
        if (span <= 0) return
        var frac = Math.max(0, Math.min(1, thumbY / span))
        flick.contentY = frac * (flick.contentHeight - flick.height)
    }
}
