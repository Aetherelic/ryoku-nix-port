pragma ComponentBehavior: Bound

import QtQuick
import "../.." as Pill
import "../../Singletons"

// The weather widget of the clock menu (contract 08 sec 2.4). An outer state
// stack crossfades (250 ms) between three renderings: a loading label, an error
// message with a Retry button, and the loaded body. The loaded body carries a
// nav header (location plus prev/next) over an inner slide stack (200 ms) that
// pages through Current, Hourly and Daily conditions. The daemon (weather.go)
// owns the Open-Meteo fetch and ships every string and icon token ready to bind,
// so this file makes no network call and does no unit maths.
Item {
    id: root

    required property real s
    required property bool open

    // Inner page: 0 Current, 1 Hourly, 2 Daily.
    property int page: 0

    readonly property string status: Weather.status
    readonly property bool loaded: root.status === "loaded" && Weather.current !== null
    readonly property bool hasData: Weather.hasData

    // Nav is dead until data has loaded; prev off on Current, next off on Daily.
    readonly property bool canPrev: root.hasData && root.page > 0
    readonly property bool canNext: root.hasData && root.page < 2

    // The current-page detail and sunrise/sunset rows, driven off the daemon's
    // pre-formatted strings so the delegates just bind.
    readonly property var detailModel: [
        { icon: "wx-humidity", value: Weather.current ? String(Weather.current.humidity) : "0", unit: qsTr("% humidity") },
        { icon: "wx-uv-index", value: Weather.current ? String(Weather.current.uvIndex) : "0", unit: qsTr(" UV index") },
        { icon: "wx-windy", value: Weather.current ? Weather.current.wind : "0", unit: Weather.current ? Weather.current.windUnits : "" }
    ]
    readonly property var sunModel: [
        { label: qsTr("Sunrise"), icon: "wx-sunrise", value: Weather.current ? Weather.current.sunrise : "" },
        { label: qsTr("Sunset"), icon: "wx-sunset", value: Weather.current ? Weather.current.sunset : "" }
    ]

    onLoadedChanged: if (!root.loaded) root.page = 0

    implicitWidth: 320 * root.s
    implicitHeight: root.status === "loaded" ? loadedBox.implicitHeight
        : root.status === "error" ? errorBox.implicitHeight
        : loadingBox.implicitHeight
    Behavior on implicitHeight { NumberAnimation { duration: Motion.weatherFade; easing.type: Easing.OutCubic } }

    // --- loading ---
    Item {
        id: loadingBox
        width: root.width
        implicitHeight: loadingLabel.implicitHeight + 24 * root.s
        opacity: root.status === "loading" ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: Motion.weatherFade; easing.type: Motion.crossfadeCurve } }
        Text {
            id: loadingLabel
            anchors.centerIn: parent
            text: qsTr("Weather loading\u2026")
            color: Theme.onSurface
            horizontalAlignment: Text.AlignHCenter
            font.family: Theme.fontPrimary
            font.pixelSize: Theme.fontMd * root.s
            font.weight: Font.Bold
        }
    }

    // --- error ---
    Column {
        id: errorBox
        width: root.width
        spacing: 8 * root.s
        opacity: root.status === "error" ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: Motion.weatherFade; easing.type: Motion.crossfadeCurve } }

        Text {
            width: parent.width
            text: Weather.errorText.length > 0 ? Weather.errorText : qsTr("Error loading weather.")
            color: Theme.error
            horizontalAlignment: Text.AlignHCenter
            font.family: Theme.fontPrimary
            font.pixelSize: Theme.fontMd * root.s
            font.weight: Font.Bold
        }
        MenuButton {
            anchors.horizontalCenter: parent.horizontalCenter
            minW: retryLabel.implicitWidth + 2 * pad
            minH: retryLabel.implicitHeight + 2 * pad
            pad: Theme.paddingMd * root.s
            radius: Theme.radiusWidget
            onClicked: Weather.retry()
            Text {
                id: retryLabel
                anchors.centerIn: parent
                text: qsTr("Retry")
                color: Theme.onSurface
                font.family: Theme.fontPrimary
                font.pixelSize: Theme.fontSm * root.s
            }
        }
    }

    // --- loaded ---
    Column {
        id: loadedBox
        width: root.width
        spacing: 8 * root.s
        opacity: root.loaded ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: Motion.weatherFade; easing.type: Motion.crossfadeCurve } }

        // nav header
        Item {
            width: parent.width
            height: Math.max(locationLabel.implicitHeight, prevBtn.implicitHeight)

            Text {
                id: locationLabel
                anchors.left: parent.left
                anchors.right: navRow.left
                anchors.rightMargin: 8 * root.s
                anchors.verticalCenter: parent.verticalCenter
                text: Weather.location
                elide: Text.ElideRight
                color: Theme.onSurfaceVariant
                font.family: Theme.fontPrimary
                font.pixelSize: Theme.fontSm * root.s
                font.weight: Font.Bold
            }
            Row {
                id: navRow
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6 * root.s

                MenuButton {
                    id: prevBtn
                    minW: 30 * root.s
                    minH: 28 * root.s
                    pad: Theme.paddingSm * root.s
                    radius: Theme.radiusWidget
                    enabled: root.canPrev
                    onClicked: if (root.canPrev) root.page -= 1
                    Pill.GlyphIcon {
                        anchors.centerIn: parent
                        width: 16 * root.s
                        height: 16 * root.s
                        name: "chevron-left"
                        color: prevBtn.contentColor
                        stroke: 1.8
                    }
                }
                MenuButton {
                    id: nextBtn
                    minW: 30 * root.s
                    minH: 28 * root.s
                    pad: Theme.paddingSm * root.s
                    radius: Theme.radiusWidget
                    enabled: root.canNext
                    onClicked: if (root.canNext) root.page += 1
                    Pill.GlyphIcon {
                        anchors.centerIn: parent
                        width: 16 * root.s
                        height: 16 * root.s
                        name: "chevron-right"
                        color: nextBtn.contentColor
                        stroke: 1.8
                    }
                }
            }
        }

        // inner slide stack (current / hourly / daily)
        Item {
            id: viewport
            width: parent.width
            clip: true
            height: root.page === 0 ? currentPage.implicitHeight
                : root.page === 1 ? hourlyPage.implicitHeight
                : dailyPage.implicitHeight
            Behavior on height { NumberAnimation { duration: Motion.rowReveal; easing.type: Motion.rowRevealCurve } }

            Row {
                id: strip
                x: -root.page * viewport.width
                Behavior on x { NumberAnimation { duration: Motion.rowReveal; easing.type: Motion.rowRevealCurve } }

                // Current page
                WeatherCard {
                    id: currentPage
                    s: root.s
                    width: viewport.width
                    title: qsTr("Current Conditions")
                    Row {
                        width: parent.width
                        Column {
                            width: parent.width / 2
                            spacing: 8 * root.s
                            Row {
                                anchors.horizontalCenter: parent.horizontalCenter
                                spacing: 12 * root.s
                                Pill.GlyphIcon {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 48 * root.s
                                    height: 48 * root.s
                                    name: Weather.current ? Weather.current.icon : "wx-unknown"
                                    color: Theme.onSurface
                                    stroke: 1.6
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: Weather.current ? Weather.current.temperature : ""
                                    color: Theme.onSurface
                                    font.family: Theme.fontPrimary
                                    font.pixelSize: Theme.fontXl * root.s
                                    font.weight: Font.Bold
                                }
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: qsTr("Feels like: ") + (Weather.current ? Weather.current.feelsLike : "")
                                color: Theme.onSurface
                                font.family: Theme.fontPrimary
                                font.pixelSize: Theme.fontSm * root.s
                            }
                        }
                        Column {
                            width: parent.width / 2
                            spacing: 8 * root.s
                            Repeater {
                                model: root.detailModel
                                delegate: Row {
                                    required property var modelData
                                    spacing: 8 * root.s
                                    Pill.GlyphIcon {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: 20 * root.s
                                        height: 20 * root.s
                                        name: modelData.icon
                                        color: Theme.onSurface
                                        stroke: 1.6
                                    }
                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: modelData.value
                                        color: Theme.onSurface
                                        font.family: Theme.fontPrimary
                                        font.pixelSize: Theme.fontSm * root.s
                                        font.weight: Font.Bold
                                    }
                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: modelData.unit
                                        color: Theme.onSurface
                                        font.family: Theme.fontPrimary
                                        font.pixelSize: Theme.fontSm * root.s
                                    }
                                }
                            }
                        }
                    }
                    Row {
                        width: parent.width
                        Repeater {
                            model: root.sunModel
                            delegate: Column {
                                required property var modelData
                                width: parent.width / 2
                                spacing: 8 * root.s
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: modelData.label
                                    color: Theme.onSurface
                                    font.family: Theme.fontPrimary
                                    font.pixelSize: Theme.fontSm * root.s
                                }
                                Row {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    spacing: 8 * root.s
                                    Pill.GlyphIcon {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: 20 * root.s
                                        height: 20 * root.s
                                        name: modelData.icon
                                        color: Theme.onSurface
                                        stroke: 1.6
                                    }
                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: modelData.value
                                        color: Theme.onSurface
                                        font.family: Theme.fontPrimary
                                        font.pixelSize: Theme.fontSm * root.s
                                        font.weight: Font.Bold
                                    }
                                }
                            }
                        }
                    }
                }

                // Hourly page (24 items)
                WeatherCard {
                    id: hourlyPage
                    s: root.s
                    width: viewport.width
                    title: qsTr("Hourly Conditions")
                    Flickable {
                        width: parent.width
                        implicitHeight: hourlyRow.implicitHeight
                        contentWidth: hourlyRow.width
                        contentHeight: hourlyRow.implicitHeight
                        flickableDirection: Flickable.HorizontalFlick
                        clip: true
                        Row {
                            id: hourlyRow
                            spacing: 32 * root.s
                            Repeater {
                                model: Weather.hourly
                                delegate: Column {
                                    required property var modelData
                                    spacing: 8 * root.s
                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: modelData.time
                                        color: Theme.onSurface
                                        font.family: Theme.fontPrimary
                                        font.pixelSize: Theme.fontSm * root.s
                                        font.weight: Font.Bold
                                    }
                                    Pill.GlyphIcon {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        width: 20 * root.s
                                        height: 20 * root.s
                                        name: modelData.icon
                                        color: Theme.onSurface
                                        stroke: 1.6
                                    }
                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: modelData.temperature
                                        color: Theme.onSurface
                                        font.family: Theme.fontPrimary
                                        font.pixelSize: Theme.fontSm * root.s
                                        font.weight: Font.Bold
                                    }
                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: modelData.uv
                                        color: Theme.onSurface
                                        font.family: Theme.fontPrimary
                                        font.pixelSize: Theme.fontSm * root.s
                                        font.weight: Font.Bold
                                    }
                                }
                            }
                        }
                    }
                }

                // Daily page (7 items)
                WeatherCard {
                    id: dailyPage
                    s: root.s
                    width: viewport.width
                    title: qsTr("Daily Conditions")
                    Flickable {
                        width: parent.width
                        implicitHeight: dailyRow.implicitHeight
                        contentWidth: dailyRow.width
                        contentHeight: dailyRow.implicitHeight
                        flickableDirection: Flickable.HorizontalFlick
                        clip: true
                        Row {
                            id: dailyRow
                            spacing: 32 * root.s
                            Repeater {
                                model: Weather.daily
                                delegate: Column {
                                    required property var modelData
                                    spacing: 8 * root.s
                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: modelData.weekday
                                        color: Theme.onSurface
                                        font.family: Theme.fontPrimary
                                        font.pixelSize: Theme.fontSm * root.s
                                        font.weight: Font.Bold
                                    }
                                    Pill.GlyphIcon {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        width: 20 * root.s
                                        height: 20 * root.s
                                        name: modelData.icon
                                        color: Theme.onSurface
                                        stroke: 1.6
                                    }
                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: modelData.high
                                        color: Theme.onSurface
                                        font.family: Theme.fontPrimary
                                        font.pixelSize: Theme.fontSm * root.s
                                        font.weight: Font.Bold
                                    }
                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: modelData.low
                                        color: Theme.onSurface
                                        font.family: Theme.fontPrimary
                                        font.pixelSize: Theme.fontSm * root.s
                                        font.weight: Font.Bold
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
