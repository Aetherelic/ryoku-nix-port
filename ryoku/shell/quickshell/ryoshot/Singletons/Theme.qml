pragma Singleton

import QtQuick
import Quickshell
import Ryoku.Ui.Singletons

Singleton {
    readonly property color accent: Tokens.sun
    readonly property color accentInk: Tokens.paper
    readonly property color panel: Qt.rgba(Tokens.paper.r, Tokens.paper.g, Tokens.paper.b, 0.92)
    readonly property color panelSolid: Tokens.paperLift
    readonly property color hair: Tokens.lineSoft

    readonly property color ink: Tokens.ink
    readonly property color inkDim: Tokens.inkDim
    readonly property color inkFaint: Tokens.inkFaint

    readonly property color scrim: Qt.rgba(0, 0, 0, 0.62)
    readonly property color danger: Tokens.alert

    readonly property color hover: Tokens.tint10
    readonly property color press: Tokens.tint16
    readonly property color field: Tokens.tint5

    // An annotation ink must stay recognisable whatever the wallpaper palette is,
    // so the fixed marker inks are literals rather than palette-derived.
    readonly property var swatches: [Tokens.sun, "#ffffff", "#111111", "#e23b3b", "#f2c14e", "#5bbf73", "#4f8fe0", "#b06fe0"]

    // A redaction must not retint with the palette, or a screenshot shared later
    // would read differently from the one the user checked before sending.
    readonly property color redactSolid: "#121216"

    readonly property string ui: Tokens.ui
    readonly property string mono: Tokens.mono
    readonly property string jp: Tokens.jp

    readonly property int radius: Tokens.radius * 2
    readonly property int snap: Tokens.snap
    readonly property int move: Tokens.move
}
