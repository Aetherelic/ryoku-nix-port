import QtQuick
import "Singletons"

Rectangle {
    id: btn
    property string glyph: ""

    signal clicked()

    width: 26
    height: 26
    radius: Theme.radius / 2
    color: ma.containsMouse ? Theme.hover : "transparent"

    Text {
        anchors.centerIn: parent
        text: btn.glyph
        font.family: Theme.ui
        font.pixelSize: 14
        color: ma.containsMouse ? Theme.ink : Theme.inkDim
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton
        cursorShape: Qt.PointingHandCursor
        onClicked: btn.clicked()
    }
}
