import QtQuick
import Quickshell
import Quickshell.Wayland
import Ryoku.Blobs
import "modules/bar" as Bar

// Host half: the real plugin-popout host and frame menu manager, fed a fixture
// plugin placed at edge "center". The popout must come out centred with no hover
// band, the manager must carry its body rect in `pluginMask` (a centred body has
// no edge anchor to ride, so without it the modal clicks through), and a
// built-in centre surface (quick settings, Super+Escape) must take the screen
// from it rather than overlap it: that single-open handover is why a centred
// placement needs no "reserved" ban in the Hub editor.
ShellRoot {
    PanelWindow {
        anchors { top: true; bottom: true; left: true; right: true }
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay

        BlobGroup { id: probeGroup }

        Bar.PluginPopouts {
            id: host
            group: probeGroup
            frameThickness: 16
            pinnedId: "fixture"
        }

        Bar.FrameMenuManager {
            id: manager
            anchors.fill: parent
            monitorName: "probe"
            scale: 1
            group: probeGroup
            railClearances: ({ top: 0, bottom: 0, left: 0, right: 0 })
            Component.onCompleted: manager.openPlugin("fixture")
        }

        Timer {
            interval: 1600
            running: true
            onTriggered: {
                const pop = host.first;
                if (!pop)
                    throw new Error("CENTER-POPOUT-HOST-FAIL fixture popout never loaded");
                if (!pop.centered)
                    throw new Error("CENTER-POPOUT-HOST-FAIL edge \"center\" did not centre the popout");
                if (pop.hoverOpen || pop.triggerW !== 0 || pop.triggerH !== 0)
                    throw new Error("CENTER-POPOUT-HOST-FAIL centred popout kept a hover band");
                if (Math.abs(pop.maskX - (host.width - pop.openW) / 2) > 0.5
                    || Math.abs(pop.maskY - (host.height - pop.openH) / 2) > 0.5)
                    throw new Error("CENTER-POPOUT-HOST-FAIL mask off centre: " + pop.maskX + "," + pop.maskY);
                if (manager.pluginMask.w <= 0 || manager.pluginMask.h <= 0)
                    throw new Error("CENTER-POPOUT-HOST-FAIL pluginMask empty; the centred body would click through");
                if (manager.activeIdAt("top") !== "plugin:fixture")
                    throw new Error("CENTER-POPOUT-HOST-FAIL plugin surface not open: " + manager.activeIdAt("top"));

                manager.openSurface("quick-settings", undefined, "probe", undefined);
                if (manager.activeIdAt("top") === "plugin:fixture")
                    throw new Error("CENTER-POPOUT-HOST-FAIL quick settings did not displace the centred popout");
                if (manager.pluginMask.w > 0)
                    throw new Error("CENTER-POPOUT-HOST-FAIL centred mask survived the handover");

                console.log("CENTER-POPOUT-HOST-PASS");
                Qt.quit();
            }
        }
    }
}
