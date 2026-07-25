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
    property real spacing: 8
    property Component delegate: null

    readonly property bool atStart: align === "start"
    readonly property bool atEnd: align === "end"

    implicitWidth: content.implicitWidth
    implicitHeight: content.implicitHeight

    Loader {
        id: content
        sourceComponent: root.horizontal ? horizontalContent : verticalContent

        anchors.left: (root.horizontal && root.atStart) ? parent.left : undefined
        anchors.right: (root.horizontal && root.atEnd) ? parent.right : undefined
        anchors.horizontalCenter: (!root.horizontal || (!root.atStart && !root.atEnd)) ? parent.horizontalCenter : undefined

        anchors.top: (!root.horizontal && root.atStart) ? parent.top : undefined
        anchors.bottom: (!root.horizontal && root.atEnd) ? parent.bottom : undefined
        anchors.verticalCenter: (root.horizontal || (!root.atStart && !root.atEnd)) ? parent.verticalCenter : undefined
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
