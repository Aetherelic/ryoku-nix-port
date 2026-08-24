pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import "../kit"
import "../../modules"
import Ryoku.Ui
import Ryoku.Ui.Singletons
import shell.services as Services

// DOCK route (台). The first-class app dock that lives on the edge opposite the
// bar. Every look knob and the pin list read and write through the services Dock
// singleton's `dock` store (shell.json top-level `dock`), so persistence is the
// same path the dock surface and Bar Studio use. Reorder is the dock's own job
// (drag), so this page only pins and unpins.
Item {
    id: page
    property var root
    property var cc
    readonly property var tk: cc.tokens
    // The content column is capped so a label and its control stay related.
    readonly property real colW: Math.min(page.width, tk.contentW)
    implicitHeight: col.implicitHeight

    function removePin(cls) {
        const cur = Services.Dock.pinnedOrStarter();
        const next = [];
        for (let i = 0; i < cur.length; i++)
            if (cur[i] !== cls)
                next.push(cur[i]);
        Services.Dock.setPinned(next);
    }

    // Presentable captions for the Style chips: Chips render the option string,
    // so the caption lives in `options` and maps back to the stored key here.
    function styleCap(key) {
        const opts = Services.Dock.styleOptions;
        for (let i = 0; i < opts.length; i++)
            if (opts[i].key === key)
                return opts[i].label;
        return "";
    }
    function styleKey(label) {
        const opts = Services.Dock.styleOptions;
        for (let i = 0; i < opts.length; i++)
            if (opts[i].label === label)
                return opts[i].key;
        return label;
    }

    // One pinned class: its icon, its name, and a remove action. Mirrors the row
    // geometry (40 tall, hairline under, suppressed on the last) so the list reads
    // as one printed band with the switches above it.
    component PinRow: Item {
        id: pr
        property string cls: ""
        property bool last: false
        readonly property string iconSrc: Services.Dock.iconFor(pr.cls)
        readonly property string appName: {
            const e = DesktopEntries.heuristicLookup(pr.cls);
            return (e && e.name) ? e.name : pr.cls;
        }
        width: parent ? parent.width : 0
        // tall enough that a desktop icon clears the hairline, and inset to the
        // card's own text column so the list reads as rows, not as a border stack
        height: Tokens.ctlH + page.tk.gap * 2

        Image {
            id: ico
            anchors.left: parent.left
            anchors.leftMargin: page.tk.pad
            anchors.verticalCenter: parent.verticalCenter
            width: Tokens.ctlH
            height: Tokens.ctlH
            source: pr.iconSrc
            visible: pr.iconSrc !== ""
            fillMode: Image.PreserveAspectFit
            asynchronous: true
            smooth: true
        }
        UiText {
            anchors.left: ico.right
            anchors.leftMargin: page.tk.gap
            anchors.right: rm.left
            anchors.rightMargin: page.tk.gap
            anchors.verticalCenter: parent.verticalCenter
            text: pr.appName
            elide: Text.ElideRight
            color: Tokens.ink
            font.family: Tokens.ui
            font.pixelSize: Tokens.fBody
        }
        Rectangle {
            id: rm
            anchors.right: parent.right
            anchors.rightMargin: page.tk.pad
            anchors.verticalCenter: parent.verticalCenter
            width: Tokens.ctlH
            height: Tokens.ctlH
            radius: Tokens.radius
            color: rmMa.containsMouse ? Tokens.tint5 : "transparent"
            Behavior on color { ColorAnimation { duration: Tokens.snap } }
            IconText {
                anchors.centerIn: parent
                text: "close"
                color: rmMa.containsMouse ? Tokens.ink : Tokens.inkFaint
                font.pixelSize: Tokens.fBody
            }
            MouseArea {
                id: rmMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: page.removePin(pr.cls)
            }
        }
        Rectangle {
            visible: !pr.last
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.leftMargin: page.tk.pad
            anchors.right: parent.right
            anchors.rightMargin: page.tk.pad
            height: 1
            color: Tokens.lineSoft
        }
    }
    // A live schematic of the screen with the dock on it: the studio plate covers
    // the real dock (and with edge=left it sits right underneath this panel), so
    // without this a click on an edge chip changes something you cannot see. It
    // draws the resolved edge, the icon run, and whether labels ride along.
    component DockPreview: Rectangle {
        id: dp
        readonly property string edge: {
            const e = String(Services.Dock.cfg("edge", "auto"));
            if (e !== "auto")
                return e;
            return page.root && page.root.barPosition === "bottom" ? "top" : "bottom";
        }
        readonly property bool vertical: dp.edge === "left" || dp.edge === "right"
        readonly property bool live: Services.Dock.cfg("enabled", false)
        readonly property int pins: Math.max(3, Math.min(6, Services.Dock.pinnedOrStarter().length))
        readonly property string style: Services.Dock.cfg("style", "islands")

        height: Tokens.px(96)
        radius: Tokens.radius
        color: Tokens.paperLift
        border.width: 1
        border.color: Tokens.line

        // the bar, so the "opposite the bar" rule is visible rather than asserted
        Rectangle {
            width: parent.width - Tokens.s4 * 2
            height: 4
            radius: 2
            color: Tokens.inkFaint
            opacity: 0.5
            x: Tokens.s4
            y: page.root && page.root.barPosition === "bottom" ? parent.height - Tokens.s3 - height : Tokens.s3
        }

        // the dock itself, drawn in the picked style so a Style change shows in
        // the diagram, not only on the real dock hidden behind this panel.
        Item {
            id: island
            readonly property int marks: dp.pins
            readonly property int cell: Tokens.s4
            readonly property int run: island.marks * island.cell + Tokens.s2
            // tanzaku strips hang from the screen edge: flush, and a step deeper.
            readonly property bool strips: dp.style === "tanzaku"
            readonly property int depth: island.strips ? Tokens.s6 : Tokens.s5
            readonly property int inset: island.strips ? 0 : Tokens.s2
            // rail, ledger and seal share one plate; islands and tanzaku give
            // each mark its own.
            readonly property bool onePlate: dp.style === "rail" || dp.style === "ledger" || dp.style === "seal"

            width: dp.vertical ? island.depth : island.run
            height: dp.vertical ? island.run : island.depth
            opacity: dp.live ? 1 : 0.35
            Behavior on opacity { NumberAnimation { duration: Tokens.snap } }

            x: dp.edge === "left" ? island.inset
                : dp.edge === "right" ? dp.width - width - island.inset
                : Math.round((dp.width - width) / 2)
            y: dp.edge === "top" ? island.inset
                : dp.edge === "bottom" ? dp.height - height - island.inset
                : Math.round((dp.height - height) / 2)
            Behavior on x { NumberAnimation { duration: Tokens.move; easing.bezierCurve: Tokens.curveEmphasized; easing.type: Easing.Bezier } }
            Behavior on y { NumberAnimation { duration: Tokens.move; easing.bezierCurve: Tokens.curveEmphasized; easing.type: Easing.Bezier } }

            Rectangle {
                anchors.fill: parent
                visible: island.onePlate
                radius: dp.style === "seal" ? 0 : Tokens.radius
                color: Tokens.tint10
                border.width: Tokens.border
                border.color: dp.live ? Tokens.line : Tokens.lineSoft
            }

            Grid {
                anchors.centerIn: parent
                columns: dp.vertical ? 1 : island.marks
                Repeater {
                    model: island.marks
                    delegate: Item {
                        id: slot
                        required property int index
                        readonly property bool lastCell: slot.index === island.marks - 1
                        width: dp.vertical ? island.depth : island.cell
                        height: dp.vertical ? island.cell : island.depth

                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: Tokens.px(2)
                            visible: island.strips
                            radius: Tokens.radius
                            color: Tokens.tint10
                            border.width: Tokens.border
                            border.color: dp.live ? Tokens.line : Tokens.lineSoft
                        }
                        Rectangle {
                            anchors.centerIn: parent
                            visible: dp.style === "islands"
                            width: Tokens.s3
                            height: Tokens.s3
                            radius: Tokens.radius
                            color: Tokens.tint10
                            border.width: Tokens.border
                            border.color: dp.live ? Tokens.line : Tokens.lineSoft
                        }
                        Rectangle {
                            visible: dp.style === "ledger" && !slot.lastCell
                            color: dp.live ? Tokens.line : Tokens.lineSoft
                            width: dp.vertical ? parent.width : Tokens.border
                            height: dp.vertical ? Tokens.border : parent.height
                            x: dp.vertical ? 0 : parent.width - width
                            y: dp.vertical ? parent.height - height : 0
                        }
                        // seal fills only the running apps; the rest stay hollow
                        // silhouettes, so colour alone reads as running.
                        Rectangle {
                            anchors.centerIn: parent
                            width: Tokens.s2
                            height: Tokens.s2
                            radius: dp.style === "seal" ? 0 : Tokens.px(2)
                            color: dp.style !== "seal" || slot.index % 2 === 0 ? Tokens.inkMuted : "transparent"
                            border.width: dp.style === "seal" && slot.index % 2 !== 0 ? Tokens.border : 0
                            border.color: Tokens.inkMuted
                        }
                    }
                }
            }
        }

    }


    Flickable {
        id: flick
        anchors.fill: parent
        contentWidth: width
        contentHeight: col.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: col
            width: page.colW
            spacing: page.tk.sectionGap
            // the preview rides above the card, like the bar's silhouette does on
            // the Bars route: one glance answers "where will it be".
            DockPreview { width: page.colW }


            Entrance {
                width: page.colW
                index: 0
                SettingCard {
                    width: page.colW
                    title: I18n.tr("DOCK")
                    kana: "\u53f0"

                    SettingRow {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        controlWidth: 54
                        label: I18n.tr("Dock")
                        desc: I18n.tr("An app dock on its own surface, for every bar style.")
                        source: "shell.json"
                        Sw {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            on: Services.Dock.cfg("enabled", false)
                            onToggled: (v) => Services.Dock.setCfg("enabled", v)
                        }
                    }
                    SettingRow {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        divider: true
                        block: true
                        label: I18n.tr("Edge")
                        desc: I18n.tr("Auto: opposite the bar")
                        source: "shell.json"
                        enabled: Services.Dock.cfg("enabled", false)
                        Seg {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            options: ["auto", "top", "bottom", "left", "right"]
                            current: Services.Dock.cfg("edge", "auto")
                            onChose: (k) => Services.Dock.setCfg("edge", k)
                        }
                    }
                    SettingRow {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        divider: true
                        block: true
                        label: I18n.tr("Style")
                        desc: I18n.tr("How the dock is drawn.")
                        source: "shell.json"
                        enabled: Services.Dock.cfg("enabled", false)
                        Chips {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            options: Services.Dock.styleOptions.map(o => o.label)
                            current: page.styleCap(Services.Dock.cfg("style", "islands"))
                            onChose: (label) => Services.Dock.setCfg("style", page.styleKey(label))
                        }
                    }
                    SettingRow {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        divider: true
                        controlWidth: 54
                        label: I18n.tr("Auto-hide")
                        source: "shell.json"
                        enabled: Services.Dock.cfg("enabled", false)
                        Sw {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            on: Services.Dock.cfg("autohide", true)
                            onToggled: (v) => Services.Dock.setCfg("autohide", v)
                        }
                    }
                    SettingRow {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        divider: true
                        controlWidth: 54
                        label: I18n.tr("Magnify")
                        source: "shell.json"
                        enabled: Services.Dock.cfg("enabled", false)
                        Sw {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            on: Services.Dock.cfg("magnify", true)
                            onToggled: (v) => Services.Dock.setCfg("magnify", v)
                        }
                    }
                    SettingRow {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        divider: true
                        controlWidth: 54
                        label: I18n.tr("Frost")
                        source: "shell.json"
                        enabled: Services.Dock.cfg("enabled", false)
                        Sw {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            on: Services.Dock.cfg("frost", true)
                            onToggled: (v) => Services.Dock.setCfg("frost", v)
                        }
                    }
                    SettingRow {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        divider: true
                        controlWidth: 54
                        label: I18n.tr("Depth")
                        source: "shell.json"
                        enabled: Services.Dock.cfg("enabled", false)
                        Sw {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            on: Services.Dock.cfg("shadow", true)
                            onToggled: (v) => Services.Dock.setCfg("shadow", v)
                        }
                    }
                    SettingRow {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        divider: true
                        controlWidth: 54
                        label: I18n.tr("Hover labels")
                        source: "shell.json"
                        enabled: Services.Dock.cfg("enabled", false)
                        Sw {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            on: Services.Dock.cfg("labels", true)
                            onToggled: (v) => Services.Dock.setCfg("labels", v)
                        }
                    }
                    SettingRow {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        divider: true
                        controlWidth: 54
                        label: I18n.tr("Media chip")
                        desc: I18n.tr("Only while audio plays")
                        source: "shell.json"
                        enabled: Services.Dock.cfg("enabled", false)
                        Sw {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            on: Services.Dock.cfg("media", false)
                            onToggled: (v) => Services.Dock.setCfg("media", v)
                        }
                    }
                }
            }

            Entrance {
                width: page.colW
                index: 1
                SettingCard {
                    width: page.colW
                    title: I18n.tr("PINNED APPS")
                    kana: "\u56fa\u5b9a"

                    // A fact the title cannot carry: the dock owns the ordering.
                    UiText {
                    width: parent.width
                        leftPadding: page.tk.pad
                        rightPadding: page.tk.pad
                        topPadding: page.tk.gap
                        bottomPadding: page.tk.gap
                        text: I18n.tr("The dock reorders these by drag.")
                        color: Tokens.inkFaint
                        font.family: Tokens.ui
                        font.pixelSize: Tokens.fSmall
                        wrapMode: Text.WordWrap
                        elide: Text.ElideRight
                        maximumLineCount: 2
                    }

                    Repeater {
                        id: pinRepeater
                        model: Services.Dock.pinnedOrStarter()
                        delegate: PinRow {
                            required property var modelData
                            required property int index
                            cls: modelData
                            last: index === pinRepeater.count - 1
                        }
                    }
                }
            }
        }
    }

    CcScrollRail { root: page.root; flick: flick; z: 5 }
}
