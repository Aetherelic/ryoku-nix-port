pragma ComponentBehavior: Bound

import QtQuick
import "../.." as Pill
import "../../Singletons"

// Audio input entry (contract 06 sec 2.8): structurally identical to the output
// entry, differing only in the microphone icon family and the source
// accessors. The action button mutes the default source, the middle is an
// un-debounced volume slider, and the reveal lists the input devices in service
// order with a check on the current default.
Item {
    id: root

    property real s: 1
    property bool open: false

    implicitHeight: row.implicitHeight

    // Detail-page mode: hosted as a sidebar page, the device list arrives open.
    property bool pageMode: false
    onOpenChanged: if (root.open && root.pageMode) row.revealed = true

    readonly property var source: Audio.source
    readonly property real vol: root.source && root.source.audio ? root.source.audio.volume : 0
    readonly property bool muted: root.source && root.source.audio ? root.source.audio.muted : false

    RevealerRow {
        id: row
        width: root.width
        actionIconName: (!root.source || root.muted) ? "mic_off" : "mic"
        actionSensitive: true
        onActionClicked: if (root.source && root.source.audio) root.source.audio.muted = !root.source.audio.muted

        middle: RevealerRowSlider {
            anchors.fill: parent
            value: root.vol
            onMoved: v => { if (root.source && root.source.audio) root.source.audio.volume = v; }
        }

        Column {
            width: parent.width
            spacing: 0

            Repeater {
                model: root.open ? Audio.inputs : []
                delegate: MenuButton {
                    id: drow
                    required property var modelData
                    readonly property bool isDefault: root.source && drow.modelData && drow.modelData.name === root.source.name
                    width: parent.width
                    minH: dlabel.implicitHeight + drow.pad * 2
                    onClicked: Audio.setInput(drow.modelData)
                    RevealerIconLabel {
                        id: dlabel
                        anchors.fill: parent
                        iconName: drow.isDefault ? "check_circle" : ""
                        label: Audio.nodeLabel(drow.modelData)
                    }
                }
            }
        }
    }
}
