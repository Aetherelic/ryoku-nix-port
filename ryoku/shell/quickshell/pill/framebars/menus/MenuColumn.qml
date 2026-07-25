pragma ComponentBehavior: Bound

import QtQuick

// Ordered vertical stack of menu widgets. The list is built only while the menu
// is effectively open, so a closed menu holds no widget instances. The host is
// loaded by url rather than an import so the pill-level MenuWidgetHost can host
// this composition without a circular type dependency.
Column {
    id: root

    property var widgets: []
    property bool open: false
    property real scale: 1
    spacing: 6 * scale

    Repeater {
        model: root.open ? root.widgets : []
        delegate: Loader {
            id: host
            required property var modelData
            width: root.width
            source: Qt.resolvedUrl("../../MenuWidgetHost.qml")
            onLoaded: {
                item.widgetId = Qt.binding(() => (typeof host.modelData === "string") ? host.modelData : (host.modelData && host.modelData.id ? host.modelData.id : ""));
                item.widgetData = Qt.binding(() => (typeof host.modelData === "object") ? host.modelData : null);
                item.scale = Qt.binding(() => root.scale);
                item.open = Qt.binding(() => root.open);
            }
        }
    }
}
