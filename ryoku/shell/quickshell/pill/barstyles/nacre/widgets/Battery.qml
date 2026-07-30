import QtQuick
import "../../../Singletons"
import "../../.." as Pill
import "../../shared/Format.js" as Format

Item {
    id: root

    property real barHeight: 40
    signal popupRequested(string name, real center, bool active, bool pinned)
    readonly property bool charging: Battery.charging || Battery.full

    implicitWidth: content.implicitWidth
    implicitHeight: 26
    visible: Battery.present

    TapHandler {
        onTapped: root.popupRequested("battery",
            root.mapToItem(null, root.width / 2, root.height / 2).x, true, true)
    }

    Row {
        id: content
        anchors.centerIn: parent
        spacing: 4

        Pill.SymbolIcon {
            anchors.verticalCenter: parent.verticalCenter
            name: Format.batteryGlyph(Battery.pct, root.charging)
            size: 17
            color: Battery.low ? Theme.error : Theme.onSurfaceVariant
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: Battery.pct + "%"
            color: Battery.low ? Theme.error : Theme.onSurfaceVariant
            font.family: Theme.mono
            font.pixelSize: Theme.fontSm
        }
    }

}
