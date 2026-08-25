import QtQuick
import QtQuick.Shapes

// CANONICAL copy (Ryoku.Ui): used by the shell polkit surface and the Hub
// enroll UI. The standalone offline lock bundle keeps a byte-identical mirror at
// ryoku/lockscreen/qylock/quickshell-lockscreen/FingerprintScan.qml (it cannot
// import Ryoku.Ui; it vendors its deps, like SddmComponents). Keep in sync.
//
// Shared fingerprint scan / unlock visual. Self-contained (QtQuick +
// QtQuick.Shapes only, no palette singleton), state-driven, no auth logic: a
// parent binds `phase` (+ `progress` for enroll) and this only draws. That is
// what lets one component ride above every lock skin with zero per-theme code.
//
// phase:  off      hidden (no reader / no enrolled finger)
//         ready    armed and listening (a calm breath)
//         scanning a finger is being read (accent fills the ridges bottom-up)
//         success  matched (ridges full, ring completes, a small settle)
//         fail     no match (warm-red flush + shake, parent re-arms)
//         enroll   recording: ridges + ring fill to `progress` (0..1)
Item {
    id: root

    property string phase: "ready"
    property real progress: 0
    property color accent: "#ffb59b"
    property color ink: "#efe3dd"
    property int sizePx: 92
    property int ringW: Math.max(2, Math.round(sizePx * 0.03))

    implicitWidth: sizePx
    implicitHeight: sizePx
    visible: opacity > 0.01
    opacity: phase === "off" ? 0 : 1
    Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

    readonly property color failCol: "#e0806f"
    readonly property color liveCol: phase === "fail" ? failCol : accent

    property real revealDur: phase === "scanning" ? 1350 : 300
    property real reveal: (phase === "scanning" || phase === "success" || phase === "fail")
        ? 1 : (phase === "enroll" ? Math.max(0, Math.min(1, progress)) : 0)
    property real ringSweep: Math.min(359.9, (phase === "success" || phase === "fail")
        ? 360 : (phase === "enroll" ? 360 * Math.max(0, Math.min(1, progress)) : 0))
    Behavior on reveal { NumberAnimation { duration: root.revealDur; easing.type: Easing.OutCubic } }
    Behavior on ringSweep { NumberAnimation { duration: 450; easing.type: Easing.OutCubic } }

    // a stroked fingerprint (9 Lucide ridges in a 24x24 box), scaled to fit and
    // coloured by `col`. Vector, so it stays crisp at any sensor size.
    component Ridges: Shape {
        id: sh
        property color col: "white"
        property real k: width / 24
        antialiasing: true
        transform: Scale { xScale: sh.k; yScale: sh.k }
        ShapePath {
            strokeColor: sh.col
            fillColor: "transparent"
            strokeWidth: 2 / sh.k
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            PathSvg { path: "M12 10a2 2 0 0 0-2 2c0 1.02-.1 2.51-.26 4" }
            PathSvg { path: "M14 13.12c0 2.38 0 6.38-1 8.88" }
            PathSvg { path: "M17.29 21.02c.12-.6.43-2.3.5-3.02" }
            PathSvg { path: "M2 12a10 10 0 0 1 18-6" }
            PathSvg { path: "M2 16h.01" }
            PathSvg { path: "M21.8 16c.2-2 .131-5.354 0-6" }
            PathSvg { path: "M5 19.5C5.5 18 6 15 6 12a6 6 0 0 1 .34-2" }
            PathSvg { path: "M8.65 22c.21-.66.45-1.32.57-2" }
            PathSvg { path: "M9 6.8a6 6 0 0 1 9 5.2v2" }
        }
    }

    Item {
        id: content
        anchors.fill: parent
        transform: Translate { id: shakeT; x: 0 }

        // sensor disc
        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.05)
            border.width: 1
            border.color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.14)
        }

        // completion ring (draws on success / fills on enroll)
        Shape {
            anchors.fill: parent
            antialiasing: true
            ShapePath {
                strokeColor: root.liveCol
                strokeWidth: root.ringW
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                PathAngleArc {
                    centerX: root.width / 2
                    centerY: root.height / 2
                    radiusX: root.width / 2 - root.ringW
                    radiusY: root.height / 2 - root.ringW
                    startAngle: -90
                    sweepAngle: root.ringSweep
                }
            }
        }

        // fingerprint: dim base + accent reveal from the bottom
        Item {
            id: fpBox
            width: root.sizePx * 0.56
            height: width
            anchors.centerIn: parent

            Ridges {
                anchors.fill: parent
                col: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.5)
            }

            Item {
                width: parent.width
                height: parent.height * root.reveal
                anchors.bottom: parent.bottom
                clip: true
                Ridges {
                    width: fpBox.width
                    height: fpBox.height
                    anchors.bottom: parent.bottom
                    col: root.liveCol
                }
            }

            // the read line, riding the reveal boundary while scanning
            Rectangle {
                width: parent.width * 1.16
                x: -parent.width * 0.08
                height: 1
                color: root.accent
                y: parent.height * (1 - root.reveal)
                opacity: root.phase === "scanning" ? 0.9 : 0
                Behavior on opacity { NumberAnimation { duration: 150 } }
            }
        }
    }

    // a calm breath while armed and waiting
    SequentialAnimation {
        running: root.phase === "ready"
        loops: Animation.Infinite
        alwaysRunToEnd: true
        NumberAnimation { target: content; property: "opacity"; from: 0.72; to: 1; duration: 1700; easing.type: Easing.InOutSine }
        NumberAnimation { target: content; property: "opacity"; to: 0.72; duration: 1700; easing.type: Easing.InOutSine }
    }
    Binding {
        target: content
        property: "opacity"
        value: 1
        when: root.phase !== "ready"
    }

    // a small settle on success, a short shake on fail
    SequentialAnimation {
        id: pop
        NumberAnimation { target: content; property: "scale"; from: 1; to: 1.045; duration: 160; easing.type: Easing.OutBack }
        NumberAnimation { target: content; property: "scale"; to: 1; duration: 220; easing.type: Easing.OutCubic }
    }
    SequentialAnimation {
        id: shake
        loops: 2
        NumberAnimation { target: shakeT; property: "x"; to: -3; duration: 55 }
        NumberAnimation { target: shakeT; property: "x"; to: 3; duration: 55 }
        NumberAnimation { target: shakeT; property: "x"; to: 0; duration: 55 }
    }
    onPhaseChanged: {
        if (phase === "success")
            pop.restart();
        else if (phase === "fail")
            shake.restart();
    }
}
