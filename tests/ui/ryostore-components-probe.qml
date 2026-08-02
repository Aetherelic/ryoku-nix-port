import QtQuick
import Quickshell
import "ryostore" as Ryo

ShellRoot {
    id: root
    property string lastPreview: ""
    property string lastSelected: ""
    property int previewCount: 0
    property int selectionCount: 0
    property string installedKey: ""
    property string detailsKey: ""
    property string settingsKey: ""
    property var probeDimensions: String(Quickshell.env("RYOSTORE_PROBE_SIZE") || "980x640").split("x")
    readonly property int probeWidth: Number(probeDimensions[0]) || 980
    readonly property int probeHeight: Number(probeDimensions[1]) || 640

    function require(condition, label) {
        if (!condition)
            throw new Error("RYOSTORE-COMPONENTS-PROBE-FAIL " + label);
    }

    function findObject(item, name) {
        if (!item)
            return null;
        if (item.objectName === name)
            return item;
        const children = item.children || [];
        for (const child of children) {
            const found = findObject(child, name);
            if (found)
                return found;
        }
        return null;
    }

    function inside(item, container) {
        if (!item)
            return false;
        const point = item.mapToItem(container, 0, 0);
        return point.x >= 0 && point.y >= 0
                && point.x + item.width <= container.width
                && point.y + item.height <= container.height;
    }

    Ryo.ProductCover {
        id: realCover
        width: 320
        height: 180
        item: ({
            id: "hero",
            category: "rices",
            categoryName: "Rices",
            name: "Hero",
            art: Qt.resolvedUrl("ryostore/logo.svg"),
            installed: false
        })
    }

    Ryo.ProductCover {
        id: missingCover
        objectName: "missing-cover"
        x: 340
        width: 320
        height: 180
        item: ({
            id: "plain",
            category: "rices",
            categoryName: "Rices",
            name: "Plain",
            art: "",
            accent: "#d75f5f",
            surface: "#101010",
            installed: false
        })
    }

    Ryo.StatusReadout {
        id: active
        objectName: "active-readout"
        item: ({ category: "rices", id: "active", active: true, installed: true })
    }

    Ryo.StatusReadout {
        id: partial
        objectName: "partial-readout"
        item: ({ category: "bundles", id: "pack", installedCount: 2, totalCount: 4 })
    }

    Ryo.StatusReadout {
        id: progress
        objectName: "progress-readout"
        item: ({ category: "lockscreens", id: "clock" })
        busyKey: "lockscreens:clock"
        installStage: "DOWNLOADING"
    }

    Ryo.StatusReadout {
        id: offline
        objectName: "offline-readout"
        item: ({ category: "plugins", id: "market" })
        offline: true
    }

    Ryo.StatusReadout {
        id: failed
        objectName: "failure-readout"
        item: ({ category: "barstyles", id: "broken" })
        installErrorKey: "barstyles:broken"
        installError: "fixture install failed"
    }

    FloatingWindow {
        title: "ryostore-components-probe"
        minimumSize: Qt.size(root.probeWidth, root.probeHeight)
        maximumSize: minimumSize
        color: "#080a0d"

        Ryo.ShowroomStage {
            id: stage
            objectName: "showroom-stage"
            width: parent.width
            height: parent.height - 240
            item: ({
                id: "a",
                category: "rices",
                categoryName: "Rices",
                name: "Committed A",
                summary: "Committed product copy remains attached to its actions.",
                art: "",
                accent: "#b23a48",
                surface: "#171113",
                installed: false
            })
            previewItem: ({
                id: "b",
                category: "rices",
                categoryName: "Rices",
                name: "Preview B",
                art: Qt.resolvedUrl("ryostore/logo.svg"),
                accent: "#d99b50",
                surface: "#18140f",
                installed: true
            })
            positionText: "02 / 04"
            onInstallRequested: item => root.installedKey = item.category + ":" + item.id
            onDetailsRequested: item => root.detailsKey = item.category + ":" + item.id
            onSettingsRequested: item => root.settingsKey = item.category + ":" + item.id
        }

        Ryo.Filmstrip {
            id: strip
            objectName: "filmstrip"
            x: 0
            y: stage.height + 20
            width: parent.width
            height: 200
            selectedKey: "rices:b"
            items: [
                { id: "a", category: "rices", name: "A", art: "", accent: "#b23a48", surface: "#171113" },
                { id: "b", category: "rices", name: "B", art: "", accent: "#d99b50", surface: "#18140f" },
                { id: "c", category: "rices", name: "C", art: "", accent: "#4d8f72", surface: "#101815" },
                { id: "d", category: "rices", name: "D", art: "", accent: "#5876a8", surface: "#11141b" }
            ]
            onPreviewRequested: item => {
                root.previewCount++;
                root.lastPreview = item ? item.category + ":" + item.id : "";
            }
            onSelectionRequested: item => {
                root.selectionCount++;
                root.lastSelected = item ? item.category + ":" + item.id : "";
                strip.selectedKey = root.lastSelected;
            }
        }
    }

    Timer {
        interval: 50
        running: true
        onTriggered: {
            root.require(realCover.hasArtwork === true, "real artwork path");
            root.require(missingCover.hasArtwork === false, "metadata cover path");
            root.require(missingCover.coverTitle === "Plain", "missing art retains identity");
            root.require(missingCover.Accessible.name.indexOf("Plain") !== -1, "cover has accessible identity");
            root.require(active.labels.indexOf("ACTIVE") !== -1, "active state explicit");
            root.require(partial.labels.indexOf("2 / 4 INSTALLED") !== -1, "partial state explicit");
            root.require(progress.labels.indexOf("DOWNLOADING") !== -1, "matching progress explicit");
            root.require(offline.labels.indexOf("OFFLINE") !== -1, "offline state explicit");
            root.require(failed.labels.indexOf("fixture install failed") !== -1, "exact failure preserved");
            root.require(stage.displayItem.id === "b", "preview owns stage artwork");
            root.require(stage.actionItem.id === "a", "preview cannot retarget action");
            stage.triggerInstall();
            root.require(root.installedKey === "rices:a", "install targets committed selection");
            stage.previewItem = null;
            root.require(stage.displayItem.id === "a", "preview clears to committed selection");
            stage.reducedMotion = true;
            root.require(stage.motionDuration === 0, "reduced motion disables stage travel");
            const stageTitle = root.findObject(stage, "ryostore-stage-title");
            const stageStatus = root.findObject(stage, "ryostore-stage-status");
            const stagePrimary = root.findObject(stage, "ryostore-stage-primary");
            root.require(root.inside(stageTitle, stage), "stage title remains visible at cramped size");
            root.require(root.inside(stageStatus, stage), "stage status remains visible at cramped size");
            root.require(root.inside(stagePrimary, stage), "stage primary action remains visible at cramped size");
            strip.previewAt(1);
            root.require(root.lastPreview === "rices:b", "hover preview signal");
            root.require(root.selectionCount === 0, "preview does not select");
            strip.forceActiveFocus();
            root.require(strip.focusVisible, "filmstrip keyboard focus visible");
            const focusRing = root.findObject(strip, "ryostore-filmstrip-focus");
            root.require(focusRing && focusRing.visible, "pending cover draws focus ring");
            strip.move(-10);
            root.require(strip.pendingKey === "rices:a", "left boundary clamps");
            strip.moveBoundary(true);
            root.require(strip.pendingKey === "rices:d", "End reaches final item");
            strip.move(1);
            root.require(strip.pendingKey === "rices:d", "right boundary clamps");
            strip.moveBoundary(false);
            const flick = root.findObject(strip, "ryostore-filmstrip-flick");
            root.require(flick !== null, "filmstrip flick surface exposed");
            strip.reducedMotion = true;
            flick.contentX = Math.max(0, flick.contentWidth - flick.width);
            strip.settleMovement();
            root.require(root.lastSelected === "rices:d", "right-edge settle commits final item");
            root.require(strip.contentOffset > 0, "filmstrip exposes changed offset");
            strip.selectedKey = "rices:b";
            const beforeWheelCommit = root.selectionCount;
            strip.queueWheel(-1);
            root.require(strip.pendingKey === "rices:c", "wheel advances pending item");
            root.require(root.selectionCount === beforeWheelCommit, "wheel waits for gesture end");
            strip.settleWheel();
            root.require(root.lastSelected === "rices:c", "settled wheel commits pending item");
            root.require(root.selectionCount === beforeWheelCommit + 1, "wheel commits once");
            root.require(strip.kineticEnabled === false, "reduced motion disables kinetic travel");
            flick.flick(-1200, 0);
            root.require(flick.flicking === false, "reduced motion cancels flick immediately");
            console.log("RYOSTORE-COMPONENTS-PROBE-PASS");
            Qt.quit();
        }
    }
}
