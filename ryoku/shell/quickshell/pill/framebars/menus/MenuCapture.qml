pragma ComponentBehavior: Bound

import QtQuick
import "../.." as Pill
import "../../Singletons"

// The frame's capture menu (contract 09): a single left-docked 410-wide surface
// holding the screenshot controls, a divider, then the screen-record controls.
//
// Screenshot is the QUICK path: pick a delay, a save target and a mode, and it
// takes the shot and is done, with no confirmation and no editor (ryoshot stays
// as the separate beautify/annotate app). Modes are All, Monitor, Window and
// Region; each closes the menu and hands off to the Capture controller, which
// owns the grim capture, the clipboard write and the delay rules.
//
// Screen record is the same menu-side shape as the reference (an audio row, the
// capture controls, an in-menu stop) but it drives Ryoku's EXISTING Recorder,
// not a second recording system. Divergence recorded (contract 09): Ryoku does
// NOT adopt the reference wf-recorder encoder arguments, the UTC record-filename
// pattern or the separate recordings directory, because Recorder (gpu-screen-
// recorder with a wf-recorder fallback, the record island, Studio, Discord,
// camera) owns naming and encoding and is more capable. The reference's
// recording-stopped notification bug ("Screenshot saved & copied" for a
// recording) is not reproduced: Recorder already notifies "Screen recording
// stopped". No annotation UI exists here, which is parity: the reference has none.
Item {
    id: root

    property real s: 1
    property bool open: false
    signal requestClose()

    implicitHeight: col.implicitHeight

    // Screenshot options.
    property int delay: 0
    property string save: "both"        // "both" | "clipboard" | "file"
    // Record audio selection, mapped to Recorder's desktop/mic flags.
    property string audioMode: "none"   // "none" | "desktop" | "mic" | "both"

    readonly property real halfW: (col.width - 16) / 2

    readonly property string delayText: root.delay === 1 ? qsTr("1 second") : qsTr("%1 seconds").arg(root.delay)
    readonly property string saveIcon: root.save === "clipboard" ? "content_copy" : root.save === "file" ? "save" : "file_copy"
    readonly property string saveText: root.save === "clipboard" ? qsTr("Save to clipboard")
        : root.save === "file" ? qsTr("Save to file")
        : qsTr("Save to file and clipboard")
    readonly property string audioIcon: root.audioMode === "desktop" ? "volume_up"
        : root.audioMode === "mic" ? "mic"
        : root.audioMode === "both" ? "graphic_eq"
        : "volume_off"
    readonly property string audioText: root.audioMode === "desktop" ? qsTr("Desktop Audio")
        : root.audioMode === "mic" ? qsTr("Microphone")
        : root.audioMode === "both" ? qsTr("Desktop + Microphone")
        : qsTr("No Audio")

    function shoot(mode) {
        root.requestClose();
        Capture.shoot(mode, root.delay, root.save);
    }
    function audioArgs() {
        var a = [];
        if (root.audioMode === "desktop" || root.audioMode === "both")
            a.push("--with-desktop-audio");
        if (root.audioMode === "mic" || root.audioMode === "both")
            a.push("--with-microphone-audio");
        return a;
    }
    function startRecord(region) {
        var audio = root.audioArgs();
        if (region) {
            root.requestClose();
            Capture.recordRegion(audio);
        } else {
            Recorder.start(["--fullscreen"].concat(audio));
            root.requestClose();
        }
    }

    // A revealer row whose card is a selectable option list; picking an option
    // updates the caller's value and collapses the card (contract 09 sec 4d).
    component OptionRow: RevealerRow {
        id: orow
        property var options: []        // [{ v, l, icon }]
        property var current: null
        property string headerLabel: ""
        signal picked(var value)

        width: col.width
        actionSensitive: false
        middle: RevealerRowLabel { anchors.fill: parent; label: orow.headerLabel }

        Column {
            width: parent.width
            spacing: Theme.paddingMd
            Repeater {
                model: orow.options
                delegate: MenuButton {
                    id: opt
                    required property var modelData
                    width: parent.width
                    minH: optLbl.implicitHeight + opt.pad * 2
                    selected: orow.current === opt.modelData.v
                    onClicked: {
                        orow.picked(opt.modelData.v);
                        orow.revealed = false;
                    }
                    RevealerIconLabel {
                        id: optLbl
                        anchors.fill: parent
                        iconName: opt.modelData.icon
                        iconColor: opt.contentColor
                        label: opt.modelData.l
                    }
                }
            }
        }
    }

    Column {
        id: col
        width: root.width
        spacing: Theme.paddingMd

        // ---- Screenshot -----------------------------------------------------
        Text {
            text: qsTr("Screenshot")
            color: Theme.onSurface
            font.family: Theme.fontPrimary
            font.pixelSize: Theme.fontLg
            font.weight: Font.Bold
        }

        OptionRow {
            actionIconName: "timer"
            headerLabel: qsTr("Delay: %1").arg(root.delayText)
            current: root.delay
            options: [
                { v: 0, l: qsTr("0 seconds"), icon: "timer" },
                { v: 1, l: qsTr("1 second"), icon: "timer" },
                { v: 3, l: qsTr("3 seconds"), icon: "timer" },
                { v: 5, l: qsTr("5 seconds"), icon: "timer" },
                { v: 10, l: qsTr("10 seconds"), icon: "timer" }
            ]
            onPicked: value => root.delay = value
        }

        OptionRow {
            actionIconName: root.saveIcon
            headerLabel: root.saveText
            current: root.save
            options: [
                { v: "both", l: qsTr("Save to file and clipboard"), icon: "file_copy" },
                { v: "clipboard", l: qsTr("Save to clipboard"), icon: "content_copy" },
                { v: "file", l: qsTr("Save to file"), icon: "save" }
            ]
            onPicked: value => root.save = value
        }

        Grid {
            width: col.width
            columns: 2
            rowSpacing: 16
            columnSpacing: 16
            MenuBigButton { width: root.halfW; iconName: "select_all"; label: qsTr("All"); onClicked: root.shoot("all") }
            MenuBigButton { width: root.halfW; iconName: "desktop_windows"; label: qsTr("Monitor"); onClicked: root.shoot("monitor") }
            MenuBigButton { width: root.halfW; iconName: "web_asset"; label: qsTr("Window"); onClicked: root.shoot("window") }
            MenuBigButton { width: root.halfW; iconName: "crop"; label: qsTr("Region"); onClicked: root.shoot("region") }
        }

        // ---- divider --------------------------------------------------------
        MenuDivider { width: col.width; scale: root.s }

        // ---- Screen Record --------------------------------------------------
        Text {
            text: qsTr("Screen Record")
            color: Theme.onSurface
            font.family: Theme.fontPrimary
            font.pixelSize: Theme.fontLg
            font.weight: Font.Bold
        }

        OptionRow {
            actionIconName: root.audioIcon
            headerLabel: root.audioText
            current: root.audioMode
            options: [
                { v: "none", l: qsTr("No Audio"), icon: "volume_off" },
                { v: "desktop", l: qsTr("Desktop Audio"), icon: "volume_up" },
                { v: "mic", l: qsTr("Microphone"), icon: "mic" },
                { v: "both", l: qsTr("Desktop + Microphone"), icon: "graphic_eq" }
            ]
            onPicked: value => root.audioMode = value
        }

        Grid {
            width: col.width
            columns: 2
            columnSpacing: 16
            // The capture controls are disabled while any recording is live, so a
            // second recording can never be started over the first.
            MenuBigButton { width: root.halfW; iconName: "fullscreen"; label: qsTr("Screen"); enabled: !Recorder.anyActive; onClicked: root.startRecord(false) }
            MenuBigButton { width: root.halfW; iconName: "crop"; label: qsTr("Region"); enabled: !Recorder.anyActive; onClicked: root.startRecord(true) }
        }

        // In-menu recording indicator + stop (contract 09 sec 2b): shown only
        // while a recording is live, mirroring the bar RecordingIndicator; the
        // stop drives the existing Recorder (Studio has its own shutdown).
        Rectangle {
            width: col.width
            visible: Recorder.anyActive
            height: indCol.implicitHeight + Theme.paddingLg * 2
            radius: Theme.radiusWidget
            color: "transparent"
            border.width: Theme.borderWidth
            border.color: Theme.outline

            Column {
                id: indCol
                x: Theme.paddingLg
                y: Theme.paddingLg
                width: parent.width - Theme.paddingLg * 2
                spacing: Theme.paddingMd

                Row {
                    width: parent.width
                    spacing: Theme.paddingMd
                    Pill.MaterialIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Theme.iconSm
                        height: Theme.iconSm
                        font.pixelSize: Theme.iconSm
                        text: "fiber_manual_record"
                        color: Theme.error
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: qsTr("Recording screen\u2026")
                        color: Theme.onSurface
                        font.family: Theme.fontPrimary
                        font.pixelSize: Theme.fontMd
                        font.weight: Font.Bold
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Recorder.elapsedText
                        color: Theme.onSurfaceVariant
                        font.family: Theme.fontPrimary
                        font.pixelSize: Theme.fontSm
                    }
                }

                MenuButton {
                    id: stopBtn
                    selected: true
                    minW: 96
                    minH: stopTxt.implicitHeight + stopBtn.pad * 2
                    onClicked: Recorder.studioActive ? Recorder.stopStudio() : Recorder.stop()
                    Text {
                        id: stopTxt
                        anchors.centerIn: parent
                        text: qsTr("Stop")
                        color: stopBtn.contentColor
                        font.family: Theme.fontPrimary
                        font.pixelSize: Theme.fontMd
                    }
                }
            }
        }
    }
}
