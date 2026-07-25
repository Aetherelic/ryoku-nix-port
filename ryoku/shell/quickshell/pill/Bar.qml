pragma ComponentBehavior: Bound

import QtQuick

Item {
    id: bar

    required property real railScale
    required property var frameBars
    required property var style

    signal menuRequested(string id, rect ownerRect)
    signal surfaceRequested(string id, rect ownerRect)

    Repeater {
        model: ["top", "left", "bottom", "right"]

        FrameRail {
            required property string modelData
            edge: modelData
            scale: bar.railScale
            rail: bar.frameBars.rails[modelData]
            style: bar.style
            visible: rail.enabled
            onWidgetActivated: (id, ownerRect) => {
                if (bar.frameBars.menus[id])
                    bar.menuRequested(id, ownerRect);
                else if (bar.frameBars.surfaces[id])
                    bar.surfaceRequested(id, ownerRect);
            }
        }
    }
}
