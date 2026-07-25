import QtQuick
import Quickshell
import Quickshell.Io
import "../lib/providers.js" as Providers

Item {
    id: root

    property bool active: false
    readonly property var layouts: Providers.layouts
    property string current: ""
    property var processCommand: ["sh", "-c", "hyprctl -j activeworkspace 2>/dev/null | jq -r '.tiledLayout // .layout // empty'"]
    signal stopped()

    onActiveChanged: {
        if (active) refresh()
        else stop()
    }
    Component.onCompleted: refresh()
    Component.onDestruction: stop()

    function refresh() {
        if (active)
            layoutProc.running = true
    }

    function choose(layout) {
        if (!active || !layouts.includes(layout))
            return
        Quickshell.execDetached(["hyprctl", "eval", 'hl.config({ general = { layout = "' + layout + '" } })'])
        current = layout
    }

    function stop() {
        if (layoutProc.running) {
            layoutProc.running = false
            stopped()
        }
    }

    Process {
        id: layoutProc
        command: root.processCommand
        stdout: StdioCollector {
            onStreamFinished: root.current = Providers.parseLayouts(this.text)[0] || ""
        }
    }

    Timer {
        interval: 30000
        repeat: true
        running: root.active
        onTriggered: root.refresh()
    }
}
