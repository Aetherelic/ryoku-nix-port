pragma Singleton

import QtQuick
import Quickshell
import Ryoku.Ui.Singletons

// ryopin is a separate Quickshell config and cannot import ryoshot's Singletons,
// so this is a second copy of the same Tokens derivation, trimmed to the roles a
// pin uses.
Singleton {
    readonly property color panel: Qt.rgba(Tokens.paper.r, Tokens.paper.g, Tokens.paper.b, 0.92)
    readonly property color panelSolid: Tokens.paperLift
    readonly property color hair: Tokens.lineSoft
    readonly property color shadow: Qt.rgba(0, 0, 0, 0.5)

    readonly property color ink: Tokens.ink
    readonly property color inkDim: Tokens.inkDim

    readonly property color accent: Tokens.sun
    readonly property color accentInk: Tokens.paper

    readonly property color hover: Tokens.tint10

    readonly property string ui: Tokens.ui
    readonly property string mono: Tokens.mono

    readonly property int radius: Tokens.radius * 2
    readonly property int snap: Tokens.snap
}
