import QtQuick
import Quickshell
import Quickshell.Io
import Ryoku.Ui.Singletons

// One-click Ryoku update, next to the clock. `ryoku status --json` already lists
// what is incoming as commit subjects, so hovering shows the changes themselves
// instead of a bare "update available", and clicking runs the update in a terminal.
Item {
    id: rootMod
    required property var root
    readonly property color contentColor: root.widgetContentColor("G8", root.seal)

    property bool updateAvailable: false
    property int  pending: 0
    property string channel: ""
    property string installed: ""
    property string latest: ""
    property var commits: []

    readonly property int tooltipCommitLimit: 8

    visible: updateAvailable
    implicitWidth: updateAvailable ? 20 : 0
    implicitHeight: 28

    readonly property string tooltipText: {
        if (!updateAvailable) return I18n.tr("Ryoku is up to date")
        var lines = []
        var head = pending > 0
            ? I18n.tr("Ryoku update") + " · " + pending + (pending === 1
                ? " " + I18n.tr("commit") : " " + I18n.tr("commits"))
            : I18n.tr("Ryoku update")
        if (channel !== "") head += " · " + channel
        lines.push(head)
        if (installed !== "" && latest !== "" && installed !== latest)
            lines.push(installed + " → " + latest)
        var shown = Math.min(commits.length, tooltipCommitLimit)
        if (shown > 0) lines.push("")
        for (var i = 0; i < shown; i++) {
            var c = commits[i]
            var sha = c.new ? String(c.new).slice(0, 7) : ""
            var subject = String(c.name || "").trim()
            lines.push(sha !== "" ? sha + "  " + subject : subject)
        }
        if (commits.length > shown)
            lines.push("+" + (commits.length - shown) + " " + I18n.tr("more"))
        lines.push("")
        lines.push(I18n.tr("Click to update"))
        return lines.join("\n")
    }

    Process {
        id: updateProc
        command: ["bash", "-c", "ryoku status --json 2>/dev/null"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var s = null
                try { s = JSON.parse(this.text || "") } catch (e) { s = null }
                if (!s) {
                    rootMod.updateAvailable = false
                    rootMod.pending = 0
                    rootMod.commits = []
                    return
                }
                rootMod.updateAvailable = s.available === true
                rootMod.pending = Number(s.pendingUpdates) || 0
                rootMod.channel = String(s.channel || "")
                rootMod.installed = String(s.installedVersion || "")
                rootMod.latest = String(s.latestVersion || "")
                rootMod.commits = Array.isArray(s.updates) ? s.updates : []
            }
        }
    }

    Timer {
        interval: 21600000   // 6h
        running: true; repeat: true; triggeredOnStart: true
        onTriggered: { updateProc.running = false; updateProc.running = true }
    }

    // `ryoku update` (and anything else on the ryoku.system-update IPC) bumps this,
    // so the glyph clears as soon as an update finishes instead of waiting out the
    // six-hour poll.
    Connections {
        target: rootMod.root
        function onUpdateRefreshTickChanged() {
            updateProc.running = false
            updateProc.running = true
        }
    }

    Process { id: runProc; command: ["bash", "-c", "kitty ryoku update"] }

    IconText {
        anchors.centerIn: parent
        text: "\uE627"   // sync
        color: rootMod.contentColor
        font.pixelSize: 15
    }

    TooltipMixin { id: tip; root: rootMod.root; owner: rootMod; text: rootMod.tooltipText }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onEntered: tip.show()
        onExited:  tip.hide()
        onClicked: function(mouse) {
            tip.hide()
            if (mouse.button === Qt.RightButton) {
                updateProc.running = false
                updateProc.running = true
                return
            }
            runProc.running = false
            runProc.running = true
        }
    }
}
