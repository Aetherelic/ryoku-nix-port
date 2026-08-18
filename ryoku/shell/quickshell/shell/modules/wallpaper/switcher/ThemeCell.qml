pragma ComponentBehavior: Bound
import QtQuick
import "Singletons"
import Ryoku.Ui.Singletons

// One colour-scheme tile, rendered live from the palette: the scheme's surface
// as the card, a faint accent sheen, its name in the scheme's own ink, a mini
// "bar wearing the palette" (a launcher pill + role dots), and a row of tall
// pills of the key roles [onSurface, primary, secondary, tertiary, error] as the
// hero -- a Ryoku desktop in miniature, the same everywhere whether the scheme is
// built in or installed. The outline lifts to the on-surface ink on hover and the
// primary accent on the pick; the applied scheme wears an on-air dot. Dimmed and
// inert while the switch follows the wallpaper (themes disabled).
Item {
    id: cell

    required property real s
    required property var item          // theme card { id, label, sw[7], dark, image? }
    required property color bg           // stage colour, for the belt cell API
    property bool topRow: true           // unused; belt cell API
    property bool selected: false        // hovered / centred pick
    property bool active: false          // the applied scheme
    property bool interactive: true      // false while following the wallpaper
    signal entered()
    signal chosen()

    readonly property var sw: cell.item ? cell.item.sw : []
    readonly property color surface: cell.sw.length > 0 ? cell.sw[0] : Theme.surfaceContainer
    readonly property color ink: cell.sw.length > 1 ? cell.sw[1] : Theme.onSurface
    readonly property color primary:   cell.sw.length > 2 ? cell.sw[2] : Theme.primary
    readonly property color secondary: cell.sw.length > 3 ? cell.sw[3] : cell.primary
    readonly property color tertiary:  cell.sw.length > 4 ? cell.sw[4] : cell.primary
    readonly property color scErr:     cell.sw.length > 5 ? cell.sw[5] : Theme.error
    readonly property color outline:   cell.sw.length > 6 ? cell.sw[6] : Theme.outline
    readonly property bool dark: cell.item ? !!cell.item.dark : true
    // a raised surface: the scheme's own surface nudged toward its ink.
    readonly property color lift: Qt.rgba(cell.surface.r + (cell.ink.r - cell.surface.r) * 0.10,
                                          cell.surface.g + (cell.ink.g - cell.surface.g) * 0.10,
                                          cell.surface.b + (cell.ink.b - cell.surface.b) * 0.10, 1)
    // the five colour-combo pills: the theme's ink plus its four accents.
    readonly property var pills: cell.sw.length >= 6
        ? [cell.sw[1], cell.sw[2], cell.sw[3], cell.sw[4], cell.sw[5]] : []

    scale: cell.selected ? 1.03 : 1.0
    transformOrigin: Item.Center
    z: cell.selected ? 2 : 1
    Behavior on scale { NumberAnimation { duration: Motion.thumbHover; easing.type: Motion.easeType; easing.bezierCurve: Motion.easeCurve } }

    Rectangle {
        id: frame
        anchors.fill: parent
        radius: Theme.radiusWidget
        color: cell.surface
        clip: true
        border.width: Theme.borderWidth
        border.color: cell.selected ? Theme.primary : (hover.hovered ? Theme.onSurface : Theme.outline)
        Behavior on border.color { ColorAnimation { duration: Motion.thumbHover; easing.type: Motion.easeType; easing.bezierCurve: Motion.easeCurve } }

        // subtle top sheen toward the accent -- evokes the desktop's wallpaper
        // glow without a shader; one gradient, no cost.
        Rectangle {
            anchors { left: parent.left; right: parent.right; top: parent.top }
            anchors.margins: Theme.borderWidth
            height: Math.round(parent.height * 0.42)
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(cell.primary.r, cell.primary.g, cell.primary.b, cell.dark ? 0.14 : 0.08) }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }

        // theme name: top of the card, in the scheme's own on-surface ink.
        Text {
            id: nameTop
            anchors { top: parent.top; left: parent.left; right: parent.right }
            anchors.topMargin: Math.round(12 * cell.s)
            anchors.leftMargin: Math.round(10 * cell.s)
            anchors.rightMargin: Math.round(10 * cell.s)
            text: cell.item ? I18n.tr(cell.item.label) : ""
            color: cell.ink
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            maximumLineCount: 2
            elide: Text.ElideRight
            font.family: Theme.fontPrimary
            font.pixelSize: Math.round(14 * cell.s)
            font.weight: Font.DemiBold
        }

        // the palette bar: the desktop's signature "bar wearing the whole palette"
        // in miniature -- a launcher pill in the accent, then a cluster of role
        // dots. This is what makes the tile read as a Ryoku desktop, not a swatch.
        Rectangle {
            id: miniBar
            anchors { left: parent.left; right: parent.right; top: nameTop.bottom }
            anchors.topMargin: Math.round(12 * cell.s)
            anchors.leftMargin: Math.round(14 * cell.s)
            anchors.rightMargin: Math.round(14 * cell.s)
            height: Math.round(22 * cell.s)
            radius: Math.round(7 * cell.s)
            color: cell.lift
            border.width: Math.max(1, Math.round(cell.s))
            border.color: Qt.rgba(cell.outline.r, cell.outline.g, cell.outline.b, 0.7)

            Rectangle {
                anchors.left: parent.left; anchors.leftMargin: Math.round(6 * cell.s)
                anchors.verticalCenter: parent.verticalCenter
                width: Math.round(26 * cell.s); height: Math.round(10 * cell.s)
                radius: height / 2; color: cell.primary
            }
            Row {
                anchors.right: parent.right; anchors.rightMargin: Math.round(7 * cell.s)
                anchors.verticalCenter: parent.verticalCenter
                spacing: Math.round(5 * cell.s)
                Repeater {
                    model: [cell.secondary, cell.tertiary, cell.scErr]
                    delegate: Rectangle {
                        required property color modelData
                        width: Math.round(9 * cell.s); height: width; radius: width / 2; color: modelData
                    }
                }
            }
        }

        // hero: the five role pills as tall stadiums, filling the card below the bar.
        Item {
            id: pillsBox
            visible: cell.pills.length > 0
            anchors.top: miniBar.bottom
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.topMargin: Math.round(12 * cell.s)
            anchors.bottomMargin: Math.round(16 * cell.s)
            anchors.leftMargin: Math.round(16 * cell.s)
            anchors.rightMargin: Math.round(16 * cell.s)
            readonly property real gap: Math.round(7 * cell.s)
            readonly property real pillW: (width - gap * (cell.pills.length - 1)) / cell.pills.length

            Row {
                anchors.centerIn: parent
                height: parent.height
                spacing: pillsBox.gap
                Repeater {
                    model: cell.pills
                    delegate: Rectangle {
                        required property color modelData
                        width: pillsBox.pillW
                        height: parent.height
                        radius: width / 2
                        color: modelData
                    }
                }
            }
        }

        // on-air dot for the applied scheme, top-right.
        Rectangle {
            visible: cell.active
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Math.round(9 * cell.s)
            width: Math.round(11 * cell.s)
            height: width
            radius: width / 2
            color: cell.ink
        }
    }

    // dim + inert while following the wallpaper: themes are disabled.
    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusWidget
        color: "black"
        opacity: cell.interactive ? 0 : 0.5
        visible: opacity > 0.001
        Behavior on opacity { NumberAnimation { duration: Motion.thumbHover } }
    }

    HoverHandler {
        id: hover
        enabled: cell.interactive
        cursorShape: Qt.PointingHandCursor
        onHoveredChanged: if (hovered) cell.entered()
    }
    MouseArea { anchors.fill: parent; enabled: cell.interactive; cursorShape: Qt.PointingHandCursor; onClicked: cell.chosen() }
}
