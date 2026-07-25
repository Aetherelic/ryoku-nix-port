import QtQuick
import Quickshell
import Quickshell.Io
import "../lib/providers.js" as Providers
import "../.." as Pill
import "../../Singletons"

Item {
    id: root

    required property string edge
    required property real scale
    required property bool active
    readonly property var supportedLayouts: ["dwindle", "master", "scrolling", "monocle"]
    property var layouts: supportedLayouts
    property string current: ""
    signal menuRequested(string id, rect ownerRect)

    implicitWidth: 30 * scale
    implicitHeight: 30 * scale

    function refresh() {
        if (active) layoutProc.running = true;
    }

    function choose(layout) {
        if (!active || !supportedLayouts.includes(layout)) return;
        Quickshell.execDetached(["hyprctl", "eval", 'hl.config({ general = { layout = "' + layout + '" } })']);
        current = layout;
    }

    onActiveChanged: {
        if (active) refresh();
        else layoutProc.running = false;
    }
    Component.onCompleted: refresh()

    Process {
        id: layoutProc
        command: ["sh", "-c", "hyprctl -j activeworkspace 2>/dev/null | jq -r '.tiledLayout // .layout // empty'"]
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

    Pill.MaterialIcon {
        anchors.centerIn: parent
        text: "dashboard_customize"
        color: Theme.cream
        font.pixelSize: 18 * root.scale
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.menuRequested("layout-switcher", Qt.rect(0, 0, root.width, root.height))
    }
}
