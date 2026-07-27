pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

// The one timer-driven widget: a SystemClock ticks the readout (everything else
// is event driven). Horizontal bars show HH:mm on one line, vertical bars stack
// the hour and minute. Left click opens the clock menu. Contract 04 sec 3.2.
Item {
    id: root

    required property string edge
    required property real scale
    signal menuRequested(string id, rect ownerRect)

    readonly property bool horizontal: edge === "top" || edge === "bottom"
    // Reference default is 12-hour (config general.clock_format_24_h defaults to
    // false); Ryoku has no clock-format knob yet (the Go ClockConfig owns it in
    // the settings phase), so it follows that reference default.
    property bool format24h: false

    implicitWidth: btn.implicitWidth
    implicitHeight: btn.implicitHeight

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    function timeText() {
        const d = clock.date;
        const h = d.getHours();
        const shown = format24h ? h : ((h % 12) || 12);
        const hh = ("0" + shown).slice(-2);
        const mm = ("0" + d.getMinutes()).slice(-2);
        return horizontal ? (hh + ":" + mm) : (hh + "\n" + mm);
    }

    RailButton {
        id: btn
        anchors.centerIn: parent
        edge: root.edge
        scale: root.scale
        label: root.timeText()
        labelSize: 13
        labelLineHeight: 17.2
        onClicked: root.menuRequested("quick-settings", Qt.rect(0, 0, root.width, root.height))
    }
}
