import QtQuick
import "../modules"
import "kit/Routes.js" as Routes
import Ryoku.Ui
import Ryoku.Ui.Singletons

// The studio's left rail: the masthead, the routes in three named groups, and a
// search row at the foot. It replaces the old breadcrumb + QUICK/CONFIGURE tabs
// + Configure landing page all at once: every route is one click away at all
// times, so the panel has no landing screen to get lost on and no mode to be in.
//
// Latin names the route, kanji seals it. The active route is a bone plate, the
// desktop's only emphasis; nothing here is coloured except the 力 seal.
Item {
    id: rail

    property var root
    property var tk
    property string current: ""
    signal chose(string id)
    signal searchRequested()
    signal hubRequested()

    // The rail's groups. Each entry is a route id from kit/Routes.js, so the
    // registry stays the single source of what a route is called and glossed.
    readonly property var groups: [
        { "gloss": "\u5e2f", "name": "BAR", "items": ["bars", "widgets", "logo", "spaces", "pickers"] },
        { "gloss": "\u5353\u4e0a", "name": "DESK", "items": ["dock", "desktop"] },
        { "gloss": "\u5236\u5fa1", "name": "SHELL", "items": ["system", "session"] }
    ]

    // The plate takes its height from whichever is taller, the rail or the page:
    // masthead + the nav groups + the search row + the printed foot, each with the
    // gap it actually sits in. An understated total here is what pushes the
    // barcode against the plate's edge, so it counts the foot's real inset.
    implicitHeight: rail.tk
        ? rail.tk.headH + nav.implicitHeight + rail.tk.gap * 2
          + rail.tk.navH + rail.tk.gap + margin.height + rail.tk.pad * 2
        : 560

    function routeAt(id) {
        for (var i = 0; i < Routes.ROUTES.length; i++)
            if (Routes.ROUTES[i].id === id) return Routes.ROUTES[i];
        return null;
    }

    // the register sheet rides behind the rail only, exactly as the Hub's does:
    // the chrome carries the print texture, the content plate stays clean paper.
    Reg { anchors.fill: parent }

    // ── masthead ─────────────────────────────────────────────────────────────
    Item {
        id: masthead
        anchors { top: parent.top; left: parent.left; right: parent.right }
        height: rail.tk.headH

        Row {
            anchors.left: parent.left
            anchors.leftMargin: rail.tk.pad
            anchors.verticalCenter: parent.verticalCenter
            spacing: rail.tk.gap / 2

            UiText {
                anchors.verticalCenter: parent.verticalCenter
                text: "\u529b"
                color: Tokens.sun
                font.family: Tokens.jp
                font.pixelSize: Tokens.fBody
            }
            UiText {
                anchors.verticalCenter: parent.verticalCenter
                text: "RYOKU"
                color: Tokens.ink
                font.family: Tokens.mono
                font.pixelSize: Tokens.fMicro
                font.letterSpacing: Tokens.trackMark
                font.weight: Font.DemiBold
            }
            UiText {
                anchors.verticalCenter: parent.verticalCenter
                text: "SHELL STUDIO"
                color: Tokens.inkFaint
                font.family: Tokens.mono
                font.pixelSize: Tokens.fTiny
                font.letterSpacing: Tokens.trackLabel
            }
        }
        // the key that opens this panel (Super+Esc -> ryoku:quicksettings), so the
        // shortcut is learnable from the panel itself, like the search's CTRL K.
        Keycap {
            anchors.right: parent.right
            anchors.rightMargin: rail.tk.pad
            anchors.verticalCenter: parent.verticalCenter
            text: "SUPER ESC"
            us: 0.5
            dark: !Tokens.light
        }
        Rectangle {
            anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
            height: 1
            color: Tokens.lineSoft
        }
    }

    // ── the route groups ─────────────────────────────────────────────────────
    Column {
        id: nav
        anchors {
            top: masthead.bottom; topMargin: rail.tk.gap
            left: parent.left; right: parent.right
        }
        spacing: rail.tk.gap

        Repeater {
            model: rail.groups

            delegate: Column {
                id: group
                required property var modelData
                width: nav.width
                spacing: 2

                Row {
                    x: rail.tk.pad
                    height: rail.tk.eyebrowH
                    spacing: rail.tk.gap / 2

                    UiText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: group.modelData.gloss
                        color: Tokens.inkFaint
                        font.family: Tokens.jp
                        font.pixelSize: Tokens.fTiny
                    }
                    UiText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: group.modelData.name
                        color: Tokens.inkFaint
                        font.family: Tokens.mono
                        font.pixelSize: Tokens.fTiny
                        font.letterSpacing: Tokens.trackMark
                        font.weight: Font.DemiBold
                    }
                }

                Repeater {
                    model: group.modelData.items

                    delegate: Rectangle {
                        id: item
                        required property string modelData
                        readonly property var route: rail.routeAt(item.modelData)
                        readonly property bool on: rail.current === item.modelData

                        width: nav.width - rail.tk.gap * 2
                        x: rail.tk.gap
                        height: rail.tk.navH
                        radius: Tokens.radius
                        color: item.on ? Tokens.bone : (ma.containsMouse ? Tokens.tint5 : "transparent")
                        Behavior on color { ColorAnimation { duration: Tokens.snap } }

                        UiText {
                            anchors.left: parent.left
                            anchors.leftMargin: rail.tk.gap
                            anchors.verticalCenter: parent.verticalCenter
                            text: item.route ? I18n.tr(item.route.label) : item.modelData
                            color: item.on ? Tokens.inkOnBone : Tokens.inkDim
                            font.family: Tokens.ui
                            font.pixelSize: Tokens.fBody
                            font.weight: item.on ? Font.DemiBold : Font.Normal
                        }
                        UiText {
                            anchors.right: parent.right
                            anchors.rightMargin: rail.tk.gap
                            anchors.verticalCenter: parent.verticalCenter
                            text: item.route ? (item.route.gloss || "") : ""
                            color: item.on ? Tokens.inkOnBoneDim : Tokens.inkFaint
                            font.family: Tokens.jp
                            font.pixelSize: Tokens.fTiny
                        }
                        MouseArea {
                            id: ma
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: rail.chose(item.modelData)
                        }
                    }
                }
            }
        }
    }

    // ── foot: search, and marginalia in the space under it ───────────────────
    Rectangle {
        id: footLine
        anchors { bottom: foot.top; left: parent.left; right: parent.right }
        height: 1
        color: Tokens.lineSoft
    }
    Item {
        id: foot
        anchors { bottom: margin.top; left: parent.left; right: parent.right }
        height: rail.tk.navH + rail.tk.gap

        Rectangle {
            anchors.centerIn: parent
            width: parent.width - rail.tk.gap * 2
            height: rail.tk.navH
            radius: Tokens.radius
            color: searchMa.containsMouse ? Tokens.tint5 : "transparent"
            Behavior on color { ColorAnimation { duration: Tokens.snap } }

            UiText {
                anchors.left: parent.left
                anchors.leftMargin: rail.tk.gap
                anchors.verticalCenter: parent.verticalCenter
                text: I18n.tr("Search")
                color: Tokens.inkFaint
                font.family: Tokens.ui
                font.pixelSize: Tokens.fSmall
            }
            Keycap {
                anchors.right: parent.right
                anchors.rightMargin: rail.tk.gap / 2
                anchors.verticalCenter: parent.verticalCenter
                text: "CTRL K"
                us: 0.5
                dark: !Tokens.light
            }
            MouseArea {
                id: searchMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: rail.searchRequested()
            }
        }
    }
    // The rail's last inch is genuinely empty, so it carries what the Hub's rail
    // carries: the edition register above a real Code 39 plate. It scans.
    Item {
        id: margin
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        anchors.leftMargin: rail.tk.pad
        anchors.rightMargin: rail.tk.pad
        anchors.bottomMargin: rail.tk.pad
        height: rail.tk.gap + edition.height + rail.tk.gap / 2 + plate.implicitHeight

        Rectangle {
            anchors { left: parent.left; right: parent.right; top: parent.top }
            height: 1
            color: Tokens.lineSoft
        }
        // The studio is the quick surface; the Hub is every setting. A persistent
        // way there, printed where the edition mark used to sit.
        Item {
            id: edition
            anchors { left: parent.left; right: parent.right; top: parent.top; topMargin: rail.tk.gap }
            height: 20
            Row {
                id: hubRow
                anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                spacing: Tokens.s2
                Pixel {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 14; height: 14
                    kind: "torii"
                }
                UiText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: I18n.tr("OPEN THE HUB")
                    color: hubMa.containsMouse ? Tokens.ink : Tokens.inkFaint
                    font.family: Tokens.mono
                    font.pixelSize: Tokens.fTiny
                    font.letterSpacing: Tokens.trackLabel
                }
                UiText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "\u276f"
                    color: Tokens.inkFaint
                    font.family: Tokens.mono
                    font.pixelSize: Tokens.fTiny
                    opacity: hubMa.containsMouse ? 1 : 0.5
                }
            }
            MouseArea {
                id: hubMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: rail.hubRequested()
            }
        }
        // A Code 39 plate cannot be clipped -- lose the stop bars and it stops
        // being a barcode -- so the module width is solved from the rail's own
        // inner width instead of being a constant that overflowed it and printed
        // across the divider into the page.
        Barcode {
            id: plate
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            text: "RYOKU"
            barHeight: 12
            unit: Math.max(0.7, Math.min(1.4, margin.width / ((plate.text.length + 2) * 16)))
        }
    }

    Rectangle {
        anchors { top: parent.top; bottom: parent.bottom; right: parent.right }
        width: 1
        color: Tokens.lineSoft
    }
}
