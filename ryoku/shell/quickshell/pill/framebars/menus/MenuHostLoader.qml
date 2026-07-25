pragma ComponentBehavior: Bound

import QtQuick

// Loads MenuWidgetHost by resolved url rather than an import so the pill-level
// host can compose menu-dir widgets without a circular type dependency. The
// imperative onLoaded bindings forward the composition inputs; keep the
// url-based load -- an import here would reintroduce the cycle.
Loader {
    id: host

    property var widget: null
    property real scale: 1
    property bool open: false
    property int depth: 0

    signal requestClose()
    source: Qt.resolvedUrl("../../MenuWidgetHost.qml")
    onLoaded: {
        item.widgetId = Qt.binding(() => (typeof host.widget === "string") ? host.widget : (host.widget && host.widget.id ? host.widget.id : ""));
        item.widgetData = Qt.binding(() => (typeof host.widget === "object") ? host.widget : null);
        item.scale = Qt.binding(() => host.scale);
        item.open = Qt.binding(() => host.open);
        item.depth = Qt.binding(() => host.depth);
    }

    Connections {
        target: host.item
        ignoreUnknownSignals: true
        function onRequestClose() { host.requestClose(); }
    }
}
