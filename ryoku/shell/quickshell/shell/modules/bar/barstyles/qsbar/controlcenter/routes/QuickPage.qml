import QtQuick
import Quickshell
import "../kit"
import "../../modules"
import Ryoku.Ui.Singletons

// QUICK page - 1:1 port of Shibumi's QuickControlPage, in qsbar's palette.
//   barLanding: a live bar-surface preview card (the active barShellStyle form)
//   that opens the Bars route on click. actionDeck: two 4-row columns of thin
//   action rows (icon + label + detail) with a dotted rail canvas between them.
//   Hover is neutral; the seal accent marks only the active row, the routes,
//   and destructive confirms.
Item {
    id: page
    property var root: null
    property var cc: null
    implicitHeight: col.implicitHeight

    // ── token shortcuts (all from root; fallbacks only while root is null) ──
    readonly property color fg: root ? root.ink : "#cccccc"
    readonly property color acc: root ? root.seal : "#c4746e"
    readonly property color danger: root ? root.sealRaw : "#c4746e"
    readonly property color idleFill: root ? root.fillIdle : "#111111"
    readonly property color hoverFill: root ? Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.06) : "#161616"
    readonly property color idleBorder: root ? root.sep : "#333333"
    readonly property color hoverBorder: root ? Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.28) : "#444444"
    readonly property int ctlR: root ? root.tileRadius : 6
    readonly property string mono: root ? root.mono : "monospace"
    readonly property int rowH: 44
    readonly property int gap: 8
    readonly property int pad: 12
    readonly property int deckH: rowH * 4 + gap * 3

    // ── state ──
    property int hoveredLeft: -1
    property int hoveredRight: -1
    property string pending: ""

    readonly property string activeForm: root ? String(root.barShellStyle || "full") : "full"
    function cap(s) { return s && s.length ? s.charAt(0).toUpperCase() + s.slice(1) : s }
    readonly property string formLabel: page.cap(page.activeForm)

    readonly property var leftActions: [
        { id: "reload",     label: "Reload",     detail: "Reload the shell", glyph: "refresh" },
        { id: "bars",       label: "Bars",       detail: "Configure",        glyph: "view_agenda" },
        { id: "appearance", label: "Appearance", detail: "Widgets & icons",  glyph: "brush" },
        { id: "pickers",    label: "Pickers",    detail: "Media & images",   glyph: "collections" }
    ]
    readonly property var rightActions: [
        { id: "lock",     label: "Lock",     detail: "Lock session", glyph: "lock" },
        { id: "suspend",  label: "Suspend",  detail: "Sleep",        glyph: "bedtime" },
        { id: "reboot",   label: "Reboot",   detail: "System",       glyph: "restart_alt",       destructive: true },
        { id: "shutdown", label: "Shutdown", detail: "Power off",    glyph: "power_settings_new", destructive: true }
    ]

    function activateAction(id) {
        if (id === "reboot" || id === "shutdown") {
            if (page.pending === id) { page.confirm(); return }
            page.pending = id; confirmTimer.restart(); return
        }
        page.pending = ""
        if (id === "reload") { Quickshell.reload(false); if (page.cc) page.cc.close() }
        else if (id === "bars" && page.cc) page.cc.open("bars")
        else if (id === "appearance" && page.cc) page.cc.open("appearance")
        else if (id === "pickers" && page.cc) page.cc.open("pickers")
        else if (id === "lock") { Quickshell.execDetached(["hyprlock"]); if (page.cc) page.cc.close() }
        else if (id === "suspend") { Quickshell.execDetached(["systemctl", "suspend"]); if (page.cc) page.cc.close() }
    }
    function confirm() {
        var id = page.pending
        page.pending = ""; confirmTimer.stop()
        if (id === "reboot") Quickshell.execDetached(["systemctl", "reboot"])
        else if (id === "shutdown") Quickshell.execDetached(["systemctl", "poweroff"])
        if (page.cc) page.cc.close()
    }
    Timer { id: confirmTimer; interval: 5000; onTriggered: page.pending = "" }


    // ── a thin action row (icon + label + detail; destructive → 2-tap confirm) ──
    component ActionRow: Rectangle {
        id: ar
        required property var modelData
        required property int index
        required property string side
        readonly property bool confirming: page.pending === String(ar.modelData.id || "")
        width: parent ? parent.width : 0
        radius: page.ctlR
        color: ar.confirming ? Qt.rgba(page.danger.r, page.danger.g, page.danger.b, 0.11)
                             : (arMa.containsMouse ? page.hoverFill : page.idleFill)
        border.width: 1
        border.color: ar.confirming ? page.danger
                                    : (arMa.containsMouse ? page.hoverBorder : page.idleBorder)
        Behavior on color { ColorAnimation { duration: 120 } }

        Row {
            anchors.left: parent.left; anchors.leftMargin: 9
            anchors.right: parent.right; anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8
            IconText {
                anchors.verticalCenter: parent.verticalCenter
                width: 18; horizontalAlignment: Text.AlignHCenter
                text: ar.modelData.glyph
                color: ar.confirming ? page.danger : page.fg
                opacity: 0.88
                font.pixelSize: 12
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 0
                UiText {
                    text: ar.confirming ? (I18n.tr("Confirm ") + I18n.tr(ar.modelData.label)) : I18n.tr(ar.modelData.label)
                    color: ar.confirming ? page.danger : page.fg
                    font.family: page.mono; font.pixelSize: 12; font.weight: Font.DemiBold
                }
                UiText {
                    text: ar.confirming ? I18n.tr("Click again") : ar.modelData.detail
                    color: page.fg; opacity: 0.42
                    font.family: page.mono; font.pixelSize: 10
                }
            }
        }
        MouseArea {
            id: arMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onEntered: { if (ar.side === "left") page.hoveredLeft = ar.index; else page.hoveredRight = ar.index }
            onExited: {
                if (ar.side === "left" && page.hoveredLeft === ar.index) page.hoveredLeft = -1
                if (ar.side === "right" && page.hoveredRight === ar.index) page.hoveredRight = -1
            }
            onClicked: page.activateAction(ar.modelData.id)
        }
    }

    Flickable {
        id: flick
        anchors.fill: parent
        contentWidth: width
        contentHeight: col.height
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: col
            width: parent.width
            spacing: page.gap

            // ── barLanding: live preview of the active bar form → opens Bars ──
            Item {
                id: barLanding
                width: parent.width
                height: page.rowH * 2 + page.gap * 2

                Rectangle {
                    id: preview
                    anchors.fill: parent
                    radius: page.ctlR
                    color: pvMa.containsMouse ? page.hoverFill : page.idleFill
                    border.width: 1
                    border.color: pvMa.containsMouse ? page.hoverBorder : page.idleBorder
                    Behavior on color { ColorAnimation { duration: 120 } }

                    Column {
                        anchors.left: parent.left; anchors.top: parent.top
                        anchors.leftMargin: page.pad; anchors.topMargin: page.pad
                        anchors.right: parent.right; anchors.rightMargin: page.pad
                        spacing: 1
                        UiText {
                            text: I18n.tr("ACTIVE BAR")
                            color: page.fg; opacity: 0.5
                            font.family: page.mono; font.pixelSize: 10; font.letterSpacing: 1
                        }
                        UiText {
                            text: page.formLabel
                            color: page.fg
                            font.family: page.mono; font.pixelSize: 12; font.weight: Font.DemiBold
                        }
                    }
                    BarSilhouette {
                        anchors.left: parent.left; anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.margins: page.pad
                        height: page.rowH
                        root: page.root
                        form: page.activeForm
                    }
                    MouseArea {
                        id: pvMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: if (page.cc) page.cc.open("bars")
                    }
                }
            }

            // ── actionDeck: two action columns + dotted rail ──
            Item {
                id: actionDeck
                width: parent.width
                height: page.deckH

                Column {
                    id: leftCol
                    anchors.left: parent.left
                    width: Math.min(270, parent.width * 0.42)
                    height: parent.height
                    spacing: page.gap
                    Repeater {
                        model: page.leftActions
                        delegate: ActionRow {
                            side: "left"
                            height: page.rowH
                        }
                    }
                }

                Canvas {
                    id: railCanvas
                    x: leftCol.width
                    width: 34
                    height: parent.height
                    z: 2
                    antialiasing: true
                    onPaint: {
                        var ctx = getContext("2d")
                        ctx.reset(); ctx.clearRect(0, 0, width, height)
                        var rowH = page.rowH
                        var cx = width / 2
                        var idle = Qt.rgba(page.fg.r, page.fg.g, page.fg.b, 0.18)
                        ctx.beginPath(); ctx.moveTo(cx, rowH / 2); ctx.lineTo(cx, height - rowH / 2)
                        ctx.strokeStyle = idle; ctx.lineWidth = 1; ctx.stroke()
                        for (var i = 0; i < 4; i++) {
                            var y = rowH / 2 + i * (rowH + page.gap)
                            var lh = page.hoveredLeft === i
                            var rh = page.hoveredRight === i
                            if (lh) {
                                ctx.beginPath(); ctx.moveTo(0, y); ctx.bezierCurveTo(width * 0.25, y, width * 0.32, y, cx, y)
                                ctx.strokeStyle = page.acc; ctx.lineWidth = 1.35; ctx.stroke()
                                ctx.beginPath(); ctx.arc(0, y, 3.4, 0, Math.PI * 2); ctx.fillStyle = page.acc; ctx.fill()
                            }
                            if (rh) {
                                ctx.beginPath(); ctx.moveTo(cx, y); ctx.bezierCurveTo(width * 0.68, y, width * 0.75, y, width, y)
                                ctx.strokeStyle = page.acc; ctx.lineWidth = 1.35; ctx.stroke()
                                ctx.beginPath(); ctx.arc(width, y, 3.4, 0, Math.PI * 2); ctx.fillStyle = page.acc; ctx.fill()
                            }
                            ctx.beginPath(); ctx.arc(cx, y, (lh || rh) ? 3.2 : 2.7, 0, Math.PI * 2)
                            ctx.fillStyle = (lh || rh) ? page.acc : idle; ctx.fill()
                        }
                    }
                    Connections {
                        target: page
                        function onHoveredLeftChanged() { railCanvas.requestPaint() }
                        function onHoveredRightChanged() { railCanvas.requestPaint() }
                        function onAccChanged() { railCanvas.requestPaint() }
                    }
                    onWidthChanged: requestPaint()
                    onHeightChanged: requestPaint()
                    Component.onCompleted: requestPaint()
                }

                Column {
                    id: rightCol
                    anchors.right: parent.right
                    width: actionDeck.width - leftCol.width - railCanvas.width
                    height: parent.height
                    spacing: page.gap
                    Repeater {
                        model: page.rightActions
                        delegate: ActionRow {
                            side: "right"
                            height: page.rowH
                        }
                    }
                }
            }
        }
    }

    CcScrollRail { root: page.root; flick: flick; z: 5 }
}
