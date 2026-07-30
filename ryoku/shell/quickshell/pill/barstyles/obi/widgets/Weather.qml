pragma ComponentBehavior: Bound

import QtQuick
import "../../../Singletons"
import "../../.." as Pill
import "../../shared" as Shared
import "../../nacre/popouts" as Popouts
import "../../nacre/Format.js" as Format

// Obi weather: the current condition glyph and temperature, mirroring iNiR's
// bar readout against Ryoku's daemon-fed Weather singleton. Hidden until a
// frame loads. WMO code -> the shell's own weather-*-symbolic glyph set.
// Hovering opens a detail card with the current conditions and a daily strip.
Item {
    id: root

    implicitWidth: rowr.implicitWidth
    implicitHeight: 26

    readonly property var cur: Weather.current
    visible: Weather.available && Weather.temp.length > 0

    HoverHandler { id: hh }

    Row {
        id: rowr
        anchors.centerIn: parent
        spacing: 6

        Pill.SymbolIcon {
            anchors.verticalCenter: parent.verticalCenter
            name: root.cur ? Format.weatherIcon(root.cur.code, root.cur.isDay) : "weather-unknown"
            size: 18
            color: Theme.onSurfaceVariant
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: Weather.temp
            color: Theme.onSurface
            font.family: Theme.fontPrimary
            font.pixelSize: Theme.fontSm
        }
    }

    Shared.Popout {
        target: root
        targetHovered: hh.hovered
        namespace: "ryoku-obi-popout"
        content: popContent
    }

    Component {
        id: popContent
        Popouts.WeatherPopout {}
    }
}
