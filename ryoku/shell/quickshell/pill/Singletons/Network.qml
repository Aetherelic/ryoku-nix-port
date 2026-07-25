pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../framebars/lib/providers.js" as Providers
import "../framebars/lib/menupoll.js" as MenuPoll

// Lightweight network presence for the rail's display-only status.
// kind (ethernet/wifi/none), Wi-Fi signal and radio state. It polls gently
// without scanning or exposing connection controls.
Singleton {
    id: root

    // "ethernet" | "wifi" | "" (offline / no nmcli)
    property string kind: ""
    // 0..1 wifi signal, meaningful while kind === "wifi"
    property real level: 0
    property bool wifiRadio: true
    property bool vpnActive: false
    property string vpnName: ""
    property bool vpnPolling: false
    property var vpnPollOwners: []

    onVpnPollingChanged: {
        if (vpnPolling) vpnProc.running = true;
        else {
            vpnProc.running = false;
            vpnActive = false;
            vpnName = "";
        }
    }

    function setVpnPolling(owner, enabled) {
        vpnPollOwners = MenuPoll.setOwnership(vpnPollOwners, owner, enabled);
        vpnPolling = vpnPollOwners.length > 0;
        if (vpnPolling) refresh();
    }


    function refresh() {
        stateProc.running = true;
    }

    Process {
        id: stateProc
        running: true
        command: ["sh", "-c",
            "nmcli -t -f TYPE,STATE d 2>/dev/null | grep ':connected$' | cut -d: -f1; " +
            "echo --; nmcli -t -f ACTIVE,SIGNAL dev wifi list --rescan no 2>/dev/null | grep '^yes' | cut -d: -f2 | head -1; " +
            "echo --; nmcli radio wifi 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                var parts = this.text.split("--");
                var types = (parts[0] || "").trim().split("\n").filter(function(t) { return t.length > 0; });
                var eth = types.indexOf("ethernet") >= 0;
                var wifi = types.indexOf("wifi") >= 0;
                root.kind = eth ? "ethernet" : (wifi ? "wifi" : "");
                var sig = parseInt((parts[1] || "").trim(), 10);
                root.level = isNaN(sig) ? 0 : Math.max(0, Math.min(1, sig / 100));
                root.wifiRadio = (parts[2] || "").indexOf("enabled") >= 0;
            }
        }
    }

    Process {
        id: vpnProc
        command: ["sh", "-c", "nmcli -t -f TYPE,NAME connection show --active 2>/dev/null | sed -n 's/^vpn:/vpn:connected:/p'"]
        stdout: StdioCollector {
            onStreamFinished: {
                const vpn = Providers.parseVpn(this.text);
                root.vpnActive = vpn.active;
                root.vpnName = vpn.name;
            }
        }
    }

    Timer {
        interval: 30000
        repeat: true
        running: root.vpnPolling
        onTriggered: vpnProc.running = true
    }

    Timer {
        interval: 30000
        repeat: true
        running: true
        onTriggered: root.refresh()
    }
}
