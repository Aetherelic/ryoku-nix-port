import QtQuick
import Quickshell
import Quickshell.Wayland
import "../modules"
import "kit"
import "kit/Routes.js" as Routes
import Ryoku.Ui.Singletons

// The Shell Studio: the panel the bar's logo opens. It owns everything the shell
// exposes at a click, in nine routes down one rail: the bar (position, form,
// surface, widgets, logo, spaces, pickers), the desk (dock, desktop widgets and
// the spectrum) and the shell itself (the mid-work switches, and the session).
//
// It replaces a panel that had three ways to be lost: a breadcrumb, a
// QUICK/CONFIGURE mode pair, and a landing page whose only job was to list the
// routes the rail now always shows. It also replaces a translucent plate you
// could read the wallpaper through with an opaque one, because a settings surface
// that competes with the picture behind it is not a settings surface.
//
// State still reads and writes straight off `root` (the qsbar Theme) and the
// shell's own services, so persistence is untouched. The chrome is paper and ink
// from Ryoku.Ui; the bar's retinted colours appear only where they are data (the
// silhouette, the accent swatches, the marker preview).
PanelWindow {
    id: cc
    required property var root

    property var tokens: tk
    property string route: "bars"

    // `open(target)` keeps its old contract: a route id shows that route, and an
    // empty target (or the retired "quick"/"configure" words) shows the first.
    function open(target) {
        var id = (target === undefined || target === "" || target === "quick" || target === "configure")
            ? "bars" : target;
        cc.route = Routes.byId(id) ? id : "bars";
        cc.root.controlVisible = true;
    }
    function close() { cc.root.controlVisible = false }

    readonly property var routeDef: Routes.byId(cc.route)
    function pageUrl() {
        var f = Routes.fileFor(cc.route);
        return f === "" ? Qt.resolvedUrl("routes/BarsRoute.qml") : Qt.resolvedUrl("routes/" + f + ".qml");
    }

    // Search index: one entry per route from the registry, plus the controls
    // worth naming. Accepting an entry navigates to its route.
    readonly property var searchEntries: cc.buildSearchIndex()
    function buildSearchIndex() {
        var out = [];
        for (var i = 0; i < Routes.ROUTES.length; i++) {
            var r = Routes.ROUTES[i];
            out.push({ id: r.id, name: r.label, route: r.id, category: r.label,
                       searchTags: String(r.keywords || "").split(/\s+/), description: r.desc });
        }
        return out.concat([
            { id: "bars.position", name: "Bar position", route: "bars", category: "Bar",
              searchTags: ["top", "bottom", "edge"], description: "Which edge the bar docks to." },
            { id: "bars.form", name: "Bar form", route: "bars", category: "Bar",
              searchTags: ["full", "fit", "dock", "notch", "islands", "shape"], description: "The shell shape the bar takes." },
            { id: "bars.accent", name: "Accent colour", route: "bars", category: "Bar",
              searchTags: ["colour", "color", "seal", "palette"], description: "Which palette slot the bar draws its accent from." },
            { id: "bars.layout", name: "Edit layout", route: "bars", category: "Bar",
              searchTags: ["arrange", "reorder", "move", "unlock"], description: "Rearrange the bar's widgets in place." },
            { id: "widgets.visibility", name: "Widget visibility", route: "widgets", category: "Widgets",
              searchTags: ["show", "hide", "on", "off"], description: "Which widgets the bar carries." },
            { id: "widgets.colour", name: "Per-widget colour", route: "widgets", category: "Widgets",
              searchTags: ["colour", "color", "tint", "fill"], description: "Give one widget its own accent." },
            { id: "logo.mark", name: "Launcher mark", route: "logo", category: "Logo",
              searchTags: ["wordmark", "kanji", "glyph", "brand"], description: "The mark in the launcher pill." },
            { id: "spaces.count", name: "Workspace count", route: "spaces", category: "Spaces",
              searchTags: ["five", "ten", "active", "number"], description: "How many workspaces the bar shows." },
            { id: "spaces.marker", name: "Workspace marker", route: "spaces", category: "Spaces",
              searchTags: ["dots", "numbers", "kanji", "pacman", "aurora"], description: "The marker each workspace wears." },
            { id: "pickers.style", name: "Picker style", route: "pickers", category: "Pickers",
              searchTags: ["tanzaku", "hearthstone", "carousel"], description: "The layout the pickers open in." },
            { id: "dock.enabled", name: "Dock", route: "dock", category: "Dock",
              searchTags: ["dock", "apps", "pinned"], description: "The app dock on the opposite edge." },
            { id: "dock.autohide", name: "Dock auto-hide", route: "dock", category: "Dock",
              searchTags: ["hide", "peek", "reveal"], description: "Keep the dock as a peek strip until hovered." },
            { id: "desktop.widgets", name: "Desktop widgets", route: "desktop", category: "Desktop",
              searchTags: ["clock", "calendar", "music", "stats", "weather", "notes"], description: "What rides the wallpaper." },
            { id: "desktop.visualiser", name: "Spectrum", route: "desktop", category: "Desktop",
              searchTags: ["visualiser", "visualizer", "audio", "spectrum"], description: "The audio spectrum on the desktop." },
            { id: "system.dnd", name: "Do not disturb", route: "system", category: "System",
              searchTags: ["dnd", "quiet", "notifications"], description: "Hold notifications back." },
            { id: "system.reload", name: "Reload shell", route: "system", category: "System",
              searchTags: ["restart", "refresh"], description: "Restart the shell's surfaces." },
            { id: "session.lock", name: "Lock", route: "session", category: "Session",
              searchTags: ["lock", "secure"], description: "Lock the session." },
            { id: "session.shutdown", name: "Shut down", route: "session", category: "Session",
              searchTags: ["power", "off", "poweroff"], description: "Power the machine off." }
        ]);
    }

    screen: cc.root.activePopupScreen
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "ryoku-control"
    WlrLayershell.keyboardFocus: cc.root.controlVisible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    property real reveal: cc.root.controlVisible ? 1 : 0
    Behavior on reveal {
        NumberAnimation {
            duration: cc.root.controlVisible ? tk.revealOpen : tk.revealClose
            easing.type: Easing.OutCubic
        }
    }
    visible: reveal > 0.001
    onRevealChanged: if (reveal < 0.01) { cc.route = "bars"; searchOverlay.shown = false }

    CcTokens { id: tk; root: cc.root }

    readonly property int barH: cc.root.v2BarHeight
    readonly property int plateW: Math.min(tk.plateW, cc.width - 2 * tk.screenMargin)
    // The plate is as tall as it needs to be: the rail's natural height or the
    // page's, whichever is taller, capped by the screen and by tk.plateH. A short
    // route therefore yields a short panel rather than a screenful of empty
    // paper, and a long one scrolls inside the cap.
    readonly property int plateCap: Math.min(tk.plateH, cc.height - cc.barH - 2 * tk.screenMargin - tk.gap)
    readonly property int plateH: Math.max(Math.min(rail.implicitHeight, cc.plateCap),
        Math.min(cc.plateCap, tk.headH + tk.pad * 2 + tk.sectionGap + stage.pageHeight))

    // A click anywhere off the plate dismisses, the way every other popout on this
    // bar behaves. It sits below the plate, so the plate's own eater still wins.
    MouseArea {
        anchors.fill: parent
        enabled: cc.root.controlVisible
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onPressed: cc.close()
    }

    Rectangle {
        id: plate
        width: cc.plateW
        height: cc.plateH
        // Routes have different natural heights, so the plate resizes on every
        // switch. Snapping made the panel feel like a slideshow of dialogs; on the
        // house spatial curve it reads as one surface changing its mind. It only
        // animates once open, so revealing the panel never plays two motions.
        Behavior on height {
            enabled: cc.reveal > 0.99
            NumberAnimation {
                duration: Tokens.durDefaultSpatial
                easing.type: Easing.Bezier
                easing.bezierCurve: Tokens.curveDefaultSpatial
            }
        }
        radius: tk.corner
        color: Tokens.paper
        border.width: 1
        border.color: Tokens.line
        clip: true

        // it floats over the desktop, so it is the one surface here allowed a
        // shadow (docs/ui-ux.md: depth is a hairline, except when something
        // genuinely floats).
        PillShadow { theme: cc.root }

        x: Math.round(Math.max(tk.screenMargin,
            Math.min(cc.root.launcherBarX - tk.gap, cc.width - width - tk.screenMargin)))
        y: (cc.root.barPosition === "bottom" ? (cc.height - cc.barH - tk.gap - height) : (cc.barH + tk.gap))
           + (cc.root.barPosition === "bottom" ? tk.gap : -tk.gap) * (1 - cc.reveal)
        opacity: cc.reveal
        transformOrigin: cc.root.barPosition === "bottom" ? Item.Bottom : Item.Top
        focus: cc.root.controlVisible
        Keys.onPressed: function (e) {
            if (e.key === Qt.Key_Escape) {
                if (searchOverlay.shown) searchOverlay.shown = false;
                else cc.close();
                e.accepted = true;
            }
        }
        MouseArea { anchors.fill: parent; onClicked: {} }   // eat clicks so they don't dismiss

        Shortcut {
            sequence: "Ctrl+K"
            context: Qt.WindowShortcut
            enabled: cc.root.controlVisible
            onActivated: searchOverlay.shown = true
        }

        CcRail {
            id: rail
            anchors { top: parent.top; bottom: parent.bottom; left: parent.left }
            width: tk.railW
            root: cc.root
            tk: tk
            current: cc.route
            onChose: (id) => cc.route = id
            onSearchRequested: searchOverlay.shown = true
        }

        Item {
            id: body
            anchors {
                top: parent.top; bottom: parent.bottom
                left: rail.right; right: parent.right
                topMargin: tk.pad; bottomMargin: tk.pad
                leftMargin: tk.pad; rightMargin: tk.pad
            }


            CcHead {
                id: head
                anchors { top: parent.top; left: parent.left; right: parent.right }
                root: cc.root
                tk: tk
                title: cc.routeDef ? cc.routeDef.label : ""
                gloss: cc.routeDef ? cc.routeDef.gloss : ""
                desc: cc.routeDef ? cc.routeDef.desc : ""
                onClosed: cc.close()
            }

            PageMotionStage {
                id: stage
                anchors {
                    top: head.bottom; topMargin: tk.sectionGap
                    left: parent.left; right: parent.right; bottom: parent.bottom
                }
                root: cc.root
                cc: cc
                outMs: tk.pageOut
                inMs: tk.pageIn
                pageUrl: cc.pageUrl()
            }
        }

        // A page longer than the plate is cut by the plate's clip, and a row sliced
        // in half reads as a broken layout rather than "there is more below". This
        // dissolves the cut into the paper. `clip` is rectangular and ignores the
        // plate's radius, so the fade carries the corner itself or it squares it.
        Rectangle {
            anchors { left: rail.right; right: parent.right; bottom: parent.bottom }
            height: tk.pad * 2
            bottomRightRadius: tk.corner
            gradient: Gradient {
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { position: 0.55; color: Qt.rgba(Tokens.paper.r, Tokens.paper.g, Tokens.paper.b, 0.85) }
                GradientStop { position: 1.0; color: Tokens.paper }
            }
        }

        // Search is a feature, not a permanent band across the top: it opens over
        // the body on Ctrl K or from the rail's foot, and closes on Escape.
        Item {
            id: searchOverlay
            property bool shown: false
            anchors.fill: body
            visible: opacity > 0.001
            opacity: searchOverlay.shown ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: tk.fade } }
            onShownChanged: if (searchOverlay.shown) search.focusInput()

            Rectangle {
                anchors.fill: parent
                color: Tokens.paper
                opacity: 0.96
            }
            CcSearch {
                id: search
                anchors { top: parent.top; left: parent.left; right: parent.right }
                root: cc.root
                tk: tk
                entries: cc.searchEntries
                onAccepted: (entry) => {
                    searchOverlay.shown = false;
                    cc.route = entry.route;
                }
                onDismissed: searchOverlay.shown = false
            }
        }

    }
}
