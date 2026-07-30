pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Ryoku.Blobs
import "../../Singletons"
import "components" as Components
import "popouts" as NacrePopouts

Scope {
    id: root

    readonly property bool unifiedBlobFrame: true
    property var modelData
    readonly property var settings: Config.normalizedNacre
    readonly property real frameLip: settings.frameSize
    readonly property real frameInset: frameLip
    readonly property real smoothing: settings.edgeMelt
    readonly property real frameRadius: settings.frameRoundness
    readonly property real barSpan: settings.height * settings.islandScale + frameLip
    property string selectedPopup: ""
    property string hoverPopup: ""
    property real selectedCenter: 0
    property real hoverCenter: 0
    property bool mediaPresent: Media.present
    readonly property bool mediaPopupEnabled: selectedPopup === "" && mediaPresent
    readonly property bool popupBackdropActive: selectedPopup !== ""
    readonly property int overlayKeyboardMode: selectedPopup === "connectivity"
        ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    function handlePopup(name, center, active, pinned) {
        if (pinned) {
            hoverPopup = "";
            selectedCenter = center;
            selectedPopup = selectedPopup === name ? "" : name;
            return;
        }
        hoverCenter = center;
        hoverPopup = active ? name : "";
    }

    function centerFor(name) {
        if (selectedPopup === name)
            return selectedCenter;
        if (hoverPopup === name)
            return hoverCenter;
        return selectedCenter;
    }

    function popupFor(name) {
        switch (name) {
        case "audio": return audioPop;
        case "battery": return batteryPop;
        case "calendar": return calendarPop;
        case "connectivity": return connectivityPop;
        case "resources": return resourcesPop;
        case "weather": return weatherPop;
        case "notifications": return inboxPop;
        default: return null;
        }
    }

    function selectedPopupBounds() {
        const popup = popupFor(selectedPopup);
        return popup ? Qt.rect(popup.bodyX, popup.bodyY,
            popup.bodyWidth, popup.bodyHeight) : Qt.rect(0, 0, 0, 0);
    }

    function dismissPopupAt(x, y) {
        if (!popupBackdropActive)
            return false;
        const bounds = selectedPopupBounds();
        if (x >= bounds.x && x < bounds.x + bounds.width
                && y >= bounds.y && y < bounds.y + bounds.height)
            return false;
        selectedPopup = "";
        return true;
    }

    PanelWindow {
        screen: root.modelData
        visible: root.modelData !== null
        color: "transparent"
        exclusionMode: ExclusionMode.Normal
        exclusiveZone: root.barSpan
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        WlrLayershell.namespace: "ryoku-nacre-reserve"
        anchors { top: true; left: true; right: true }
        implicitHeight: root.barSpan
        mask: Region {}
    }

    PanelWindow {
        id: overlay
        objectName: "nacre-overlay"

        readonly property bool monFullscreen: {
            if (!root.modelData)
                return false;
            const monitors = Hyprland.monitors.values;
            for (let i = 0; i < monitors.length; ++i) {
                const monitor = monitors[i];
                if (monitor.name === root.modelData.name)
                    return monitor.activeWorkspace
                        ? Fullscreen.byWs[monitor.activeWorkspace.id] === true : false;
            }
            return false;
        }
        readonly property real toastCenter: width - root.frameLip - toastPop.openWidth / 2

        onMonFullscreenChanged: if (monFullscreen) {
            root.selectedPopup = "";
            root.hoverPopup = "";
        }

        screen: root.modelData
        visible: root.modelData !== null
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: root.overlayKeyboardMode
        WlrLayershell.namespace: "ryoku-nacre"
        anchors { top: true; left: true; right: true; bottom: true }

        mask: overlay.monFullscreen ? hiddenRegion
            : root.popupBackdropActive ? fullRegion : activeRegion

        Region { id: hiddenRegion }
        Region {
            id: fullRegion
            width: overlay.width
            height: overlay.height
        }
        Region {
            id: activeRegion
            Region { item: leftIsland }
            Region { item: centerIsland }
            Region { item: rightIsland }
            Region { x: audioPop.maskX; y: audioPop.maskY; width: audioPop.maskWidth; height: audioPop.maskHeight }
            Region { x: batteryPop.maskX; y: batteryPop.maskY; width: batteryPop.maskWidth; height: batteryPop.maskHeight }
            Region { x: calendarPop.maskX; y: calendarPop.maskY; width: calendarPop.maskWidth; height: calendarPop.maskHeight }
            Region { x: connectivityPop.maskX; y: connectivityPop.maskY; width: connectivityPop.maskWidth; height: connectivityPop.maskHeight }
            Region { x: mediaPop.maskX; y: mediaPop.maskY; width: mediaPop.maskWidth; height: mediaPop.maskHeight }
            Region { x: resourcesPop.maskX; y: resourcesPop.maskY; width: resourcesPop.maskWidth; height: resourcesPop.maskHeight }
            Region { x: weatherPop.maskX; y: weatherPop.maskY; width: weatherPop.maskWidth; height: weatherPop.maskHeight }
            Region { x: inboxPop.maskX; y: inboxPop.maskY; width: inboxPop.maskWidth; height: inboxPop.maskHeight }
            Region { x: toastPop.maskX; y: toastPop.maskY; width: toastPop.maskWidth; height: toastPop.maskHeight }
        }

        MouseArea {
            anchors.fill: parent
            enabled: root.popupBackdropActive
            acceptedButtons: Qt.AllButtons
            onPressed: (mouse) => root.dismissPopupAt(mouse.x, mouse.y)
        }

        FocusScope {
            anchors.fill: parent
            visible: !overlay.monFullscreen

            BlobGroup {
                id: blobGroup
                objectName: "nacre-blob-group"
                color: Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b,
                    root.settings.opacity)
                borderColor: Theme.primary
                borderWidth: 1.5
                smoothing: root.smoothing
                shadowStrength: 0.35
                shadowSize: 12
            }

            BlobInvertedRect {
                objectName: "nacre-frame"
                anchors.fill: parent
                anchors.margins: -50
                group: blobGroup
                radius: root.frameRadius
                borderTop: 50 + root.frameLip
                borderBottom: 50 + root.frameLip
                borderLeft: 50 + root.frameLip
                borderRight: 50 + root.frameLip
                visible: root.settings.frame
            }

            BlobRect {
                objectName: "nacre-lobe-left"
                group: blobGroup
                visible: leftIsland.visible
                x: 0
                y: 0
                implicitWidth: leftIsland.x + leftIsland.width
                implicitHeight: root.barSpan
                topLeftRadius: 0
                topRightRadius: 0
                bottomLeftRadius: 0
                bottomRightRadius: Math.min(root.frameRadius, root.settings.height / 2)
                deformScale: 0.000015
                sinks: false
            }

            BlobRect {
                objectName: "nacre-lobe-center"
                group: blobGroup
                visible: centerIsland.visible
                x: centerIsland.x
                y: 0
                implicitWidth: centerIsland.width
                implicitHeight: root.barSpan
                topLeftRadius: 0
                topRightRadius: 0
                bottomLeftRadius: Math.min(root.frameRadius, root.settings.height / 2)
                bottomRightRadius: Math.min(root.frameRadius, root.settings.height / 2)
                deformScale: 0.000015
                sinks: false
            }

            BlobRect {
                objectName: "nacre-lobe-right"
                group: blobGroup
                visible: rightIsland.visible
                x: rightIsland.x
                y: 0
                implicitWidth: overlay.width - rightIsland.x
                implicitHeight: root.barSpan
                topLeftRadius: 0
                topRightRadius: 0
                bottomLeftRadius: Math.min(root.frameRadius, root.settings.height / 2)
                bottomRightRadius: 0
                deformScale: 0.000015
                sinks: false
            }

            Components.Island {
                id: centerIsland
                z: 2
                anchors.top: parent.top
                anchors.topMargin: root.frameLip
                anchors.horizontalCenter: parent.horizontalCenter
                edge: "center"
                unifiedFrame: true
                widgetIds: root.settings.islands.center
                barHeight: root.settings.height
                islandScale: root.settings.islandScale
                surfaceOpacity: root.settings.opacity
                horizontalPadding: root.settings.padding
                widgetSpacing: root.settings.spacing
                maxWidth: Math.max(root.settings.height,
                    parent.width - (root.settings.height + root.settings.islandGap) * 2)
                onPopupRequested: (name, center, active, pinned) =>
                    root.handlePopup(name, center, active, pinned)
            }

            Components.Island {
                id: leftIsland
                z: 2
                anchors.top: parent.top
                anchors.topMargin: root.frameLip
                anchors.left: parent.left
                edge: "left"
                unifiedFrame: true
                widgetIds: root.settings.islands.left
                barHeight: root.settings.height
                islandScale: root.settings.islandScale
                surfaceOpacity: root.settings.opacity
                horizontalPadding: root.settings.padding
                widgetSpacing: root.settings.spacing
                maxWidth: Math.max(root.settings.height,
                    centerIsland.x - root.settings.islandGap)
                onPopupRequested: (name, center, active, pinned) =>
                    root.handlePopup(name, center, active, pinned)
            }

            Components.Island {
                id: rightIsland
                z: 2
                anchors.top: parent.top
                anchors.topMargin: root.frameLip
                anchors.right: parent.right
                edge: "right"
                unifiedFrame: true
                widgetIds: root.settings.islands.right
                barHeight: root.settings.height
                islandScale: root.settings.islandScale
                surfaceOpacity: root.settings.opacity
                horizontalPadding: root.settings.padding
                widgetSpacing: root.settings.spacing
                maxWidth: Math.max(root.settings.height,
                    parent.width - centerIsland.x - centerIsland.width - root.settings.islandGap)
                onPopupRequested: (name, center, active, pinned) =>
                    root.handlePopup(name, center, active, pinned)
            }

            Components.Popout {
                id: audioPop
                group: blobGroup
                frameThickness: root.barSpan
                frameLip: root.frameLip
                radius: root.frameRadius
                smoothing: root.smoothing
                scaleFactor: root.settings.osdScale
                alongCenter: root.centerFor("audio")
                pinned: root.selectedPopup === "audio"
                openWidth: 300
                openHeight: 420
                content: Component {
                    NacrePopouts.AudioPopout { open: audioPop.progress > 0.5 }
                }
            }

            Components.Popout {
                id: batteryPop
                group: blobGroup
                frameThickness: root.barSpan
                frameLip: root.frameLip
                radius: root.frameRadius
                smoothing: root.smoothing
                scaleFactor: root.settings.osdScale
                alongCenter: root.centerFor("battery")
                pinned: root.selectedPopup === "battery"
                openWidth: 300
                openHeight: 280
                content: Component { NacrePopouts.BatteryPopout {} }
            }

            Components.Popout {
                id: calendarPop
                group: blobGroup
                frameThickness: root.barSpan
                frameLip: root.frameLip
                radius: root.frameRadius
                smoothing: root.smoothing
                scaleFactor: root.settings.osdScale
                alongCenter: root.centerFor("calendar")
                pinned: root.selectedPopup === "calendar"
                openWidth: 220
                openHeight: 130
                content: Component { NacrePopouts.CalendarPopout {} }
            }

            Components.Popout {
                id: connectivityPop
                group: blobGroup
                frameThickness: root.barSpan
                frameLip: root.frameLip
                radius: root.frameRadius
                smoothing: root.smoothing
                scaleFactor: root.settings.osdScale
                alongCenter: root.centerFor("connectivity")
                pinned: root.selectedPopup === "connectivity"
                openWidth: 330
                openHeight: 520
                content: Component {
                    NacrePopouts.ConnectivityPopout { open: connectivityPop.progress > 0.5 }
                }
            }

            Components.Popout {
                id: mediaPop
                group: blobGroup
                frameThickness: root.barSpan
                frameLip: root.frameLip
                radius: root.frameRadius
                smoothing: root.smoothing
                scaleFactor: root.settings.osdScale
                alongCenter: root.centerFor("media")
                triggerHovered: root.hoverPopup === "media" && root.selectedPopup === ""
                active: root.mediaPopupEnabled
                closeDelay: 140
                openWidth: 300
                openHeight: 180
                content: Component { NacrePopouts.MediaPopout {} }
            }

            Components.Popout {
                id: resourcesPop
                group: blobGroup
                frameThickness: root.barSpan
                frameLip: root.frameLip
                radius: root.frameRadius
                smoothing: root.smoothing
                scaleFactor: root.settings.osdScale
                alongCenter: root.centerFor("resources")
                pinned: root.selectedPopup === "resources"
                openWidth: 280
                openHeight: 360
                content: Component { NacrePopouts.ResourcesPopout {} }
            }

            Components.Popout {
                id: weatherPop
                group: blobGroup
                frameThickness: root.barSpan
                frameLip: root.frameLip
                radius: root.frameRadius
                smoothing: root.smoothing
                scaleFactor: root.settings.osdScale
                alongCenter: root.centerFor("weather")
                pinned: root.selectedPopup === "weather"
                openWidth: 320
                openHeight: 240
                content: Component { NacrePopouts.WeatherPopout {} }
            }

            Components.Popout {
                id: inboxPop
                group: blobGroup
                frameThickness: root.barSpan
                frameLip: root.frameLip
                radius: root.frameRadius
                smoothing: root.smoothing
                scaleFactor: root.settings.osdScale
                alongCenter: root.centerFor("notifications")
                pinned: root.selectedPopup === "notifications"
                openWidth: 340
                openHeight: 520
                content: Component {
                    NacrePopouts.NotificationInbox {
                        open: inboxPop.progress > 0.5
                        onCloseRequested: root.selectedPopup = ""
                    }
                }
            }

            Components.Popout {
                id: toastPop
                group: blobGroup
                frameThickness: root.barSpan
                frameLip: root.frameLip
                radius: root.frameRadius
                smoothing: root.smoothing
                scaleFactor: root.settings.osdScale
                alongCenter: overlay.toastCenter
                pinned: Notifs.popups.length > 0 && root.selectedPopup === ""
                active: root.selectedPopup === ""
                openWidth: 342
                openHeight: 100
                content: Component {
                    NacrePopouts.NotificationToast {
                        onOpenInbox: {
                            root.selectedCenter = overlay.toastCenter;
                            root.selectedPopup = "notifications";
                        }
                    }
                }
            }
        }
    }
}
