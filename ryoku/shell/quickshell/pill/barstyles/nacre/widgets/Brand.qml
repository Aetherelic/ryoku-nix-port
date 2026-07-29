import QtQuick
import Quickshell
import "../../.." as Pill

Item {
    property real barHeight: 40

    implicitWidth: 24
    implicitHeight: 26

    Pill.BrandMark {
        anchors.centerIn: parent
        size: 12
    }
    TapHandler {
        onTapped: Quickshell.execDetached(["ryoku-shell", "launcher"])
    }
}
