pragma ComponentBehavior: Bound

import QtQuick

Item {
    id: root

    required property var ids
    required property bool horizontal
    property Component delegate: null


    implicitWidth: content.implicitWidth
    implicitHeight: content.implicitHeight

    Loader {
        id: content
        anchors.fill: parent
        sourceComponent: root.horizontal ? horizontalContent : verticalContent
    }

    Component {
        id: horizontalContent

        Row {
            Repeater {
                model: root.ids

                Loader {
                    id: loader
                    required property string modelData
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
            Repeater {
                model: root.ids

                Loader {
                    id: loader
                    required property string modelData
                    active: root.delegate !== null
                    sourceComponent: root.delegate

                    onLoaded: if (item) item.widgetId = modelData

                }
            }
        }
    }
}
