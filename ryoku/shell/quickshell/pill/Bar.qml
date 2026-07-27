pragma ComponentBehavior: Bound

import QtQuick

Item {
    id: bar

    required property real railScale
    required property var frameBars
    required property var style
    // Per-edge reveal baseline from the shared reveal model in shell.qml.
    required property var revealState

    signal menuRequested(string id, rect ownerRect)
    signal surfaceRequested(string id, rect ownerRect)
    signal actionRequested(string id)

    Repeater {
        model: ["top", "left", "bottom", "right"]

        FrameRail {
            required property string modelData
            edge: modelData
            revealed: bar.revealState ? bar.revealState[modelData] === true : false
            rail: bar.frameBars.rails[modelData]
            style: bar.style
            delegate: Component {
                BarWidgetHost {
                    edge: modelData
                    // Fit the widget to the rail's band: a rail thinner than the
                    // 48px parity size scales its widgets down so the button and
                    // its hover highlight never overflow a small bar.
                    scale: bar.railScale * Math.min(1, bar.frameBars.rails[modelData].size / 48)
                    onMenuRequested: (id, ownerRect) => bar.menuRequested(id, ownerRect)
                    onActionRequested: id => bar.actionRequested(id)
                }
            }
            visible: rail.enabled
        }
    }
}
