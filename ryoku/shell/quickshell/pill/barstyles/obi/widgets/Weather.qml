pragma ComponentBehavior: Bound

import QtQuick
import "../../../Singletons"
import "../../.." as Pill
import "../components" as C

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

    function iconFor(code, day) {
        const d = day ? "day" : "night";
        if (code === 0) return "weather-clear-" + d;
        if (code === 1 || code === 2) return "weather-partly-cloudy-" + d;
        if (code === 3) return "weather-overcast";
        if (code === 45 || code === 48) return "weather-fog";
        if (code >= 51 && code <= 57) return "weather-drizzle";
        if (code === 61 || code === 80) return "weather-rain-light";
        if (code === 63 || code === 81) return "weather-rain";
        if (code === 65 || code === 82) return "weather-rain-heavy";
        if (code === 66 || code === 67) return "weather-sleet";
        if (code === 71 || code === 85) return "weather-snow-light";
        if (code === 73 || code === 77) return "weather-snow";
        if (code === 75 || code === 86) return "weather-snow-heavy";
        if (code >= 95) return "weather-thunderstorm";
        return "weather-cloudy";
    }

    HoverHandler { id: hh }

    Row {
        id: rowr
        anchors.centerIn: parent
        spacing: 6

        Pill.SymbolIcon {
            anchors.verticalCenter: parent.verticalCenter
            name: root.cur ? root.iconFor(root.cur.code, root.cur.isDay) : "weather-unknown"
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

    C.Popout {
        target: root
        targetHovered: hh.hovered
        content: popContent
    }

    Component {
        id: popContent
        Item {
            implicitWidth: col.width + 40
            implicitHeight: col.implicitHeight + 36

            Column {
                id: col
                width: 260
                anchors.centerIn: parent
                spacing: 14

                // Header: big temperature, condition, location.
                Row {
                    width: parent.width
                    spacing: 12

                    Pill.SymbolIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: root.cur ? root.iconFor(root.cur.code, root.cur.isDay) : "weather-unknown"
                        size: 46
                        color: Theme.onSurfaceVariant
                    }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2
                        Text {
                            text: Weather.temp
                            color: Theme.onSurface
                            font.family: Theme.fontPrimary
                            font.pixelSize: Theme.fontXxl
                            font.weight: Font.Bold
                        }
                        Text {
                            text: Weather.condition
                            color: Theme.onSurfaceVariant
                            font.family: Theme.fontPrimary
                            font.pixelSize: Theme.fontMd
                        }
                        Text {
                            visible: Weather.location.length > 0
                            width: 190
                            text: Weather.location
                            elide: Text.ElideRight
                            color: Theme.onSurfaceVariant
                            font.family: Theme.fontPrimary
                            font.pixelSize: Theme.fontSm
                        }
                    }
                }

                // Detail chips: feels-like, humidity, wind.
                Row {
                    width: parent.width
                    Repeater {
                        model: [
                            { icon: root.cur ? root.iconFor(root.cur.code, root.cur.isDay) : "weather-unknown",
                              label: qsTr("Feels"),
                              value: root.cur ? String(root.cur.feelsLike) : "" },
                            { icon: "weather-humidity",
                              label: qsTr("Humidity"),
                              value: (root.cur ? root.cur.humidity : Weather.humidity) + "%" },
                            { icon: "weather-windy",
                              label: qsTr("Wind"),
                              value: root.cur ? (root.cur.windValue + " " + root.cur.windUnits) : "" }
                        ]
                        delegate: Column {
                            id: chip
                            required property var modelData
                            width: parent.width / 3
                            spacing: 5

                            Pill.SymbolIcon {
                                anchors.horizontalCenter: parent.horizontalCenter
                                name: chip.modelData.icon
                                size: 20
                                color: Theme.onSurfaceVariant
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: chip.modelData.label.toUpperCase()
                                color: Theme.onSurfaceVariant
                                font.family: Theme.mono
                                font.pixelSize: Theme.fontSm - 4
                                font.letterSpacing: 1.2
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: chip.modelData.value
                                color: Theme.onSurface
                                font.family: Theme.fontPrimary
                                font.pixelSize: Theme.fontSm
                                font.weight: Font.DemiBold
                            }
                        }
                    }
                }

                // Daily forecast strip, shown only when the frame carries one.
                Column {
                    width: parent.width
                    spacing: 10
                    visible: Weather.daily.length > 0

                    Rectangle {
                        width: parent.width
                        height: Theme.borderWidth
                        color: Theme.outline
                    }

                    Row {
                        width: parent.width
                        readonly property int days: Math.min(4, Weather.daily.length)
                        Repeater {
                            model: parent.days
                            delegate: Column {
                                id: dcell
                                required property int index
                                readonly property var d: Weather.daily[dcell.index]
                                width: parent.width / parent.days
                                spacing: 5

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: dcell.d.day
                                    color: Theme.onSurfaceVariant
                                    font.family: Theme.mono
                                    font.pixelSize: Theme.fontSm - 3
                                    font.weight: Font.DemiBold
                                }
                                Pill.SymbolIcon {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    name: root.iconFor(dcell.d.code, true)
                                    size: 22
                                    color: Theme.onSurfaceVariant
                                }
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: dcell.d.high
                                    color: Theme.onSurface
                                    font.family: Theme.fontPrimary
                                    font.pixelSize: Theme.fontSm
                                    font.weight: Font.DemiBold
                                }
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: dcell.d.low
                                    color: Theme.onSurfaceVariant
                                    font.family: Theme.fontPrimary
                                    font.pixelSize: Theme.fontSm - 1
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
