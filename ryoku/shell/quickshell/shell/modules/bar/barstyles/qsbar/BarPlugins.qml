pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

// Discovery for store-installed plugins that chose the bar as their host
// (`topbarGlyph`). Publishes the enabled set so BarSlot can render one glyph
// slot per plugin. Discovery is the shared discover.sh, so enabled state and
// per-plugin settings come from the same plugins.json the other hosts read.
Item {
    id: root

    property var plugins: []
    property var pluginIds: []

    readonly property string _shellDir: Quickshell.env("RYOKU_SHELL_DIR")
    readonly property string _script: (_shellDir && _shellDir.length > 0)
        ? _shellDir + "/quickshell/plugins/discover.sh"
        : (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config"))
            + "/quickshell/plugins/discover.sh"
    readonly property string _stateHome: Quickshell.env("XDG_STATE_HOME")
        || (Quickshell.env("HOME") + "/.local/state")

    width: 0
    height: 0

    function reload() {
        discoverProc.running = false
        discoverProc.running = true
    }

    function entryFor(id) {
        for (var i = 0; i < root.plugins.length; i++)
            if (root.plugins[i].id === id) return root.plugins[i]
        return null
    }

    function syncPlugins(all) {
        var next = []
        for (var i = 0; i < all.length; i++) {
            var p = all[i]
            if (p && p.placement && p.placement.host === "topbarGlyph") next.push(p)
        }
        root.plugins = next
        var ids = []
        for (var k = 0; k < next.length; k++) ids.push(next[k].id)
        var same = ids.length === root.pluginIds.length
        if (same) {
            for (var j = 0; j < ids.length; j++)
                if (ids[j] !== root.pluginIds[j]) { same = false; break }
        }
        if (!same) root.pluginIds = ids
    }

    Process {
        id: discoverProc
        command: ["bash", root._script]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                var all = []
                try { all = JSON.parse(this.text || "[]") } catch (e) { all = [] }
                root.syncPlugins(all)
            }
        }
    }

    FileView {
        path: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config"))
            + "/ryoku/plugins.json"
        watchChanges: true
        printErrors: false
        onFileChanged: root.reload()
    }

    // A store install/remove bumps the revision; re-scan so a freshly installed
    // bar plugin appears without a shell restart.
    FileView {
        path: root._stateHome + "/ryoku/store/revision.json"
        watchChanges: true
        atomicWrites: true
        printErrors: false
        onFileChanged: root.reload()
    }
}
