import QtQuick
import "../../modules"

// A titled group inside a route editor: an uppercase eyebrow, an optional line of
// supporting detail, then the body. `default` children flow into the body.
// Sizes match CcTokens.fontEyebrow / fontDetail.
Column {
    id: sec
    property var root
    property string title: ""
    property string desc: ""
    default property alias body: bodyCol.data

    spacing: 8

    UiText {
        visible: sec.title !== ""
        text: sec.title
        color: sec.root ? sec.root.sumiHi : "#888888"
        font.family: sec.root ? sec.root.mono : "monospace"
        font.pixelSize: 10
        font.letterSpacing: 1
        font.weight: Font.DemiBold
    }

    UiText {
        visible: sec.desc !== ""
        width: sec.width
        text: sec.desc
        color: sec.root ? sec.root.sumi : "#888888"
        font.family: sec.root ? sec.root.mono : "monospace"
        font.pixelSize: 10
        wrapMode: Text.WordWrap
        elide: Text.ElideRight
        maximumLineCount: 2
    }

    Column {
        id: bodyCol
        width: sec.width
        spacing: 8
    }
}
