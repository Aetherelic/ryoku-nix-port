pragma ComponentBehavior: Bound

import QtQuick
import ".." as Menus

Item {
    id: root

    property real s: 1
    property bool open: false
    property var navigate: null
    property var closePanel: null

    Flickable {
        anchors.fill: parent
        contentWidth: width
        contentHeight: weather.implicitHeight + 24
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height

        Menus.MenuWeather {
            id: weather
            x: 12
            y: 12
            width: parent.width - 24
            s: root.s
            open: root.open
        }
    }
}
