pragma ComponentBehavior: Bound

import QtQuick
import Ryoku.Blobs
import "../../../Singletons"

Item {
    id: root

    required property var group
    property real frameThickness: 49
    property real frameLip: 9
    property real radius: 9
    property real smoothing: 8
    property real alongCenter: -1
    property real openWidth: 320
    property real openHeight: 200
    property real scaleFactor: 1
    property bool pinned: false
    property bool triggerHovered: false
    property bool active: true
    property int closeDelay: 0
    property Component content: null

    property bool heldOpen: false
    property real heldCenter: -1
    property real heldWidth: 0
    property real heldHeight: 0
    property real progress: 0

    readonly property bool hovered: triggerHovered || bodyHover.hovered
    readonly property bool shouldOpen: active && (pinned || hovered)
    readonly property real liveWidth: contentLoader.item
        && contentLoader.item.implicitWidth > 0 ? contentLoader.item.implicitWidth : openWidth
    readonly property real liveHeight: contentLoader.item
        && contentLoader.item.implicitHeight > 0 ? contentLoader.item.implicitHeight : openHeight
    readonly property real bodyWidth: heldOpen ? liveWidth : heldWidth
    readonly property real bodyHeight: heldOpen ? liveHeight : heldHeight
    readonly property real center: (triggerHovered || pinned) ? alongCenter : heldCenter
    readonly property real edgeInset: frameLip + 12 * scaleFactor
    readonly property real bodyX: Math.max(edgeInset,
        Math.min(width - bodyWidth - edgeInset, center - bodyWidth / 2))
    readonly property real bodyY: frameThickness
    readonly property real currentHeight: Math.max(0, bodyHeight * progress)
    readonly property real maskX: bodyX
    readonly property real maskY: bodyY
    readonly property real maskWidth: heldOpen ? bodyWidth : 0
    readonly property real maskHeight: heldOpen ? bodyHeight : 0
    readonly property real burial: (1 - Math.max(0, Math.min(1, progress))) * smoothing

    anchors.fill: parent

    function holdGeometry() {
        heldCenter = alongCenter;
        heldWidth = liveWidth;
        heldHeight = liveHeight;
    }

    onAlongCenterChanged: if (triggerHovered || pinned) heldCenter = alongCenter
    onOpenWidthChanged: if (heldOpen) heldWidth = openWidth
    onOpenHeightChanged: if (heldOpen) heldHeight = openHeight
    onLiveWidthChanged: if (heldOpen) heldWidth = liveWidth
    onLiveHeightChanged: if (heldOpen) heldHeight = liveHeight
    onPinnedChanged: {
        if (pinned) {
            holdGeometry();
            heldOpen = active;
        } else if (!triggerHovered) {
            closeGrace.stop();
            heldOpen = false;
        }
    }
    onShouldOpenChanged: {
        if (shouldOpen) {
            closeGrace.stop();
            holdGeometry();
            heldOpen = true;
        } else if (closeDelay > 0) {
            closeGrace.restart();
        } else {
            heldOpen = false;
        }
    }
    Component.onCompleted: {
        holdGeometry();
        heldOpen = shouldOpen;
    }

    states: State {
        name: "open"
        when: root.heldOpen
        PropertyChanges { root.progress: 1 }
    }

    transitions: [
        Transition {
            to: "open"
            NumberAnimation {
                property: "progress"
                duration: Motion.spatial
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Motion.spatialCurve
            }
        },
        Transition {
            from: "open"
            NumberAnimation {
                property: "progress"
                duration: Motion.morph
                easing.type: Easing.OutCubic
            }
        }
    ]

    Timer {
        id: closeGrace
        interval: root.closeDelay
        onTriggered: root.heldOpen = false
    }

    BlobRect {
        readonly property real reach: root.frameThickness + root.smoothing

        group: root.group
        x: root.bodyX
        y: root.bodyY - reach
        implicitWidth: root.bodyWidth
        implicitHeight: root.currentHeight > 0
            ? Math.max(0, root.currentHeight + reach - root.burial) : 0
        topLeftRadius: 0
        topRightRadius: 0
        bottomLeftRadius: root.radius
        bottomRightRadius: root.radius
        deformScale: 0.000015
        sinks: false
    }

    Item {
        id: reveal
        x: root.bodyX
        y: root.bodyY
        width: root.bodyWidth
        height: root.currentHeight
        clip: true

        HoverHandler { id: bodyHover }

        Loader {
            id: contentLoader
            anchors.top: parent.top
            width: root.bodyWidth
            height: root.bodyHeight
            active: root.content !== null
            sourceComponent: root.content
        }
    }
}
