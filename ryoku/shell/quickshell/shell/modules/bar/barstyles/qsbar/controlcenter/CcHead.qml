import QtQuick
import "../modules"
import Ryoku.Ui.Singletons

// The body's head: the route's name in the display face with its kanji seal, the
// route's one-line summary, and a state line that prints the facts the bar is
// actually in right now. That state line is what the old "STATE SYNCED" badge and
// the separate status strip were reaching for: a badge that says a write landed
// tells the user nothing, whereas "ISLANDS / TOP / ACCENT F" tells them what they
// are looking at.
Item {
    id: head

    property var root
    property var tk
    property string title: ""
    property string gloss: ""
    property string desc: ""
    signal closed()

    implicitHeight: head.tk.headH

    Row {
        id: name
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.topMargin: head.tk.gap / 2
        spacing: head.tk.gap

        UiText {
            anchors.baseline: nameText.baseline
            text: head.gloss
            color: Tokens.inkFaint
            font.family: Tokens.jp
            font.pixelSize: Tokens.fBody
        }
        UiText {
            id: nameText
            text: I18n.tr(head.title)
            color: Tokens.ink
            font.family: Tokens.display
            font.pixelSize: Tokens.fValue
        }
    }

    // The summary runs the head's full width: the state line and the close mark
    // ride the title's row above it, so there is nothing here to make room for.
    UiText {
        anchors.left: parent.left
        anchors.top: name.bottom
        anchors.topMargin: 2
        anchors.right: parent.right
        text: I18n.tr(head.desc)
        color: Tokens.inkFaint
        font.family: Tokens.ui
        font.pixelSize: Tokens.fSmall
        elide: Text.ElideRight
    }

    // the live facts, mono so they read as a readout rather than a sentence.
    // Anchored to the head, not to the title's baseline: the title lives inside a
    // Row, and a nephew is not a sibling.
    UiText {
        id: state
        anchors.right: shut.left
        anchors.rightMargin: head.tk.gap
        anchors.top: parent.top
        anchors.topMargin: head.tk.gap
        text: head.stateLine()
        color: Tokens.inkMuted
        font.family: Tokens.mono
        font.pixelSize: Tokens.fMicro
        font.letterSpacing: Tokens.trackLabel
    }

    function stateLine() {
        if (!head.root)
            return "";
        var form = String(head.root.barShellStyle || "").toUpperCase();
        var pos = String(head.root.barPosition || "").toUpperCase();
        var accent = String(head.root.barColor || "").toUpperCase();
        return [form, pos, accent].filter(function (p) { return p.length > 0; }).join("  \u00b7  ");
    }

    Rectangle {
        id: shut
        anchors.right: parent.right
        anchors.top: parent.top
        width: Tokens.ctlH
        height: Tokens.ctlH
        radius: Tokens.radius
        color: shutMa.containsMouse ? Tokens.tint5 : "transparent"
        Behavior on color { ColorAnimation { duration: Tokens.snap } }

        UiText {
            anchors.centerIn: parent
            text: "\u2715"
            color: shutMa.containsMouse ? Tokens.ink : Tokens.inkFaint
            font.family: Tokens.mono
            font.pixelSize: Tokens.fSmall
        }
        MouseArea {
            id: shutMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: head.closed()
        }
    }

    Rectangle {
        anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
        height: 1
        color: Tokens.lineSoft
    }
}
