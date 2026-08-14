import QtQuick
import "../../modules"

// Numeric stepper for values a segmented choice cannot carry. Emits `commit`
// with the clamped result; the caller owns the property.
Row {
    id: stepper

    property var root
    property int value: 0
    property int minimum: 0
    property int maximum: 64
    property int stepBy: 1
    property string suffix: ""

    signal commit(int value)

    spacing: 4

    component Btn: Rectangle {
        id: btn
        property string glyph: ""
        property bool live: true
        signal act

        width: 28
        height: 28
        radius: stepper.root.tileRadius
        color: btnMa.containsMouse && btn.live
            ? Qt.rgba(stepper.root.ink.r, stepper.root.ink.g, stepper.root.ink.b, 0.06)
            : stepper.root.fillIdle
        border.width: 1
        border.color: btnMa.containsMouse && btn.live
            ? Qt.rgba(stepper.root.ink.r, stepper.root.ink.g, stepper.root.ink.b, 0.28)
            : stepper.root.sep
        opacity: btn.live ? 1 : 0.4
        Behavior on color { ColorAnimation { duration: 120 } }

        UiText {
            anchors.centerIn: parent
            text: btn.glyph
            color: stepper.root.ink
            font.family: stepper.root.mono
            font.pixelSize: 12
        }
        MouseArea {
            id: btnMa
            anchors.fill: parent
            hoverEnabled: true
            enabled: btn.live
            cursorShape: Qt.PointingHandCursor
            onClicked: btn.act()
        }
    }

    Btn {
        glyph: "\u2212"
        live: stepper.value > stepper.minimum
        onAct: stepper.commit(Math.max(stepper.minimum, stepper.value - stepper.stepBy))
    }
    UiText {
        anchors.verticalCenter: parent.verticalCenter
        width: 36
        horizontalAlignment: Text.AlignHCenter
        text: stepper.value + stepper.suffix
        color: stepper.root.ink
        font.family: stepper.root.mono
        font.pixelSize: 12
        font.features: ({ "tnum": 1 })
    }
    Btn {
        glyph: "+"
        live: stepper.value < stepper.maximum
        onAct: stepper.commit(Math.min(stepper.maximum, stepper.value + stepper.stepBy))
    }
}
