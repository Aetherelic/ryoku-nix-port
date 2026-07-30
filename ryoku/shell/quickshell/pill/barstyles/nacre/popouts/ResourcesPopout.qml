pragma ComponentBehavior: Bound

import QtQuick
import "../../../Singletons"

Item {
    implicitWidth: 280
    implicitHeight: content.implicitHeight + 36

    component Meter: Column {
        id: meter

        property string label: ""
        property real fraction: 0
        property string value: ""

        width: parent.width
        spacing: 4

        Item {
            width: parent.width
            height: labelText.implicitHeight

            Text {
                id: labelText
                anchors.left: parent.left
                text: meter.label
                color: Theme.onSurfaceVariant
                font.family: Theme.fontPrimary
                font.pixelSize: Theme.fontSm
            }
            Text {
                anchors.right: parent.right
                text: meter.value
                color: Theme.onSurface
                font.family: Theme.mono
                font.pixelSize: Theme.fontSm
            }
        }

        Rectangle {
            width: parent.width
            height: 4
            radius: 2
            color: Qt.rgba(Theme.onSurface.r, Theme.onSurface.g, Theme.onSurface.b, 0.15)

            Rectangle {
                width: parent.width * Math.max(0, Math.min(1, meter.fraction))
                height: parent.height
                radius: parent.radius
                color: Theme.onSurface
            }
        }
    }

    Column {
        id: content
        anchors.centerIn: parent
        width: 240
        spacing: 12

        Text {
            text: "Resources"
            color: Theme.onSurface
            font.family: Theme.fontPrimary
            font.pixelSize: Theme.fontMd
            font.weight: Font.Bold
        }
        Meter {
            label: "CPU"
            fraction: Sysinfo.cpu
            value: Math.round(Sysinfo.cpu * 100) + "%"
        }
        Meter {
            label: "Memory"
            fraction: Sysinfo.mem
            value: Sysinfo.memUsedGiB.toFixed(1) + " / " + Sysinfo.memTotalGiB.toFixed(1) + " GiB"
        }
        Meter {
            visible: Sysinfo.hasTemp
            label: "Temperature"
            fraction: Math.min(1, Sysinfo.tempC / 100)
            value: Math.round(Sysinfo.tempC) + "°C"
        }
    }
}
