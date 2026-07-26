pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Bluetooth
import "../../Singletons"

// One renderer parameterised by statusId, exactly as the reference treats each
// status widget as its own type. Box-shape indicators (battery/network/bluetooth)
// carry no click; button-shape widgets (audio-output/audio-input/notifications)
// click, and the two audio widgets take a hover-gated vertical wheel. Icon rules
// and self-hide are the reference literals (contract 04 sec 3.2).
Item {
    id: root

    required property string edge
    required property real scale
    required property string statusId
    signal menuRequested(string id, rect ownerRect)

    readonly property bool box: statusId === "battery" || statusId === "network" || statusId === "bluetooth"
    readonly property bool audioOut: statusId === "audio-output"
    readonly property bool audioIn: statusId === "audio-input"

    // battery self-hides when no battery device is present; everything else is
    // always visible (contract 04 sec 3.2). selfShown is private, so an ancestor
    // collapsing the bar (which pulls `visible` to false) cannot zero the size.
    readonly property bool selfShown: statusId !== "battery" || Battery.present
    visible: selfShown
    implicitWidth: selfShown ? btn.implicitWidth : 0
    implicitHeight: selfShown ? btn.implicitHeight : 0

    // --- icon rules (contract 04 sec 3.2), literal thresholds ----------------

    // audio: muted wins, then >66 high, >33 medium, >0 low, ==0 muted.
    function audioOutGlyph(pct, muted) {
        if (muted)
            return "volume_off";
        return pct > 66 ? "volume_up" : pct > 33 ? "volume_down" : pct > 0 ? "volume_mute" : "volume_off";
    }
    // Material Symbols carries no microphone-sensitivity levels, so the level
    // thresholds collapse to the muted boundary (muted or zero -> mic_off).
    function audioInGlyph(pct, muted) {
        return (muted || pct <= 0) ? "mic_off" : "mic";
    }
    // battery: buckets of ten, with a charging variant.
    function batteryGlyph(pct, charging) {
        const b = pct > 99 ? 100 : pct > 90 ? 90 : pct > 80 ? 80 : pct > 70 ? 70
            : pct > 60 ? 60 : pct > 50 ? 50 : pct > 40 ? 40 : pct > 30 ? 30
            : pct > 20 ? 20 : pct > 10 ? 10 : 0;
        if (charging)
            return b >= 100 ? "battery_charging_full" : b >= 90 ? "battery_charging_90"
                : b >= 80 ? "battery_charging_80" : b >= 60 ? "battery_charging_60"
                : b >= 50 ? "battery_charging_50" : b >= 30 ? "battery_charging_30"
                : "battery_charging_20";
        return b >= 100 ? "battery_full" : b >= 90 ? "battery_6_bar" : b >= 70 ? "battery_5_bar"
            : b >= 50 ? "battery_4_bar" : b >= 40 ? "battery_3_bar" : b >= 20 ? "battery_2_bar"
            : b >= 10 ? "battery_1_bar" : "battery_0_bar";
    }
    // wifi strength: >75 excellent, >50 good, >25 ok, >0 weak, else none.
    function networkGlyph() {
        if (Network.kind === "ethernet")
            return "lan";
        if (Network.kind === "wifi") {
            const s = Network.level * 100;
            return s > 75 ? "signal_wifi_4_bar" : s > 50 ? "network_wifi_3_bar"
                : s > 25 ? "network_wifi_2_bar" : s > 0 ? "network_wifi_1_bar" : "signal_wifi_0_bar";
        }
        return Network.wifiRadio ? "signal_wifi_off" : "wifi_off";
    }
    function bluetoothGlyph() {
        const a = Bluetooth.defaultAdapter;
        if (!a)
            return "bluetooth_disabled";
        return a.enabled ? "bluetooth" : "bluetooth_disabled";
    }

    readonly property bool hasNotifs: Notifs.tracked.length > 0
    readonly property string glyph: {
        if (statusId === "battery")
            return batteryGlyph(Battery.pct, Battery.charging);
        if (statusId === "network")
            return networkGlyph();
        if (statusId === "bluetooth")
            return bluetoothGlyph();
        if (statusId === "audio-output")
            return audioOutGlyph(Audio.sink && Audio.sink.audio ? Math.round(Audio.sink.audio.volume * 100) : 0,
                Audio.sink && Audio.sink.audio ? Audio.sink.audio.muted : false);
        if (statusId === "audio-input")
            return audioInGlyph(Audio.source && Audio.source.audio ? Math.round(Audio.source.audio.volume * 100) : 0,
                Audio.source && Audio.source.audio ? Audio.source.audio.muted : false);
        return hasNotifs ? "notifications_active" : "notifications";
    }

    // --- interaction (contract 04 sec 3.2, sec 4) ----------------------------

    function primary() {
        if (audioOut) {
            Quickshell.execDetached(["ryoku-shell", "audio", "mute"]);
        } else if (audioIn) {
            if (Audio.source && Audio.source.audio)
                Audio.source.audio.muted = !Audio.source.audio.muted;
        } else if (statusId === "notifications") {
            root.menuRequested("notifications", Qt.rect(0, 0, root.width, root.height));
        }
    }

    // step +-0.05 clamped [0,1]; wheel up increases. Output routes through the
    // daemon so the OSD + feedback sound fire (reference plays a sound on output
    // only); input is a silent direct set on the source.
    function scrollBy(steps) {
        if (audioOut) {
            Quickshell.execDetached(["ryoku-shell", "audio", steps > 0 ? "up" : "down"]);
        } else if (audioIn && Audio.source && Audio.source.audio) {
            const v = Audio.source.audio.volume + (steps > 0 ? 0.05 : -0.05);
            Audio.source.audio.volume = Math.max(0, Math.min(1, v));
        }
    }

    RailButton {
        id: btn
        anchors.centerIn: parent
        edge: root.edge
        scale: root.scale
        icon: root.glyph
        iconFill: root.statusId === "notifications" && root.hasNotifs ? 1 : 0
        interactive: !root.box
        scrollable: root.audioOut || root.audioIn
        onClicked: root.primary()
        onScrolled: steps => root.scrollBy(steps)
    }
}
