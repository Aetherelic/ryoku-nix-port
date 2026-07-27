import QtQuick
import Ryoku.Ui.Singletons

// The small list head shared by the studio's widget lists and the catalogue:
// a mono // lead, the tracked name, a soft leader, and a count tag registering
// how many rows follow. The section-mark vocabulary, one size down.
Item {
    id: head
    property string label: ""
    property string count: ""
    implicitHeight: 18

    Row {
        id: lead
        spacing: Tokens.s2
        anchors.verticalCenter: parent.verticalCenter
        Text {
            text: "//"
            color: Tokens.inkFaint
            font.family: Tokens.mono
            font.pixelSize: Tokens.fTiny
            anchors.verticalCenter: parent.verticalCenter
        }
        Text {
            text: head.label + "_"
            color: Tokens.inkMuted
            font.family: Tokens.ui
            font.pixelSize: Tokens.fMicro
            font.weight: Font.Medium
            font.letterSpacing: Tokens.trackLabel
            anchors.verticalCenter: parent.verticalCenter
        }
    }
    Text {
        id: tally
        visible: head.count !== ""
        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
        text: head.count
        color: Tokens.inkFaint
        font.family: Tokens.mono
        font.pixelSize: Tokens.fTiny
    }
    Rectangle {
        anchors { left: lead.right; right: tally.visible ? tally.left : parent.right; verticalCenter: parent.verticalCenter }
        anchors.leftMargin: Tokens.s3
        anchors.rightMargin: tally.visible ? Tokens.s3 : 0
        height: 1
        color: Tokens.lineSoft
    }
}
