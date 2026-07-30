import QtQuick
import "../../../Singletons"
import "../../.." as Pill

Item {
    id: root

    property real barHeight: 40
    signal popupRequested(string name, real center, bool active, bool pinned)

    implicitWidth: content.implicitWidth
    implicitHeight: 26

    Component.onCompleted: Sysinfo.setActive(root, true)
    Component.onDestruction: Sysinfo.setActive(root, false)
    TapHandler {
        onTapped: root.popupRequested("resources",
            root.mapToItem(null, root.width / 2, root.height / 2).x, true, true)
    }

    component HealthValue: Row {
        required property string glyph
        required property string value
        property color valueColor: Theme.onSurfaceVariant

        spacing: 3

        Pill.MaterialIcon {
            anchors.verticalCenter: parent.verticalCenter
            text: parent.glyph
            color: parent.valueColor
            font.pixelSize: Theme.iconSm
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: parent.value
            color: parent.valueColor
            font.family: Theme.mono
            font.pixelSize: Theme.fontSm
        }
    }

    Row {
        id: content
        anchors.centerIn: parent
        spacing: 8

        HealthValue {
            objectName: "nacre-health-cpu"
            glyph: "memory"
            value: Math.round(Sysinfo.cpu * 100) + "%"
            valueColor: Sysinfo.cpu > 0.85 ? Theme.error : Theme.onSurfaceVariant
        }
        HealthValue {
            objectName: "nacre-health-memory"
            glyph: "memory_alt"
            value: Math.round(Sysinfo.mem * 100) + "%"
            valueColor: Sysinfo.mem > 0.9 ? Theme.error : Theme.onSurfaceVariant
        }
        HealthValue {
            objectName: "nacre-health-temperature"
            visible: Sysinfo.hasTemp
            glyph: "thermostat"
            value: Math.round(Sysinfo.tempC) + "°"
            valueColor: Sysinfo.tempC > 80 ? Theme.error : Theme.onSurfaceVariant
        }
    }

}
