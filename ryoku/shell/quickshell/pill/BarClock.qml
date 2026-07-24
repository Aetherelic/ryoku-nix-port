import QtQuick
import Quickshell
import "Singletons"

// Compact atoll clock: stacked time and date when the islands are tall enough,
// one line on a thinner bar.
Item {
    id: clock

    property real s: 1
    readonly property var loc: Qt.locale("en_US")
    readonly property bool stacked: Config.barHeight >= 30

    implicitWidth: face.implicitWidth
    implicitHeight: face.implicitHeight

    SystemClock {
        id: sys
        precision: SystemClock.Minutes
    }

    Column {
        id: face
        spacing: 0

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: !clock.stacked
            spacing: 6 * clock.s

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Qt.formatTime(sys.date, "HH:mm")
                color: Theme.cream
                font.family: Theme.font
                font.pixelSize: 11.5 * clock.s
                font.weight: Font.DemiBold
                font.features: ({ "tnum": 1 })
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: clock.loc.toString(sys.date, "ddd d MMM")
                color: Theme.dim
                font.family: Theme.font
                font.pixelSize: 11.5 * 0.72 * clock.s
                font.weight: Font.Medium
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: clock.stacked
            text: Qt.formatTime(sys.date, "HH:mm")
            color: Theme.cream
            font.family: Theme.font
            font.pixelSize: 12 * clock.s
            font.weight: Font.DemiBold
            font.features: ({ "tnum": 1 })
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: clock.stacked
            text: clock.loc.toString(sys.date, "ddd d MMM")
            color: Theme.dim
            font.family: Theme.font
            font.pixelSize: 12 * 0.62 * clock.s
            font.weight: Font.Medium
        }
    }
}
