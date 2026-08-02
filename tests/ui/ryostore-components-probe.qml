import QtQuick
import Quickshell
import "ryostore" as Ryo

ShellRoot {
    id: root

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
            console.log("RYOSTORE-COMPONENTS-PROBE-PASS");
            Qt.quit();
        }
    }
}
