pragma ComponentBehavior: Bound

import QtQuick
import "../.." as Pill
import "../../Singletons"

// Audio output entry (contract 06 sec 2.8): a RevealerRow whose action button
// mutes the default sink and whose middle is an inline, un-debounced volume
// slider; the reveal opens the service-ordered output device list, each row
// selecting a default and marking the current one with a check. Volume/mute
// come live from the default Pipewire sink; the device list from Audio.outputs.
Item {
    id: root

    property real s: 1
    property bool open: false

    implicitHeight: row.implicitHeight

    readonly property var sink: Audio.sink
    readonly property real vol: root.sink && root.sink.audio ? root.sink.audio.volume : 0
    readonly property bool muted: root.sink && root.sink.audio ? root.sink.audio.muted : false

    function muteIcon() {
        if (!root.sink || root.muted)
            return "volume_off";
        const p = root.vol * 100;
        return p > 66 ? "volume_up" : p > 33 ? "volume_down" : p > 0 ? "volume_mute" : "volume_off";
    }

    RevealerRow {
        id: row
        width: root.width
        actionIconName: root.muteIcon()
        actionSensitive: true
        onActionClicked: if (root.sink && root.sink.audio) root.sink.audio.muted = !root.sink.audio.muted

        middle: RevealerRowSlider {
            anchors.fill: parent
            value: root.vol
            onMoved: v => { if (root.sink && root.sink.audio) root.sink.audio.volume = v; }
        }

        Column {
            width: parent.width
            spacing: 0

            Repeater {
                model: root.open ? Audio.outputs : []
                delegate: MenuButton {
                    id: drow
                    required property var modelData
                    readonly property bool isDefault: root.sink && drow.modelData && drow.modelData.name === root.sink.name
                    width: parent.width
                    minH: dlabel.implicitHeight + drow.pad * 2
                    onClicked: Audio.setOutput(drow.modelData)
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
