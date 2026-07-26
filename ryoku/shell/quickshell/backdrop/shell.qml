//@ pragma DefaultEnv QSG_RENDER_LOOP = basic
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "Singletons"

/**
 * Ryoku desktop backdrop: the in-shell wallpaper surface.
 *
 * One Background layer window per monitor (namespace ryoku-wallpaper, exclusive
 * zone -1, all four edges anchored, no input) draws a single global wallpaper
 * mirrored to every output. The ryoku-shell daemon copies the chosen image into a
 * cache file, bumps a revision, and streams {path, revision, fit} on the
 * `wallpaper` topic; each window crossfades (200 ms) to every new revision. This
 * replaces the external wallpaper daemon so wallpaper state, the colour scheme,
 * and the shell all live in one place. Contract 08 sec 1, 2.6, 3.1, 5, 7.
 *
 * The wallpaper switcher (a separate config root) still sets wallpapers through
 * `ryoku-shell wallpaper set`, which feeds this same topic.
 */
ShellRoot {
    id: root

    // The full file url the surface paints, folded from the topic's path +
    // revision so the query busts Qt's pixmap cache on every change (contract 08
    // sec 3.1). "" until the first frame; the window's paper colour shows.
    property string wallpaperUrl: ""
    // content_fit -> Image.fillMode (contract 08 sec 3.3); Cover is the default.
    property string fit: "Cover"

    readonly property string sockPath: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/ryoku-shell.sock"

    function apply(line) {
        try {
            const f = JSON.parse(line);
            root.fit = f.fit || "Cover";
            root.wallpaperUrl = (f.path && f.path.length > 0) ? "file://" + f.path + "?v=" + (f.revision || 0) : "";
        } catch (e) {
            // A malformed frame must never blank the desktop; keep the last image.
        }
    }

    // Subscribe once, then stream, mirroring the Tray/Clipboard singletons. A
    // second write would half-close the stream (daemon rule), so nothing else
    // writes here.
    Socket {
        id: sub
        path: root.sockPath
        parser: SplitParser {
            onRead: line => root.apply(line)
        }
        Component.onCompleted: connected = true
        onConnectionStateChanged: {
            if (connected) {
                write("subscribe wallpaper\n");
                flush();
            } else {
                retry.restart();
            }
        }
    }

    // The daemon may be down when the surface loads (or restart under it); retry
    // quietly so the desktop repaints once it returns.
    Timer {
        id: retry
        interval: 2000
        onTriggered: if (!sub.connected)
            sub.connected = true
    }

    // One background window per monitor; hotplug adds a window that binds the same
    // global state and paints the current revision at once (contract 08 sec 7).
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win
            required property var modelData

            screen: modelData
            color: Theme.paper
            exclusiveZone: -1
            WlrLayershell.namespace: "ryoku-wallpaper"
            WlrLayershell.layer: WlrLayer.Background
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            // A wallpaper takes no input: clicks pass through to the desktop and
            // the widgets that ride this layer (same as the frame edge surfaces).
            mask: Region {}

            Backdrop {
                anchors.fill: parent
                url: root.wallpaperUrl
                fit: root.fit
            }
        }
    }
}
