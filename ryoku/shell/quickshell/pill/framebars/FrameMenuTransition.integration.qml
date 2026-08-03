import QtQuick
import Quickshell
import Ryoku.Blobs
import "Singletons"

ShellRoot {
    id: root

    BlobGroup { id: group }
    property bool crossAnchorStarted: false

    FrameMenuManager {
        id: manager
        width: 1200
        height: 800
        monitorName: "eDP-1"
        scale: 1
        group: root.group
        railClearances: ({ top: 16, left: 16, bottom: 16, right: 16 })
    }

    Timer {
        interval: 120
        running: true
        onTriggered: {
            manager.openSurface("wallpaper", null, "eDP-1");
            openedWait.start();
        }
    }

    Timer {
        id: openedWait
        interval: Motion.diagonal + 80
        onTriggered: {
            const firstReady = manager.chromeOwner === "wallpaper" && manager.chromeReveal > 0.99;
            manager.openSurface("theme", null, "eDP-1");
            Qt.callLater(function() {
                root.crossAnchorStarted = firstReady
                    && manager.chromeOwner === "wallpaper"
                    && manager.pendingChrome.id === "theme";
                switchedWait.start();
            });
        }
    }

    Timer {
        id: switchedWait
        interval: Motion.diagonal + Motion.sidebarEnter + 120
        onTriggered: {
            const completed = manager.chromeOwner === "theme"
                && manager.chromeReveal > 0.99
                && manager.pendingChrome.id === undefined;
            console.log(root.crossAnchorStarted && completed
                ? "FRAME-MENU-TRANSITION-PASS" : "FRAME-MENU-TRANSITION-FAIL");
            Qt.quit();
        }
    }
}
