pragma ComponentBehavior: Bound

import QtQuick
import shell.services
import "../../components"

// Compact HUD action. Optional checked and tooltip states make preview toggles
// readable without giving ordinary transport buttons extra visual weight.
Rectangle {
    id: btn

    property real s: 1
    property string glyph: ""
    property color tint: Theme.onSurfaceVariant
    property bool checked: false
    property bool checkable: false
    property string tip: ""
    readonly property bool tipVisible: tip !== "" && btn.visible
        && (hov.hovered || btn.activeFocus)
    signal tapped()

    width: 26 * s
    height: 26 * s
    radius: 7 * s
    color: checked
        ? Qt.rgba(btn.tint.r, btn.tint.g, btn.tint.b, 0.16)
        : (hov.hovered || activeFocus ? Theme.surfaceContainerHigh : "transparent")
    border.width: checked || activeFocus ? 1 * s : 0
    border.color: Qt.rgba(btn.tint.r, btn.tint.g, btn.tint.b, 0.58)
    Behavior on color { ColorAnimation { duration: Motion.fast } }
    Behavior on scale { NumberAnimation { duration: Motion.fast; easing.type: Easing.OutCubic } }

    scale: press.active ? 0.94 : 1
    activeFocusOnTab: true
    Accessible.role: Accessible.Button
    Accessible.name: tip !== "" ? tip : glyph
    Accessible.description: tip
    Accessible.checkable: checkable
    Accessible.checked: checked

    GlyphIcon {
        anchors.centerIn: parent
        width: 15 * btn.s
        height: 15 * btn.s
        name: btn.glyph
        color: btn.tint
        stroke: 1.7
    }


    HoverHandler { id: hov; cursorShape: Qt.PointingHandCursor }
    TapHandler { id: press; onTapped: btn.tapped() }
    Keys.onPressed: event => {
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
            btn.tapped();
            event.accepted = true;
        }
    }
}
