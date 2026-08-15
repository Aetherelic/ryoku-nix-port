pragma ComponentBehavior: Bound
import QtQuick
import "Singletons"
import Ryoku.Ui.Singletons

// One colour-scheme tile: a rounded card filled with the theme's own surface
// colour, its name at the top, and a row of tall rounded pills of the palette's
// key roles [onSurface, primary, secondary, tertiary, error] -- the colour-combo
// preview. A scheme that ships its own preview art shows that image cropped to
// the card instead, with the name on a placard; everything else uses the pills.
// The outline lifts to the on-surface ink on hover and the primary accent on the
// pick; the applied scheme wears an on-air dot. Dimmed and inert while the switch
// follows the wallpaper (themes disabled).
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
    readonly property string image: (cell.item && cell.item.image) ? cell.item.image : ""
    readonly property bool hasImage: cell.image.length > 0
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

        // preview art, when the scheme ships it: cropped to fill, decoded once.
        Image {
            id: art
            visible: cell.hasImage
            anchors.fill: parent
            anchors.margins: Theme.borderWidth
            asynchronous: true
            cache: true
            fillMode: Image.PreserveAspectCrop
            sourceSize: Qt.size(512, 512)
            source: cell.hasImage ? "file://" + cell.image : ""
        }

        // scrim under the placard so the name stays legible over any art.
        Rectangle {
            visible: cell.hasImage
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            height: Math.round(56 * cell.s)
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0) }
                GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.55) }
            }
        }

        // theme name: top of the card in its own on-surface ink for the pill
        // preview, a bottom-left placard over art so it reads on any image.
        Text {
            id: nameTop
            visible: !cell.hasImage
            anchors { top: parent.top; left: parent.left; right: parent.right }
            anchors.topMargin: Math.round(14 * cell.s)
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
        Text {
            visible: cell.hasImage
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            anchors.leftMargin: Math.round(12 * cell.s)
            anchors.rightMargin: Math.round(12 * cell.s)
            anchors.bottomMargin: Math.round(12 * cell.s)
            text: cell.item ? I18n.tr(cell.item.label) : ""
            color: "white"
            wrapMode: Text.WordWrap
            maximumLineCount: 2
            elide: Text.ElideRight
            font.family: Theme.fontPrimary
            font.pixelSize: Math.round(14 * cell.s)
            font.weight: Font.DemiBold
        }

        // the colour-combo pills: a centred row of tall stadium bars filling the
        // card below the name, one per key role.
        Item {
            id: pillsBox
            visible: !cell.hasImage && cell.pills.length > 0
            anchors.top: nameTop.bottom
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.topMargin: Math.round(12 * cell.s)
            anchors.bottomMargin: Math.round(18 * cell.s)
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
            color: cell.hasImage ? Theme.primary : cell.ink
            border.width: cell.hasImage ? Math.max(1, Math.round(2 * cell.s)) : 0
            border.color: cell.surface
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
