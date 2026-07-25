import QtQuick
import "../.." as Pill
import "../../Singletons"
import "../../lib/weather.js" as Wx

Item {
    id: root

    required property real s
    required property bool open

    implicitWidth: 320 * s
    implicitHeight: content.implicitHeight

    Column {
        id: content
        width: parent.width
        spacing: 12 * root.s

        Row {
            spacing: 12 * root.s
            Pill.GlyphIcon {
                width: 34 * root.s
                height: 34 * root.s
                name: Weather.glyph
                color: Theme.cream
                stroke: 1.5
            }
            Column {
                Text {
                    text: Weather.available ? Weather.temp : "Weather unavailable"
                    color: Theme.bright
                    font.family: Theme.display
                    font.pixelSize: 24 * root.s
                }
                Text {
                    text: Weather.available ? Weather.condition + (Weather.city.length ? "  ·  " + Weather.city : "") : ""
                    color: Theme.dim
                    font.family: Theme.font
                    font.pixelSize: 11 * root.s
                }
            }
        }
        Row {
            width: parent.width
            visible: root.open && Weather.available
            Repeater {
                model: Math.min(6, Weather.hourly.length)
                delegate: Column {
                    required property int index
                    width: parent.width / 6
                    spacing: 4 * root.s
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Weather.hourly[index].hour
                        color: Theme.faint
                        font.family: Theme.mono
                        font.pixelSize: 9 * root.s
                    }
                    Pill.GlyphIcon {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 16 * root.s
                        height: 16 * root.s
                        name: Wx.glyphFor(Weather.hourly[index].code)
                        color: Theme.subtle
                        stroke: 1.4
                    }
                }
            }
        }
    }
}
