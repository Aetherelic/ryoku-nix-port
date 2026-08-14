import QtQuick
import QtQuick.Effects

// Optional depth behind a pill, panel, tooltip or menu card, off until the user
// enables it. The bar shell's own screen-facing shadow is separate.
RectangularShadow {
    id: pillShadow

    required property var theme

    anchors.fill: parent
    radius: parent && parent.radius !== undefined ? parent.radius : 0
    blur: 8
    spread: 0
    // Falls away from the edge the bar is anchored to.
    offset: Qt.vector2d(0, theme && theme.barPosition === "bottom" ? -1 : 1)
    color: theme ? theme.pillShadow : Qt.rgba(0, 0, 0, 0.55)
    visible: theme ? theme.barShadowEnabled === true : false
    z: -1
}
