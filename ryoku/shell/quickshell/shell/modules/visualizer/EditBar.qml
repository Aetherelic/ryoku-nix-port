pragma ComponentBehavior: Bound
import QtQuick
import Ryoku.Ui
import Ryoku.Ui.Singletons
import "Singletons"

// The spectrum's editing bar, shown while a look is being placed, so a look is tuned
// where you can see it rather than in the Hub with the desktop behind a window.
//
// Fixed to an edge of the screen, never to the box: a readout of the thing being
// moved must not move with it. Controls come from Ryoku.Ui and metrics from Tokens;
// the tray is the Hub's gallery with the Hub's painter, so one catalogue draws what
// the eleven looks look like.
Item {
    id: bar

    // The box being placed, in screen px, so the bar can step out from under it.
    required property rect box

    signal done

    readonly property bool atTop: bar.box.y + bar.box.height > bar.height - 200
    readonly property alias trayOpen: tray.open

    function closeTray() { tray.open = false; }
    function toggleTray() { tray.open = !tray.open; }

    anchors.fill: parent

    // --- the look tray --------------------------------------------------------
    Rectangle {
        id: tray
        property bool open: false

        x: Math.round((bar.width - width) / 2)
        y: bar.atTop ? plate.y + plate.height + Tokens.s3 : plate.y - height - Tokens.s3
        width: gal.width + 2 * Tokens.s4
        height: gal.height + 2 * Tokens.s4
        radius: Tokens.radius
        color: Qt.alpha(Tokens.paper, 0.94)
        border.width: Tokens.border
        border.color: Tokens.line
        visible: opacity > 0.01
        opacity: tray.open ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Tokens.swap; easing.type: Tokens.ease } }

        // a shield: a click that misses a tile must not start a drag behind the tray
        MouseArea { anchors.fill: parent; acceptedButtons: Qt.LeftButton | Qt.RightButton }

        Gallery {
            id: gal
            anchors.centerIn: parent
            width: 11 * 132 + 10 * 7
            painter: VizStyles
            options: VizStyles.styles.map(function (s) { return { key: s.key, origin: s.kind, draw: s.key }; })
            current: Config.styleId
            onChose: (k) => {
                Config.setStyle(k);
                tray.open = false;
            }
        }
    }

    // --- the bar --------------------------------------------------------------
    Rectangle {
        id: plate
        x: Math.round((bar.width - width) / 2)
        y: bar.atTop ? Tokens.s5 : Math.round(bar.height - height - Tokens.s5)
        width: col.width + 2 * Tokens.s5
        height: col.height + 2 * Tokens.s4
        radius: Tokens.radius
        color: Qt.alpha(Tokens.paper, 0.94)
        border.width: Tokens.border
        border.color: Tokens.line

        MouseArea { anchors.fill: parent; acceptedButtons: Qt.LeftButton | Qt.RightButton }

        Column {
            id: col
            anchors.centerIn: parent
            spacing: Tokens.s3

            Row {
                id: controls
                spacing: Tokens.s5

                Group {
                    label: I18n.tr("LOOK")
                    // Drawn, because a name alone does not say what a ribbon is.
                    Rectangle {
                        width: 176
                        height: 30
                        radius: Tokens.radius
                        color: tray.open ? Tokens.tint16 : (lookHov.hovered ? Tokens.tint10 : "transparent")
                        border.width: Tokens.border
                        border.color: tray.open ? Tokens.ink : (lookHov.hovered ? Tokens.lineStrong : Tokens.line)
                        Behavior on color { ColorAnimation { duration: Tokens.snap } }

                        Row {
                            anchors { left: parent.left; leftMargin: Tokens.s2; verticalCenter: parent.verticalCenter }
                            spacing: Tokens.s2
                            Canvas {
                                id: art
                                width: 46
                                height: 20
                                anchors.verticalCenter: parent.verticalCenter
                                onPaint: {
                                    var c = getContext("2d");
                                    c.reset();
                                    VizStyles.draw(c, Config.styleId, width, height, 0.98, 0.45);
                                }
                                Component.onCompleted: art.requestPaint()
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: Config.styleId
                                color: Tokens.ink
                                font.family: Tokens.ui
                                font.pixelSize: Tokens.fRow
                                font.weight: Font.DemiBold
                            }
                        }
                        Text {
                            anchors { right: parent.right; rightMargin: Tokens.s2; verticalCenter: parent.verticalCenter }
                            text: tray.open ? "\u25b4" : "\u25be"
                            color: Tokens.inkDim
                            font.pixelSize: 11
                        }
                        HoverHandler { id: lookHov; cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: bar.toggleTray() }
                        WheelHandler {
                            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                            onWheel: (w) => Config.cycleStyle(w.angleDelta.y > 0 ? 1 : -1)
                        }
                        Connections {
                            target: Config
                            function onStyleIdChanged() { art.requestPaint(); }
                        }
                    }
                }

                Rule {}

                Group {
                    label: I18n.tr("BANDS")
                    Row {
                        spacing: Tokens.s2
                        Step {
                            anchors.verticalCenter: parent.verticalCenter
                            value: Config.bars
                            from: 16
                            to: 128
                            onModified: (v) => Config.setBars(v)
                        }
                        Value {
                            anchors.verticalCenter: parent.verticalCenter
                            text: Config.bars
                        }
                    }
                }

                Rule {}

                Group {
                    label: I18n.tr("MIRROR")
                    dim: !Config.mirrorApplies
                    Sw {
                        on: Config.mirror
                        onToggled: if (Config.mirrorApplies) Config.toggleMirror()
                    }
                }
                Group {
                    label: I18n.tr("PEAKS")
                    dim: !Config.peaksApply
                    Sw {
                        on: Config.peaks
                        onToggled: if (Config.peaksApply) Config.togglePeaks()
                    }
                }

                Rule {}

                Group {
                    label: I18n.tr("GAIN")
                    Row {
                        spacing: Tokens.s2
                        Slid {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 96
                            value: Config.gain
                            from: 0.5
                            to: 2
                            onModified: (v) => Config.setGain(v)
                        }
                        Value {
                            anchors.verticalCenter: parent.verticalCenter
                            text: Math.round(Config.gain * 100) + "%"
                        }
                    }
                }
                Group {
                    label: I18n.tr("SMOOTHING")
                    Row {
                        spacing: Tokens.s2
                        Slid {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 96
                            value: Config.smoothing
                            from: 0
                            to: 1
                            onModified: (v) => Config.setSmoothing(v)
                        }
                        Value {
                            anchors.verticalCenter: parent.verticalCenter
                            text: Math.round(Config.smoothing * 100) + "%"
                        }
                    }
                }

                Rule {}

                Group {
                    label: I18n.tr("ANGLE")
                    Row {
                        spacing: Tokens.s2
                        Value {
                            anchors.verticalCenter: parent.verticalCenter
                            text: Math.round(Config.angle) + "\u00b0"
                        }
                        Btn {
                            anchors.verticalCenter: parent.verticalCenter
                            text: I18n.tr("SQUARE")
                            compact: true
                            armed: Math.round(Config.angle) !== 0
                            onAct: Config.rotate(0)
                        }
                    }
                }

                Group {
                    // One group, two axes: a lean is one idea.
                    label: I18n.tr("LEAN")
                    Row {
                        spacing: Tokens.s2
                        Slid {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 72
                            value: Config.tiltX
                            from: -Config.tiltMax
                            to: Config.tiltMax
                            onModified: (v) => Config.setTiltX(v)
                        }
                        Slid {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 72
                            value: Config.tiltY
                            from: -Config.tiltMax
                            to: Config.tiltMax
                            onModified: (v) => Config.setTiltY(v)
                        }
                        Value {
                            anchors.verticalCenter: parent.verticalCenter
                            text: Math.round(Config.tiltX) + "\u00b0 " + Math.round(Config.tiltY) + "\u00b0"
                        }
                        Btn {
                            anchors.verticalCenter: parent.verticalCenter
                            text: I18n.tr("LEVEL")
                            compact: true
                            armed: Math.round(Config.tiltX) !== 0 || Math.round(Config.tiltY) !== 0
                            onAct: Config.levelTilt()
                        }
                    }
                }
                Group {
                    label: I18n.tr("SIZE")
                    Value {
                        text: Math.round(Config.w * 100) + "\u00d7" + Math.round(Config.h * 100) + "%"
                    }
                }

                Rule {}

                Group {
                    label: ""
                    Row {
                        spacing: Tokens.s2
                        Btn {
                            text: I18n.tr("FLIP")
                            onAct: Config.flip()
                        }
                        Btn {
                            text: I18n.tr("DONE")
                            primary: true
                            onAct: bar.done()
                        }
                    }
                }
            }

            // Under a hairline: an instruction is not a control, and outside the
            // plate it was unreadable over a picture.
            Rectangle {
                width: controls.width
                height: Tokens.border
                color: Tokens.lineSoft
            }
            Text {
                // Phrase by phrase, so each is a translatable unit.
                text: [I18n.tr("drag to move"), I18n.tr("corner to size"),
                       I18n.tr("dot to turn"), I18n.tr("scroll to resize"),
                       "f " + I18n.tr("flip"), "m " + I18n.tr("mirror"),
                       "r " + I18n.tr("square")].join("     ")
                color: Tokens.inkFaint
                font.family: Tokens.ui
                font.pixelSize: Tokens.fMicro
                font.letterSpacing: Tokens.trackLabel
            }
        }
    }

    // The eyebrow says what the control below it is.
    component Group: Column {
        property string label: ""
        property bool dim: false
        spacing: 7
        opacity: dim ? 0.35 : 1
        enabled: !dim
        Behavior on opacity { NumberAnimation { duration: Tokens.snap } }
        Text {
            text: parent.label
            color: Tokens.inkMuted
            font.family: Tokens.ui
            font.pixelSize: Tokens.fTiny
            font.letterSpacing: Tokens.trackMark
            font.weight: Font.Medium
        }
    }
    component Value: Text {
        color: Tokens.ink
        font.family: Tokens.mono
        font.pixelSize: Tokens.fRow
    }
    component Rule: Rectangle {
        anchors.verticalCenter: parent ? parent.verticalCenter : undefined
        width: Tokens.border
        height: 34
        color: Tokens.lineSoft
    }
}
