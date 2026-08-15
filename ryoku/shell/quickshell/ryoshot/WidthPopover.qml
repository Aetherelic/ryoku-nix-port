import QtQuick
import QtQuick.Layouts
import "Singletons"

Item {
    id: pop

    /** Externally driven current stroke width in the 1..20 range. */
    property int selected: 4

    /** Emitted on a preset tap or a stepper change. */
    signal picked(int w)

    signal closeRequested()

    focus: visible
    Keys.onEscapePressed: pop.closeRequested()

    readonly property int arrow: 7
    implicitWidth: card.implicitWidth
    implicitHeight: card.implicitHeight + arrow

    readonly property var presets: [
        { width: 2, dot: 5 },
        { width: 4, dot: 9 },
        { width: 7, dot: 13 }
    ]

    /** Clamps to 1..20 and emits only when the value actually moves. */
    function apply(w) {
        var c = Math.max(1, Math.min(20, Math.round(w)));
        if (c !== pop.selected) pop.picked(c);
    }

    opacity: 0
    scale: 0.92
    transformOrigin: Item.Top
    Component.onCompleted: appear.start()
    ParallelAnimation {
        id: appear
        NumberAnimation { target: pop; property: "opacity"; from: 0; to: 1; duration: Theme.snap; easing.type: Easing.OutCubic }
        NumberAnimation { target: pop; property: "scale"; from: 0.92; to: 1; duration: Theme.snap; easing.type: Easing.OutCubic }
    }

    Rectangle {
        id: card
        width: parent.width
        height: parent.height - pop.arrow
        radius: Theme.radius
        color: Theme.panel
        border.color: Theme.hair
        border.width: 1
        implicitWidth: content.implicitWidth + 24
        implicitHeight: content.implicitHeight + 20

        ColumnLayout {
            id: content
            anchors.centerIn: parent
            spacing: 10

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 4
                Repeater {
                    model: pop.presets
                    Rectangle {
                        id: cell
                        required property var modelData
                        Layout.preferredWidth: 30
                        Layout.preferredHeight: 30
                        radius: 6
                        readonly property bool sel: pop.selected === modelData.width
                        color: sel ? Qt.rgba(1, 1, 1, 0.08)
                            : (cellHover.hovered ? Qt.rgba(1, 1, 1, 0.04) : Qt.rgba(0, 0, 0, 0))
                        border.color: sel ? Theme.accent : Qt.rgba(0, 0, 0, 0)
                        border.width: 1

                        Rectangle {
                            anchors.centerIn: parent
                            width: cell.modelData.dot
                            height: cell.modelData.dot
                            radius: width / 2
                            color: cell.sel ? Theme.accent : Theme.ink
                        }

                        HoverHandler { id: cellHover }
                        TapHandler { onTapped: pop.apply(cell.modelData.width) }
                    }
                }
            }

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 8

                Rectangle {
                    id: minus
                    Layout.preferredWidth: 26
                    Layout.preferredHeight: 26
                    radius: 6
                    color: minusHover.hovered ? Qt.rgba(1, 1, 1, 0.06) : Qt.rgba(0, 0, 0, 0)
                    border.color: Theme.hair
                    border.width: 1
                    Text {
                        anchors.centerIn: parent
                        text: "\u2212"
                        color: Theme.ink
                        font.family: Theme.mono
                        font.pixelSize: 16
                    }
                    HoverHandler { id: minusHover }
                    TapHandler { onTapped: pop.apply(pop.selected - 1) }
                }

                Text {
                    Layout.preferredWidth: 28
                    horizontalAlignment: Text.AlignHCenter
                    text: pop.selected
                    color: Theme.ink
                    font.family: Theme.mono
                    font.pixelSize: 14
                }

                Rectangle {
                    id: plus
                    Layout.preferredWidth: 26
                    Layout.preferredHeight: 26
                    radius: 6
                    color: plusHover.hovered ? Qt.rgba(1, 1, 1, 0.06) : Qt.rgba(0, 0, 0, 0)
                    border.color: Theme.hair
                    border.width: 1
                    Text {
                        anchors.centerIn: parent
                        text: "+"
                        color: Theme.ink
                        font.family: Theme.mono
                        font.pixelSize: 16
                    }
                    HoverHandler { id: plusHover }
                    TapHandler { onTapped: pop.apply(pop.selected + 1) }
                }
            }
        }
    }

    Canvas {
        width: pop.arrow * 2
        height: pop.arrow
        anchors.bottom: card.top
        anchors.horizontalCenter: card.horizontalCenter
        onPaint: {
            var ctx = getContext("2d");
            ctx.reset();
            ctx.beginPath();
            ctx.moveTo(0, height);
            ctx.lineTo(width, height);
            ctx.lineTo(width / 2, 0);
            ctx.closePath();
            ctx.fillStyle = Theme.panel;
            ctx.fill();
        }
    }
}
