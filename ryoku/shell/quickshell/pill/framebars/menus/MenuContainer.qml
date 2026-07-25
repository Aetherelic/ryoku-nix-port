pragma ComponentBehavior: Bound

import QtQuick

// Nested composition: a bounded, orientation-aware group of menu widgets. The
// depth cap stops a self-referential container from recursing without end. Like
// MenuColumn it loads the host by url to avoid a circular type dependency.
Item {
    id: root

    property var widgets: []
    property string orientation: "vertical"
    property bool open: false
    property real scale: 1
    property int depth: 0
    readonly property int maxDepth: 3
    property real spacing: 6 * scale

    implicitWidth: layout.item ? layout.item.implicitWidth : 0
    implicitHeight: layout.item ? layout.item.implicitHeight : 0

    Loader {
        id: layout
        width: root.width
        active: root.open && root.depth < root.maxDepth
        sourceComponent: root.orientation === "horizontal" ? rowComp : colComp
    }

    Component {
        id: hostComp
        Loader {
            id: host
            required property var modelData
            width: root.orientation === "horizontal" ? implicitWidth : root.width
            source: Qt.resolvedUrl("../../MenuWidgetHost.qml")
            onLoaded: {
                item.widgetId = Qt.binding(() => (typeof host.modelData === "string") ? host.modelData : (host.modelData && host.modelData.id ? host.modelData.id : ""));
                item.widgetData = Qt.binding(() => (typeof host.modelData === "object") ? host.modelData : null);
                item.scale = Qt.binding(() => root.scale);
                item.open = Qt.binding(() => root.open);
                item.depth = Qt.binding(() => root.depth + 1);
            }
        }
    }

    Component { id: colComp; Column { spacing: root.spacing; Repeater { model: root.widgets; delegate: hostComp } } }
    Component { id: rowComp; Row { spacing: root.spacing; Repeater { model: root.widgets; delegate: hostComp } } }
}
