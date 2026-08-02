import QtQuick
import Quickshell
import "ryostore" as Ryo

ShellRoot {
    id: root
    property string lastPreview: ""
    property string lastSelected: ""
    property int previewCount: 0
    property int selectionCount: 0

    function require(condition, label) {
        if (!condition)
            throw new Error("RYOSTORE-COMPONENTS-PROBE-FAIL " + label);
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

    Ryo.Filmstrip {
        id: strip
        objectName: "filmstrip"
        y: 220
        width: 900
        height: 220
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
            strip.previewAt(1);
            root.require(root.lastPreview === "rices:b", "hover preview signal");
            root.require(root.selectionCount === 0, "preview does not select");
            strip.move(-10);
            root.require(strip.pendingKey === "rices:a", "left boundary clamps");
            strip.moveBoundary(true);
            root.require(strip.pendingKey === "rices:d", "End reaches final item");
            strip.move(1);
            root.require(strip.pendingKey === "rices:d", "right boundary clamps");
            strip.commitPending();
            root.require(root.lastSelected === "rices:d", "settled item commits");
            root.require(strip.contentOffset >= 0, "filmstrip offset exposed");
            console.log("RYOSTORE-COMPONENTS-PROBE-PASS");
            Qt.quit();
        }
    }
}
