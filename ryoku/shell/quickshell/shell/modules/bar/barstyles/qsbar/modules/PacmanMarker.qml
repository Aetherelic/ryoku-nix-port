import QtQuick

// A single pacman workspace cell: focused draws the pacman glyph, occupied a
// pellet glyph, empty a small dimmed circle. eatProgress/eatDirection let the
// travelling pacman "eat" the pellet it lands on (fade, shrink and slide toward
// the mouth); WorkspaceWidget drives those from its travel state machine.
Item {
    id: marker

    required property bool focused
    required property bool occupied
    property bool hovered: false
    property real eatProgress: 0
    property int eatDirection: 1
    property color activeColor: "white"
    property color occupiedColor: "white"
    property color emptyColor: "white"
    property color hoverColor: "white"

    readonly property int glyphSize: 14
    readonly property int pelletSize: 5
    readonly property real eatOffset: 3
    readonly property real boundedEatProgress: Math.max(0, Math.min(1, eatProgress))
    readonly property real hoverFactor: hovered && boundedEatProgress === 0 ? 1.08 : 1

    implicitWidth: 22
    implicitHeight: 18
    opacity: 1 - boundedEatProgress
    scale: (1 - 0.45 * boundedEatProgress) * hoverFactor
    transformOrigin: Item.Center
    transform: Translate {
        x: -marker.eatDirection * marker.eatOffset * marker.boundedEatProgress
    }

    Behavior on scale {
        enabled: marker.boundedEatProgress === 0
        NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
    }

    Text {
        anchors.centerIn: parent
        visible: marker.focused || marker.occupied
        text: marker.focused ? String.fromCodePoint(0xF0BAF) : String.fromCodePoint(0xF02A0)
        color: marker.hovered ? marker.hoverColor
             : marker.focused ? marker.activeColor
                              : marker.occupiedColor
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: marker.glyphSize
        font.weight: Font.Bold
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        renderType: Text.NativeRendering

        Behavior on color { ColorAnimation { duration: 140; easing.type: Easing.OutCubic } }
    }

    Rectangle {
        visible: !marker.focused && !marker.occupied
        anchors.centerIn: parent
        width: marker.pelletSize
        height: width
        radius: width / 2
        color: marker.hovered ? marker.hoverColor : marker.emptyColor
        opacity: marker.hovered ? 0.90 : 0.55
        antialiasing: true

        Behavior on color { ColorAnimation { duration: 140; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
    }
}
