import QtQuick
import Ryoku.FrameBars

Loader {
    id: root

    required property string widgetId
    property real barHeight: 40

    signal popupRequested(string name, real center, bool active, bool pinned)

    source: {
        const item = NacreConfig.entry(root.widgetId);
        return item ? "../widgets/" + item.file : "";
    }
    readonly property bool contentVisible: root.item
        ? root.item.visible : root.status !== Loader.Error
    width: root.contentVisible && root.item ? root.item.implicitWidth : 0
    height: root.item ? root.item.implicitHeight : 0

    onLoaded: {
        if (root.item && root.item.barHeight !== undefined)
            root.item.barHeight = root.barHeight;
    }
    onStatusChanged: {
        if (root.status === Loader.Error)
            console.warn("Nacre widget failed:", root.widgetId);
    }

    Connections {
        target: root.item
        ignoreUnknownSignals: true
        function onPopupRequested(name, center, active, pinned) {
            root.popupRequested(name, center, active, pinned);
        }
    }
}
