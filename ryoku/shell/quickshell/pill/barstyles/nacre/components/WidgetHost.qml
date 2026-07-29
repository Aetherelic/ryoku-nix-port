import QtQuick
import "../widgets/registry.js" as Registry

Loader {
    id: root

    required property string widgetId
    property real barHeight: 40

    source: Registry.source(root.widgetId)
    visible: root.item ? root.item.visible : root.status !== Loader.Error
    width: root.visible && root.item ? root.item.implicitWidth : 0
    height: root.item ? root.item.implicitHeight : 0

    onLoaded: {
        if (root.item && root.item.barHeight !== undefined)
            root.item.barHeight = root.barHeight;
    }
    onStatusChanged: {
        if (root.status === Loader.Error)
            console.warn("Nacre widget failed:", root.widgetId);
    }
}
