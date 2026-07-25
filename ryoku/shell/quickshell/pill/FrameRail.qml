pragma ComponentBehavior: Bound

import QtQuick
import Ryoku.Blobs

Item {
    id: root

    required property string edge
    required property var rail
    required property var style
    property Component delegate: null

    readonly property bool horizontal: edge === "top" || edge === "bottom"
    transformOrigin: edge === "bottom" ? Item.BottomLeft : (edge === "right" ? Item.TopRight : Item.TopLeft)


    width: horizontal ? parent.width / scale : rail.size
    height: horizontal ? rail.size : parent.height / scale
    anchors.top: edge === "top" ? parent.top : undefined
    anchors.bottom: edge === "bottom" ? parent.bottom : undefined
    anchors.left: edge === "left" ? parent.left : undefined
    anchors.right: edge === "right" ? parent.right : undefined

    BlobRect {
        anchors.fill: parent
        group: root.style.group
        topLeftRadius: 0
        topRightRadius: 0
        bottomLeftRadius: 0
        bottomRightRadius: 0
        sinks: false
    }

    Row {
        visible: root.horizontal
        width: parent.width
        height: parent.height

        RailZone {
            width: parent.width / 3
            height: parent.height
            ids: root.rail.start
            horizontal: true
            align: "start"
            delegate: root.delegate
        }
        RailZone {
            width: parent.width / 3
            height: parent.height
            ids: root.rail.center
            horizontal: true
            align: "center"
            delegate: root.delegate
        }
        RailZone {
            width: parent.width / 3
            height: parent.height
            ids: root.rail.end
            horizontal: true
            align: "end"
            delegate: root.delegate
        }
    }

    Column {
        visible: !root.horizontal
        width: parent.width
        height: parent.height

        RailZone {
            width: parent.width
            height: parent.height / 3
            ids: root.rail.top
            horizontal: false
            align: "start"
            delegate: root.delegate
        }
        RailZone {
            width: parent.width
            height: parent.height / 3
            ids: root.rail.center
            horizontal: false
            align: "center"
            delegate: root.delegate
        }
        RailZone {
            width: parent.width
            height: parent.height / 3
            ids: root.rail.bottom
            horizontal: false
            align: "end"
            delegate: root.delegate
        }
    }
}
