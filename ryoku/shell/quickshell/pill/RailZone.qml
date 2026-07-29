pragma ComponentBehavior: Bound

import QtQuick

// One third of a rail. `align` places the group inside that third: a start zone
// hugs the leading edge, a centre zone sits on the rail's midpoint, an end zone
// hugs the trailing edge. Widgets always centre on the rail's short axis, so a
// glyph never rides the rail's outer wall.
Item {
    id: root

    required property var ids
    required property bool horizontal
    required property string align
    property real spacing: 0
    property Component delegate: null

    readonly property bool atStart: align === "start"
    readonly property bool atEnd: align === "end"

    implicitWidth: content.implicitWidth
    implicitHeight: content.implicitHeight

    // How much of the rail the start and end zones occupy, fed by FrameRail to
    // the CENTRE zone only. The zones are overlays with nothing else keeping
    // them apart, so a grown end group (a tray full of apps) marched straight
    // through the centred dock. The centre stays centred while there is room
    // and slides just far enough to clear the neighbours when there is not;
    // with more content than rail it hugs the start side, which at least keeps
    // one boundary honest instead of stacking icons on icons.
    property real leadExtent: 0
    property real tailExtent: 0
    readonly property bool centred: !root.atStart && !root.atEnd
    function centreShift(span, size) {
        const ideal = (span - size) / 2;
        const lo = root.leadExtent + root.spacing;
        const hi = span - root.tailExtent - root.spacing - size;
        return (Math.min(Math.max(ideal, lo), Math.max(hi, lo))) - ideal;
    }

    Loader {
        id: content
        sourceComponent: root.horizontal ? horizontalContent : verticalContent

        anchors.left: (root.horizontal && root.atStart) ? parent.left : undefined
        anchors.right: (root.horizontal && root.atEnd) ? parent.right : undefined
        anchors.horizontalCenter: (!root.horizontal || (!root.atStart && !root.atEnd)) ? parent.horizontalCenter : undefined
        anchors.horizontalCenterOffset: (root.horizontal && root.centred)
            ? root.centreShift(root.width, content.implicitWidth) : 0

        anchors.top: (!root.horizontal && root.atStart) ? parent.top : undefined
        anchors.bottom: (!root.horizontal && root.atEnd) ? parent.bottom : undefined
        anchors.verticalCenter: (root.horizontal || (!root.atStart && !root.atEnd)) ? parent.verticalCenter : undefined
        anchors.verticalCenterOffset: (!root.horizontal && root.centred)
            ? root.centreShift(root.height, content.implicitHeight) : 0
    }

    Component {
        id: horizontalContent

        Row {
            spacing: root.spacing

            Repeater {
                model: root.ids

                Loader {
                    id: loader
                    required property string modelData
                    anchors.verticalCenter: parent ? parent.verticalCenter : undefined
                    active: root.delegate !== null
                    sourceComponent: root.delegate

                    onLoaded: if (item) item.widgetId = modelData
                }
            }
        }
    }

    Component {
        id: verticalContent

        Column {
            spacing: root.spacing

            Repeater {
                model: root.ids

                Loader {
                    id: loader
                    required property string modelData
                    anchors.horizontalCenter: parent ? parent.horizontalCenter : undefined
                    active: root.delegate !== null
                    sourceComponent: root.delegate

                    onLoaded: if (item) item.widgetId = modelData
                }
            }
        }
    }
}
