import QtQuick
import "../../../Singletons"
import "../../.." as Pill
import "../../shared" as Shared
import "../../shared/popouts" as Popouts
import "../../shared/Format.js" as Format

Item {
    id: root

    property real barHeight: 40
    readonly property var current: Weather.current

    implicitWidth: content.implicitWidth
    implicitHeight: 26
    visible: Weather.available && Weather.temp.length > 0

    HoverHandler { id: hover }

    Row {
        id: content
        anchors.centerIn: parent
        spacing: 5

        Pill.SymbolIcon {
            anchors.verticalCenter: parent.verticalCenter
            name: root.current ? Format.weatherIcon(root.current.code, root.current.isDay) : "weather-unknown"
            size: 17
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
        targetHovered: hover.hovered
        barHeight: root.barHeight
        namespace: "ryoku-nacre-popout"
        content: popup
    }
    Component {
        id: popup
        Popouts.WeatherPopout {}
    }
}
