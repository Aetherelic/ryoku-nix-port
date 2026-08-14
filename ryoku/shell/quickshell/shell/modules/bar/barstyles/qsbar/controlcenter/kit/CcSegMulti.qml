import QtQuick
import "../../modules"

// A segmented choice where any number of options can be on at once, for a
// setting that is a set rather than a pick. Same silhouette as CcSeg - one
// rounded outer border with clipped one-pixel internal separators - so the two
// read as the same control family. `selected` is the list of keys that are on.
Rectangle {
    id: seg

    property var root
    property var options: []
    property var selected: []
    property int controlHeight: 28

    signal toggled(string key)

    implicitWidth: row.implicitWidth
    implicitHeight: seg.controlHeight
    width: implicitWidth
    height: implicitHeight
    radius: seg.root ? seg.root.tileRadius : 6
    color: seg.root ? seg.root.fillIdle : "transparent"
    border.width: 1
    border.color: seg.root ? seg.root.sep : "transparent"
    clip: true

    Row {
        id: row
        height: seg.height

        Repeater {
            model: seg.options

            delegate: Row {
                id: cell
                required property var modelData
                required property int index
                readonly property string key: (typeof modelData === "string") ? modelData : modelData.key
                readonly property string lbl: (typeof modelData === "string")
                    ? modelData : (modelData.label || modelData.key)
                readonly property bool on: (seg.selected || []).indexOf(cell.key) >= 0

                height: seg.height

                Rectangle {
                    visible: cell.index > 0
                    width: 1
                    height: seg.height
                    color: seg.root ? seg.root.sep : "transparent"
                }

                Rectangle {
                    height: seg.height
                    width: Math.max(46, lblText.implicitWidth + 20)
                    color: !seg.root ? "transparent"
                        : cell.on
                            ? Qt.rgba(seg.root.seal.r, seg.root.seal.g, seg.root.seal.b, 0.16)
                            : (ma.containsMouse
                                ? Qt.rgba(seg.root.ink.r, seg.root.ink.g, seg.root.ink.b, 0.06)
                                : "transparent")
                    Behavior on color { ColorAnimation { duration: 120 } }

                    UiText {
                        id: lblText
                        anchors.centerIn: parent
                        text: cell.lbl
                        color: !seg.root ? "#888888" : (cell.on ? seg.root.seal : seg.root.ink)
                        font.family: seg.root ? seg.root.mono : "monospace"
                        font.pixelSize: 12
                        font.weight: cell.on ? Font.DemiBold : Font.Normal
                        Behavior on color { ColorAnimation { duration: 120 } }
                    }
                    MouseArea {
                        id: ma
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: seg.toggled(cell.key)
                    }
                }
            }
        }
    }
}
