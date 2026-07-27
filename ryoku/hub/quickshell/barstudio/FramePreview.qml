pragma ComponentBehavior: Bound

import QtQuick
import Ryoku.Ui.Singletons

// The interactive stage: a schematic of the desktop frame and its four rails,
// drawn from the live config. Each edge is a band whose thickness tracks the
// rail's size, filled with one tick per widget grouped into its three zones;
// click a band to select that rail for the inspector. The centre reads out the
// active rail's state, and a rail that differs from the saved config carries a
// dot. The diagram is a picture of the running frame, so a staged edit lands
// here at once, beside the desktop it also repaints.
Item {
    id: fp

    required property var config
    property var committedBars: null
    property string selected: "left"
    property bool frameEnabled: true
    property real frameOpacity: 1
    signal selectEdge(string edge)

    // the edge the pointer is over, so the centre readout previews it before a
    // click commits the selection; empty falls back to the selected rail.
    property string hoverEdge: ""
    readonly property string active: fp.hoverEdge !== "" ? fp.hoverEdge : fp.selected

    CatalogLabels { id: labels }

    function isHorizontal(edge) { return edge === "top" || edge === "bottom"; }
    function zonesOf(edge) { return fp.isHorizontal(edge) ? ["start", "center", "end"] : ["top", "center", "bottom"]; }

    // A band's thickness in the diagram, mapped from the configured size into a
    // readable range: a true-to-pixel band would be a few px and hide its
    // widgets. An off rail is a thin ghost; off/empty read by emphasis, not size.
    function bandPx(edge) {
        const rail = fp.config.rails[edge];
        const horiz = fp.isHorizontal(edge);
        if (!rail || !rail.enabled) return horiz ? 10 : 12;
        const min = horiz ? 16 : 24;
        const max = horiz ? 96 : 112;
        const lo = horiz ? 18 : 20;
        const hi = horiz ? 40 : 48;
        const k = Math.max(0, Math.min(1, (rail.size - min) / (max - min)));
        return Math.round(lo + (hi - lo) * k);
    }
    readonly property var thick: ({
        top: fp.bandPx("top"), bottom: fp.bandPx("bottom"),
        left: fp.bandPx("left"), right: fp.bandPx("right")
    })
    function countOf(edge) {
        const rail = fp.config.rails[edge];
        if (!rail) return 0;
        const zs = fp.zonesOf(edge);
        let n = 0;
        for (let i = 0; i < zs.length; ++i) n += (rail[zs[i]] || []).length;
        return n;
    }
    function railModified(edge) {
        if (!fp.committedBars || !fp.committedBars.rails) return false;
        return JSON.stringify(fp.config.rails[edge]) !== JSON.stringify(fp.committedBars.rails[edge]);
    }
    function stateLine(edge) {
        const rail = fp.config.rails[edge];
        if (!rail || !rail.enabled) return qsTr("off");
        const vis = rail.reveal ? qsTr("pinned") : qsTr("auto-hide");
        const n = fp.countOf(edge);
        return n === 0 ? qsTr("on · empty · %1").arg(vis) : qsTr("on · %1 · %2").arg(n).arg(vis);
    }

    // the largest 16:10 screen that fits, centred, so the page can hand this any
    // box and the diagram keeps its proportions.
    readonly property real aspect: 16 / 10
    readonly property real screenW: Math.min(fp.width, fp.height * fp.aspect)
    readonly property real screenH: fp.screenW / fp.aspect

    Rectangle {
        id: screen
        width: fp.screenW
        height: fp.screenH
        anchors.centerIn: parent
        radius: Tokens.radius
        color: Tokens.paper
        border.width: Tokens.border
        border.color: Tokens.line

        // frame chrome mirror: the inset band shows the two working chrome knobs
        // (draw toggle by presence, opacity by fade) on the diagram itself.
        Rectangle {
            anchors.fill: parent
            anchors.margins: 3
            radius: Tokens.radius
            color: "transparent"
            visible: fp.frameEnabled
            opacity: fp.frameOpacity
            border.width: 2
            border.color: Tokens.line
        }

        // the desktop area, with a live readout of the active rail
        Column {
            anchors.centerIn: parent
            spacing: 2
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "力"
                color: Tokens.lineSoft
                font.family: Tokens.jp
                font.pixelSize: Math.round(Math.min(screen.width, screen.height) * 0.26)
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: labels.edge(fp.active).toUpperCase() + " " + qsTr("RAIL")
                color: Tokens.inkMuted
                font.family: Tokens.ui
                font.pixelSize: Tokens.fMicro
                font.weight: Font.Medium
                font.letterSpacing: Tokens.trackLabel
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: fp.stateLine(fp.active)
                color: Tokens.inkFaint
                font.family: Tokens.mono
                font.pixelSize: Tokens.fTiny
            }
        }

        // the four rail bands
        Repeater {
            model: ["top", "bottom", "left", "right"]
            delegate: Rectangle {
                id: band
                required property string modelData
                readonly property bool horiz: fp.isHorizontal(band.modelData)
                readonly property var rail: fp.config.rails[band.modelData]
                readonly property bool on: !!(band.rail && band.rail.enabled)
                readonly property bool sel: fp.selected === band.modelData
                readonly property real t: fp.thick[band.modelData]

                objectName: "rail-band-" + band.modelData
                x: band.modelData === "right" ? screen.width - band.t : 0
                y: band.modelData === "bottom" ? screen.height - band.t : (band.horiz ? 0 : fp.thick.top)
                width: band.horiz ? screen.width : band.t
                height: band.horiz ? band.t : screen.height - fp.thick.top - fp.thick.bottom

                radius: Tokens.radius
                color: band.sel ? Tokens.tint10 : (band.on ? Tokens.tint5 : "transparent")
                border.width: band.sel ? 2 : Tokens.border
                border.color: band.sel ? Tokens.bone : (band.on ? Tokens.line : Tokens.lineSoft)
                opacity: band.on ? 1 : 0.7
                Behavior on color { ColorAnimation { duration: Tokens.snap } }
                Behavior on border.color { ColorAnimation { duration: Tokens.snap } }

                // one tick per widget, grouped into the three zones (thirds) and
                // held against each zone's own end, mirroring the real rail.
                Repeater {
                    model: fp.zonesOf(band.modelData)
                    delegate: Item {
                        id: zoneBox
                        required property string modelData
                        required property int index
                        readonly property var ids: band.rail ? (band.rail[zoneBox.modelData] || []) : []
                        x: band.horiz ? band.width / 3 * zoneBox.index : 0
                        y: band.horiz ? 0 : band.height / 3 * zoneBox.index
                        width: band.horiz ? band.width / 3 : band.width
                        height: band.horiz ? band.height : band.height / 3

                        Row {
                            visible: band.horiz
                            spacing: 3
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: zoneBox.modelData === "start" ? parent.left : undefined
                            anchors.right: zoneBox.modelData === "end" ? parent.right : undefined
                            anchors.horizontalCenter: zoneBox.modelData === "center" ? parent.horizontalCenter : undefined
                            anchors.leftMargin: 7
                            anchors.rightMargin: 7
                            Repeater {
                                model: zoneBox.ids.length
                                delegate: Rectangle {
                                    width: 5
                                    height: Math.max(6, band.t - 12)
                                    radius: Tokens.radius
                                    color: band.sel ? Tokens.ink : Tokens.inkDim
                                }
                            }
                        }
                        Column {
                            visible: !band.horiz
                            spacing: 3
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.top: zoneBox.modelData === "top" ? parent.top : undefined
                            anchors.bottom: zoneBox.modelData === "bottom" ? parent.bottom : undefined
                            anchors.verticalCenter: zoneBox.modelData === "center" ? parent.verticalCenter : undefined
                            anchors.topMargin: 7
                            anchors.bottomMargin: 7
                            Repeater {
                                model: zoneBox.ids.length
                                delegate: Rectangle {
                                    width: Math.max(6, band.t - 12)
                                    height: 5
                                    radius: Tokens.radius
                                    color: band.sel ? Tokens.ink : Tokens.inkDim
                                }
                            }
                        }
                    }
                }

                // a rail edited away from the saved config carries a dot
                Rectangle {
                    visible: fp.railModified(band.modelData)
                    width: 5
                    height: 5
                    radius: 2.5
                    color: Tokens.sun
                    x: 5
                    y: 5
                }

                HoverHandler {
                    cursorShape: Qt.PointingHandCursor
                    onHoveredChanged: fp.hoverEdge = hovered ? band.modelData
                        : (fp.hoverEdge === band.modelData ? "" : fp.hoverEdge)
                }
                TapHandler { onTapped: fp.selectEdge(band.modelData) }
            }
        }
    }
}
