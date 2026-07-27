import QtQuick
import Ryoku.Ui.Singletons
import "Singletons"

// The pending rice diff: the dirty-state machine pointed at the desktop. Clean
// (the pick already wears on the desktop) is a hairline card that says so. Dirty
// inverts to bone (the screen's one editorial plate) and states what the
// desktop still wears, with the current and candidate strips and up to three
// rows in file syntax. SET WALLPAPER flips it back, which is the confirmation.
Item {
    id: card

    // the state, owned by App (it holds the session's applied-desktop baseline).
    property bool clean: false
    property bool desktopValid: false
    property string desktopName: ""
    property var desktopColours: []
    property string desktopImage: ""
    property real desktopFrame: 1
    property string candImage: ""
    property bool isVideo: false

    readonly property var candColours: Wallhaven.palette
    readonly property real candFrame: Wallhaven.settings.frame

    function base(p) { var s = "" + p; var i = s.lastIndexOf("/"); return i >= 0 ? s.slice(i + 1) : s; }
    function changedCount() {
        if (!desktopValid) return 16;
        var n = 0;
        for (var i = 0; i < 16; i++) {
            var a = (desktopColours && desktopColours.length > i) ? desktopColours[i] : "";
            var b = (candColours && candColours.length > i) ? candColours[i] : "";
            if (("" + a).toLowerCase() !== ("" + b).toLowerCase()) n++;
        }
        return n;
    }
    readonly property bool imageDiff: !desktopValid || desktopImage !== candImage
    readonly property bool frameDiff: isVideo && (!desktopValid || Math.abs(desktopFrame - candFrame) > 0.001)

    implicitHeight: clean ? 40 : dirtyCol.implicitHeight + 2 * Tokens.s3

    Rectangle {
        anchors.fill: parent
        radius: Tokens.radius
        color: card.clean ? "transparent" : Tokens.bone
        border.width: card.clean ? Tokens.border : 0
        border.color: Tokens.line
    }

    // clean: this is your desktop.
    Text {
        anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: Tokens.s3 }
        visible: card.clean
        text: "This is your desktop."
        color: Tokens.inkMuted
        font.family: Tokens.ui
        font.pixelSize: 12
    }

    // dirty: the editorial plate.
    Column {
        id: dirtyCol
        visible: !card.clean
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: Tokens.s3 }
        spacing: Tokens.s2

        Item {
            width: parent.width
            height: 14
            Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - countTag.width - Tokens.s2
                elide: Text.ElideRight
                text: card.desktopValid
                      ? "PREVIEWING · YOUR DESKTOP STILL WEARS " + (card.desktopName.length ? card.desktopName.toUpperCase() : "IT")
                      : "PREVIEWING · NOT YET SET ON YOUR DESKTOP"
                color: Tokens.inkOnBone
                font.family: Tokens.ui
                font.pixelSize: 11
                font.weight: Font.Medium
                font.letterSpacing: 1.2
            }
            Text {
                id: countTag
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: card.desktopValid ? card.changedCount() + " OF 16 COLOURS CHANGE" : "NOT YET ON YOUR DESKTOP"
                color: Tokens.inkOnBoneDim
                font.family: Tokens.mono
                font.pixelSize: 9
            }
        }

        // current strip, struck (only when we know what the desktop wears).
        Column {
            width: parent.width
            spacing: 2
            visible: card.desktopValid
            Text {
                text: "current"
                color: Tokens.inkOnBoneDim
                font.family: Tokens.mono
                font.pixelSize: 9
                font.strikeout: true
            }
            PaletteRow { width: parent.width; implicitHeight: 16; colors: card.desktopColours }
        }
        // candidate strip, in full.
        Column {
            width: parent.width
            spacing: 2
            Text {
                text: "candidate"
                color: Tokens.inkOnBone
                font.family: Tokens.mono
                font.pixelSize: 9
            }
            PaletteRow { width: parent.width; implicitHeight: 16; colors: card.candColours }
        }

        // up to two rows in file syntax: image, frame.
        Column {
            width: parent.width
            spacing: 1
            DiffRow { visible: card.imageDiff; k: "image";   was: card.desktopValid ? card.base(card.desktopImage) : "(none)"; now: card.base(card.candImage) }
            DiffRow { visible: card.frameDiff; k: "frame";   was: card.desktopValid ? card.desktopFrame.toFixed(1) + "s" : "(default)"; now: card.candFrame.toFixed(1) + "s" }
        }
    }

    // one file-syntax row: key, then the old struck and the new in ink.
    component DiffRow: Row {
        property string k: ""
        property string was: ""
        property string now: ""
        spacing: Tokens.s2
        Text { text: k; color: Tokens.inkOnBoneDim; font.family: Tokens.mono; font.pixelSize: 12; width: 52 }
        Text { text: was; color: Tokens.inkOnBoneDim; font.family: Tokens.mono; font.pixelSize: 12; font.strikeout: true }
        Text { text: "->"; color: Tokens.inkOnBoneDim; font.family: Tokens.mono; font.pixelSize: 12 }
        Text { text: now; color: Tokens.inkOnBone; font.family: Tokens.mono; font.pixelSize: 12 }
    }
}
