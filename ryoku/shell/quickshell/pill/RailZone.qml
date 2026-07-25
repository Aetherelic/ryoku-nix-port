pragma ComponentBehavior: Bound

import QtQuick

Item {
    id: root

    required property var ids
    required property bool horizontal
    property Component delegate: null

    signal widgetActivated(string id, rect ownerRect)

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

                    Connections {
                        target: loader.item
                        function onActivated() {
                            const point = loader.mapToGlobal(0, 0);
                            root.widgetActivated(loader.modelData, {
                                x: point.x,
                                y: point.y,
                                width: loader.width,
                                height: loader.height
                            });
                        }
                    }
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

                    Connections {
                        target: loader.item
                        function onActivated() {
                            const point = loader.mapToGlobal(0, 0);
                            root.widgetActivated(loader.modelData, {
                                x: point.x,
                                y: point.y,
                                width: loader.width,
                                height: loader.height
                            });
                        }
                    }
                }
            }
        }
    }
}
