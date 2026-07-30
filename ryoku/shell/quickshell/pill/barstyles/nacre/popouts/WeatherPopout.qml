pragma ComponentBehavior: Bound

import QtQuick
import "../../../Singletons"
import "../../.." as Pill
import "../Format.js" as Format

Item {
    readonly property var current: Weather.current

    implicitWidth: content.width + 40
    implicitHeight: content.implicitHeight + 36

    Column {
        id: content
        width: 260
        anchors.centerIn: parent
        spacing: 14

        Row {
            width: parent.width
            spacing: 12

            Pill.SymbolIcon {
                anchors.verticalCenter: parent.verticalCenter
                name: current ? Format.weatherIcon(current.code, current.isDay) : "weather-unknown"
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

        Row {
            width: parent.width

            Repeater {
                model: [
                    {
                        icon: current ? Format.weatherIcon(current.code, current.isDay) : "weather-unknown",
                        label: qsTr("Feels"),
                        value: current ? String(current.feelsLike) : ""
                    },
                    {
                        icon: "weather-humidity",
                        label: qsTr("Humidity"),
                        value: (current ? current.humidity : Weather.humidity) + "%"
                    },
                    {
                        icon: "weather-windy",
                        label: qsTr("Wind"),
                        value: current ? current.windValue + " " + current.windUnits : ""
                    }
                ]

                delegate: Column {
                    id: detail
                    required property var modelData
                    width: parent.width / 3
                    spacing: 5

                    Pill.SymbolIcon {
                        anchors.horizontalCenter: parent.horizontalCenter
                        name: detail.modelData.icon
                        size: 20
                        color: Theme.onSurfaceVariant
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: detail.modelData.label.toUpperCase()
                        color: Theme.onSurfaceVariant
                        font.family: Theme.mono
                        font.pixelSize: Theme.fontSm - 4
                        font.letterSpacing: 1.2
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: detail.modelData.value
                        color: Theme.onSurface
                        font.family: Theme.fontPrimary
                        font.pixelSize: Theme.fontSm
                        font.weight: Font.DemiBold
                    }
                }
            }
        }

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
                        id: day
                        required property int index
                        readonly property var forecast: Weather.daily[day.index]
                        width: parent.width / parent.days
                        spacing: 5

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: day.forecast.day
                            color: Theme.onSurfaceVariant
                            font.family: Theme.mono
                            font.pixelSize: Theme.fontSm - 3
                            font.weight: Font.DemiBold
                        }
                        Pill.SymbolIcon {
                            anchors.horizontalCenter: parent.horizontalCenter
                            name: Format.weatherIcon(day.forecast.code, true)
                            size: 22
                            color: Theme.onSurfaceVariant
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: day.forecast.high
                            color: Theme.onSurface
                            font.family: Theme.fontPrimary
                            font.pixelSize: Theme.fontSm
                            font.weight: Font.DemiBold
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: day.forecast.low
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
