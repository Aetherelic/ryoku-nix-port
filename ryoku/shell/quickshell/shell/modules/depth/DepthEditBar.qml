pragma ComponentBehavior: Bound
import QtQuick
import Ryoku.Ui
import Ryoku.Ui.Singletons
import "Singletons"

// The depth composing bar, shown while depth is being placed (docs/depth.md).
// The cutout is locked to the wallpaper, so there is nothing to move or resize -
// the user drags the clock into the subject's negative space with the ordinary
// widget drag, seeing the overlap live, and this bar carries only the honest
// knobs: edge feather, foreground strength, whether the clock sits in front, a
// regenerate, and done. Fixed to the bottom edge so a readout never moves with
// the thing being placed, matching the spectrum's EditBar.
Item {
    id: bar
    signal done

    anchors.fill: parent

    Rectangle {
        id: plate
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Tokens.s7
        width: row.implicitWidth + Tokens.s5 * 2
        height: row.implicitHeight + Tokens.s4 * 2
        radius: Tokens.radius
        color: Qt.alpha(Tokens.paper, 0.94)
        border.width: Tokens.border
        border.color: Tokens.line

        Row {
            id: row
            anchors.centerIn: parent
            spacing: Tokens.s5

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: I18n.tr("DEPTH")
                color: Tokens.ink
                font.family: Tokens.mono
                font.pixelSize: Tokens.fMicro
            }

            Column {
                spacing: Tokens.s1
                Text {
                    text: I18n.tr("FEATHER")
                    color: Tokens.inkMuted
                    font.family: Tokens.mono
                    font.pixelSize: Tokens.fTiny
                }
                Slid {
                    width: 120
                    value: Config.feather
                    from: 0
                    to: 1
                    onModified: v => Config.setFeather(v)
                }
            }

            Column {
                spacing: Tokens.s1
                Text {
                    text: I18n.tr("FOREGROUND")
                    color: Tokens.inkMuted
                    font.family: Tokens.mono
                    font.pixelSize: Tokens.fTiny
                }
                Slid {
                    width: 120
                    value: Config.lift
                    from: 0.2
                    to: 1
                    onModified: v => Config.setLift(v)
                }
            }

            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: Tokens.s2
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: I18n.tr("CLOCK IN FRONT")
                    color: Tokens.inkMuted
                    font.family: Tokens.mono
                    font.pixelSize: Tokens.fTiny
                }
                Sw {
                    anchors.verticalCenter: parent.verticalCenter
                    on: Config.isFront("clock")
                    onToggled: Config.toggleFront("clock")
                }
            }

            Btn {
                anchors.verticalCenter: parent.verticalCenter
                text: I18n.tr("REGENERATE")
                onAct: Config.refresh()
            }
            Btn {
                anchors.verticalCenter: parent.verticalCenter
                text: I18n.tr("DONE")
                onAct: bar.done()
            }
        }
    }
}
