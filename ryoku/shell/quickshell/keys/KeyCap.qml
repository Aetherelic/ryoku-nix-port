import QtQuick
import Ryoku.Ui.Singletons

// One key cap in the shipped legend's vocabulary: a hairline rect with a mono
// glyph, no fill and no colour spent. Modifiers and keys look identical -- Ryoku
// leans on type and space, not accent, so the whole sheet stays quiet.
Rectangle {
    id: cap
    property string text: ""

    implicitHeight: 22
    implicitWidth: Math.max(22, label.implicitWidth + 14)
    radius: Tokens.radius
    color: "transparent"
    border.width: Tokens.border
    border.color: Tokens.line

    Text {
        id: label
        anchors.centerIn: parent
        text: cap.text
        color: Tokens.inkDim
        font.family: Tokens.mono
        font.pixelSize: Tokens.fMicro
    }
}
