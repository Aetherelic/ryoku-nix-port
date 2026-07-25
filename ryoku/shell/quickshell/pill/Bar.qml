pragma ComponentBehavior: Bound

import QtQuick

Item {
    id: bar

    required property real railScale
    required property var frameBars
    required property var style

    signal menuRequested(string id, rect ownerRect)
    signal surfaceRequested(string id, rect ownerRect)
    signal actionRequested(string id)

    Repeater {
        model: ["top", "left", "bottom", "right"]

        FrameRail {
            required property string modelData
            edge: modelData
            scale: bar.railScale
            rail: bar.frameBars.rails[modelData]
            style: bar.style
            delegate: Component {
                BarWidgetHost {
                    edge: modelData
                    scale: bar.railScale
                    onMenuRequested: (id, ownerRect) => bar.menuRequested(id, ownerRect)
                    onActionRequested: id => bar.actionRequested(id)
                }
            }
            visible: rail.enabled
        }
    }
}
