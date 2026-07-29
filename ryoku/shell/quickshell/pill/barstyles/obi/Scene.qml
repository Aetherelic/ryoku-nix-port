pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../Singletons"
import "components" as C
import "widgets" as W

// Obi bar style: a floating top bar (the sash across the top of the screen),
// one instance per monitor, loaded by shell.qml when Config.barStyle is "obi".
// Five zones mirror iNiR's ii bar: the kanji workspaces stay screen-centred and
// the other pills flank them; the active window sits far left, tray + weather
// far right. Only the pills take input; the rest of the strip is click-through.
PanelWindow {
    id: win

    property var modelData
    screen: modelData

    color: "transparent"
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: win.barHeight + win.topGap
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.namespace: "ryoku-obi"

    anchors { top: true; left: true; right: true }

    readonly property int barHeight: 40
    readonly property int topGap: 6
    readonly property int sideGap: 10
    readonly property int pillGap: 8

    // Per-widget visibility from Bar Studio (the Config.obi map); an absent key
    // reads as shown, so the bar is full by default. Workspaces is the identity
    // of the Obi bar and is always shown.
    function shows(id) { return !Config.obi || Config.obi[id] !== false; }

    implicitHeight: win.barHeight + win.topGap * 2

    mask: Region {
        Region { item: leftPill }
        Region { item: centerLeftPill }
        Region { item: centerPill }
        Region { item: centerRightPill }
        Region { item: rightPill }
    }

    Item {
        id: bar
        anchors.fill: parent
        anchors.topMargin: win.topGap
        anchors.bottomMargin: win.topGap
        anchors.leftMargin: win.sideGap
        anchors.rightMargin: win.sideGap

        C.BarPill {
            id: leftPill
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            W.ActiveWindow { visible: win.shows("activeWindow") }
        }

        C.BarPill {
            id: centerPill
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            W.Workspaces {}
        }

        C.BarPill {
            id: centerLeftPill
            anchors.right: centerPill.left
            anchors.rightMargin: win.pillGap
            anchors.verticalCenter: parent.verticalCenter
            W.Resources { visible: win.shows("resources") }
            W.Media { visible: win.shows("media") && Media.present }
        }

        C.BarPill {
            id: centerRightPill
            anchors.left: centerPill.right
            anchors.leftMargin: win.pillGap
            anchors.verticalCenter: parent.verticalCenter
            W.Clock { visible: win.shows("clock") }
            W.Audio { visible: win.shows("audio") }
            W.Utils {}
            W.Battery { visible: win.shows("battery") && Battery.present }
        }

        C.BarPill {
            id: rightPill
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            W.Connectivity { visible: win.shows("connectivity") }
            W.Tray { visible: win.shows("tray") && Tray.items.length > 0 }
            W.Weather { visible: win.shows("weather") && Weather.available && Weather.temp.length > 0 }
        }
    }
}
