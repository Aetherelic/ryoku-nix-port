pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import "Singletons"

// The desktop right-click chrome, shared by every context menu the widget
// layer spawns (the desktop and clock menu, and each plugin tile's menu). One
// surface card in the quick-settings sidebar idiom: a lifted plate with a
// masthead eyebrow, a soft drop shadow, ink-washed rows and a scale+fade
// settle on open. A caller sets `title` and the click point (px, py) and fills
// the card with MenuRow / MenuSection / MenuChip; the card clamps itself on
// screen, pins the masthead, scrolls its overflow, and dismisses on any click
// outside it. Fills the host window so the click-away catcher covers the
// desktop and a tile that vanishes never drags the menu down with it.
Item {
    id: menu

    // A MenuRow finds its enclosing menu by this marker to close on trigger.
    readonly property bool ryoMenu: true

    anchors.fill: parent
    visible: menu.open || panel.opacity > 0.01

    property bool open: false
    property string title: ""
    property string gloss: ""
    property real px: 0
    property real py: 0
    property real cardWidth: 248

    // caller rows land in this column; the masthead sits above it, pinned.
    default property alias content: col.data

    function close() { menu.open = false; }

    // click-away: any press outside the card dismisses.
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onPressed: menu.close()
    }

    MultiEffect {
        source: panel
        anchors.fill: panel
        visible: !Performance.shadowsDisabled && panel.opacity > 0.01
        shadowEnabled: true
        shadowColor: Theme.shadow
        shadowBlur: 1.0
        shadowVerticalOffset: 12
        blurMax: 48
        autoPaddingEnabled: true
    }

    Rectangle {
        id: panel
        readonly property int pad: Theme.s4
        readonly property int gap: Theme.s3
        readonly property real fullHeight: panel.pad
            + (mast.visible ? mast.height + panel.gap : 0)
            + col.implicitHeight + panel.pad

        x: Math.max(Theme.s2, Math.min(menu.px, menu.width - width - Theme.s2))
        y: Math.max(Theme.s2, Math.min(menu.py, menu.height - height - Theme.s2))
        width: menu.cardWidth
        height: Math.min(panel.fullHeight, menu.height - Theme.s2 * 2)
        radius: Theme.menuRadius
        color: Theme.surface
        border.width: 1
        border.color: Theme.line

        transformOrigin: Item.TopLeft
        scale: menu.open ? 1 : 0.96
        opacity: menu.open ? 1 : 0
        Behavior on scale { NumberAnimation { duration: Theme.quick; easing.type: Theme.ease } }
        Behavior on opacity { NumberAnimation { duration: Theme.quick } }

        // masthead eyebrow: the route's kanji gloss, its tracked Latin scope, and
        // a hairline leader running to the card edge. Pinned above the scroller.
        Row {
            id: mast
            visible: menu.title.length > 0
            anchors { top: parent.top; left: parent.left; right: parent.right; margins: panel.pad }
            spacing: Theme.s2
            Text {
                id: seal
                visible: menu.gloss.length > 0
                anchors.verticalCenter: parent.verticalCenter
                text: menu.gloss
                color: Theme.faint
                font.family: Theme.fontJp
                font.pixelSize: Theme.fBody
            }
            Text {
                id: cap
                anchors.verticalCenter: parent.verticalCenter
                text: menu.title.toUpperCase()
                color: Theme.inkDim
                font.family: Theme.font
                font.pixelSize: Theme.fMicro
                font.weight: Font.DemiBold
                font.letterSpacing: Theme.trackMark
            }
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.max(0, mast.width - (seal.visible ? seal.width + mast.spacing : 0) - cap.width - mast.spacing)
                height: 1
                color: Theme.line
            }
        }

        Flickable {
            id: flick
            anchors {
                top: mast.visible ? mast.bottom : parent.top
                topMargin: mast.visible ? panel.gap : panel.pad
                left: parent.left; leftMargin: panel.pad
                right: parent.right; rightMargin: panel.pad
                bottom: parent.bottom; bottomMargin: panel.pad
            }
            contentHeight: col.implicitHeight
            clip: true
            // Non-interactive so a press on a row/chip is never stolen for a
            // flick (that swallows the tap); a WheelHandler scrolls the rare
            // menu that overflows the screen instead.
            interactive: false
            boundsBehavior: Flickable.StopAtBounds

            WheelHandler {
                onWheel: (e) => {
                    const maxY = Math.max(0, flick.contentHeight - flick.height);
                    flick.contentY = Math.max(0, Math.min(maxY, flick.contentY - e.angleDelta.y));
                }
            }

            Column {
                id: col
                width: flick.width
                spacing: Theme.s1
            }
        }
    }
}
