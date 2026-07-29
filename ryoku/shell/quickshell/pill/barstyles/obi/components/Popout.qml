pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../../Singletons"

// A popout card anchored under a bar widget. Give it a `target` (the widget item)
// and a `content` Component; it opens while the pointer is over the target or the
// card and eases shut shortly after both are left. Overlay layer, click-through
// outside the card. Each Obi widget owns its own Popout, so a style's popouts
// live entirely inside its folder.
Item {
    id: root

    property Item target: null
    property bool targetHovered: false
    property real barHeight: 46
    property Component content: null

    property bool cardHovered: false
    readonly property bool wantOpen: (root.targetHovered || root.cardHovered)
        && root.target !== null && root.content !== null
    property bool shown: false

    onWantOpenChanged: {
        if (root.wantOpen) {
            closeTimer.stop();
            root.shown = true;
        } else {
            closeTimer.restart();
        }
    }
    Timer { id: closeTimer; interval: 180; onTriggered: root.shown = false }

    Loader {
        active: root.shown
        sourceComponent: popComp
    }

    Component {
        id: popComp

        PanelWindow {
            id: win
            color: "transparent"
            screen: (root.QsWindow && root.QsWindow.window) ? root.QsWindow.window.screen : null
            exclusionMode: ExclusionMode.Ignore
            exclusiveZone: 0
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
            WlrLayershell.namespace: "ryoku-obi-popout"

            anchors { top: true; left: true }
            implicitWidth: card.width
            implicitHeight: card.height
            mask: Region { item: card }

            margins.top: root.barHeight
            margins.left: {
                if (!(root.QsWindow && root.target && root.target.width > 0))
                    return 6;
                const x = root.QsWindow.mapFromItem(root.target, (root.target.width - card.width) / 2, 0).x;
                const maxX = root.QsWindow.window.width - card.width - 6;
                return Math.max(6, Math.min(x, maxX));
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
