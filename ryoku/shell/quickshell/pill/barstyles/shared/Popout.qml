pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../Singletons"

Item {
    id: root

    property Item target: null
    property bool targetHovered: false
    property real barHeight: 46
    property string namespace: "ryoku-bar-popout"
    property Component content: null
    property bool cardHovered: false
    property bool shown: false

    readonly property bool wantOpen: (root.targetHovered || root.cardHovered)
        && root.target !== null && root.content !== null

    onWantOpenChanged: {
        if (root.wantOpen) {
            closeTimer.stop();
            root.shown = true;
        } else {
            closeTimer.restart();
        }
    }

    Timer {
        id: closeTimer
        interval: 180
        onTriggered: root.shown = false
    }

    Loader {
        active: root.shown
        sourceComponent: popComp
    }

    Component {
        id: popComp

        PanelWindow {
            color: "transparent"
            screen: root.QsWindow && root.QsWindow.window ? root.QsWindow.window.screen : null
            exclusionMode: ExclusionMode.Ignore
            exclusiveZone: 0
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
            WlrLayershell.namespace: root.namespace
            anchors { top: true; left: true }
            implicitWidth: card.width
            implicitHeight: card.height
            mask: Region { item: card }
            margins.top: root.barHeight
            margins.left: {
                if (!(root.QsWindow && root.target && root.target.width > 0))
                    return 6;
                const x = root.QsWindow.mapFromItem(root.target, (root.target.width - card.width) / 2, 0).x;
                return Math.max(6, Math.min(x, root.QsWindow.window.width - card.width - 6));
            }

            Rectangle {
                id: card
                width: inner.implicitWidth + 2
                height: inner.implicitHeight + 2
                radius: Theme.radiusWindow
                color: Theme.surface
                border.width: Theme.borderWidth
                border.color: Theme.outline
                opacity: Theme.windowOpacity

                HoverHandler { onHoveredChanged: root.cardHovered = hovered }

                Loader {
                    id: inner
                    anchors.centerIn: parent
                    sourceComponent: root.content
                }
            }
        }
    }
}
