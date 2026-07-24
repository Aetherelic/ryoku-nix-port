pragma ComponentBehavior: Bound
import QtQuick
import "Singletons"

// Display-only Atoll weather: the Open-Meteo condition and temperature.
// Hidden until the shared Weather singleton has a real reading.
Item {
    id: wx

    property real s: 1

    readonly property var symFor: ({
        "sun": "clear_day", "cloud": "cloud", "fog": "foggy",
        "rain": "rainy", "snow": "weather_snowy", "storm": "thunderstorm"
    })

    visible: Weather.available
    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight


    Row {
        id: row
        anchors.centerIn: parent
        spacing: 4 * wx.s

        Item {
            anchors.verticalCenter: parent.verticalCenter
            width: 16 * wx.s
            height: 16 * wx.s
            MaterialIcon {
                anchors.centerIn: parent
                text: wx.symFor[Weather.glyph] || "cloud"
                fill: 1
                color: Theme.subtle
                font.pixelSize: 14 * wx.s
            }
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: Weather.temp
            color: Theme.subtle
            font.family: Theme.font
            font.pixelSize: 10.5 * wx.s
            font.weight: Font.Medium
            font.features: ({ "tnum": 1 })
        }
    }

}
