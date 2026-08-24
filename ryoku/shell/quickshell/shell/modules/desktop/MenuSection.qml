import QtQuick
import "Singletons"

// A section eyebrow inside a context menu: a kanji gloss then a tracked
// small-caps label with a hairline leader, the studio's rhythm between control
// groups. With no label it is a plain hairline divider.
Item {
    id: sec

    property string label: ""
    property string gloss: ""

    width: parent ? parent.width : 0
    implicitHeight: sec.label.length > 0 ? Theme.ctlH : Theme.s3

    Row {
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        spacing: Theme.s2

        Text {
            id: gl
            visible: sec.gloss.length > 0 && sec.label.length > 0
            anchors.verticalCenter: parent.verticalCenter
            text: sec.gloss
            color: Theme.faint
            font.family: Theme.fontJp
            font.pixelSize: Theme.fMicro
        }
        Text {
            id: cap
            visible: sec.label.length > 0
            anchors.verticalCenter: parent.verticalCenter
            text: sec.label.toUpperCase()
            color: Theme.inkDim
            font.family: Theme.font
            font.pixelSize: Theme.fMicro
            font.weight: Font.DemiBold
            font.letterSpacing: Theme.trackMark
        }
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - (gl.visible ? gl.width + parent.spacing : 0) - (cap.visible ? cap.width + parent.spacing : 0)
            height: 1
            color: Theme.line
        }
    }
}
