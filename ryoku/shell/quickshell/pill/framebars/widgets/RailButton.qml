pragma ComponentBehavior: Bound

import QtQuick
import "../.." as Pill
import "../../Singletons"

// Shared rail bar-widget button. Parity geometry (contract 02 sec 2, contract 04
// sec 2.1): on a vertical bar (left/right) 48x36, on a horizontal bar
// (top/bottom) 36x48, each grown to fit its content; 10px inner padding;
// radiusWidget corners; a 16px (iconSm) icon by default. The reference state
// layer (on-surface 8% over the surface) and the selected fill (primary bg,
// on-primary fg) are reproduced. Box-shape indicators (network/battery/bluetooth/
// power-profile/vpn) pass interactive:false to drop the hover and the click, and
// scroll is opt-in (audio only) through scrollable.
Item {
    id: root

    required property string edge
    property real scale: 1
    property string icon: ""              // Material Symbols glyph; "" hides it
    property real iconFill: 0
    property string label: ""             // text alternative (clock); "" hides it
    property real iconSize: Theme.iconSm  // nominal content size (16, dock uses 24)
    property real labelSize: 12
    property real labelLineHeight: 0     // FixedHeight line spacing for multi-line labels; 0 = font default
    property bool interactive: true
    property bool active: false           // selected -> primary fill + on-primary fg
    property bool scrollable: false       // audio only: hover-gated vertical wheel

    readonly property bool horizontal: edge === "top" || edge === "bottom"
    readonly property color foreground: active ? Theme.onPrimary : Theme.onSurface
    // widgets that recolour their glyph (recording -> error) override this.
    property color iconColor: root.foreground
    readonly property real pad: 10 * scale

    default property alias content: body.data

    signal clicked()
    signal scrolled(int steps)            // +1 wheel up, -1 wheel down

    // The content sets the natural size; the parity minima are the band-thickness
    // axis (48) and the along-bar axis (36).
    implicitWidth: Math.max((horizontal ? 36 : 48) * scale, body.childrenRect.width + 2 * pad)
    implicitHeight: Math.max((horizontal ? 48 : 36) * scale, body.childrenRect.height + 2 * pad)

    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusWidget
        color: root.active ? Theme.primary
            : (root.interactive && hover.hovered
                ? Qt.rgba(Theme.onSurface.r, Theme.onSurface.g, Theme.onSurface.b, 0.08)
                : "transparent")
    }

    // Centred wrapper: children sit at their natural origin so childrenRect
    // measures them, and the wrapper is centred in the button.
    Item {
        id: body
        x: Math.round((root.width - width) / 2)
        y: Math.round((root.height - height) / 2)
        width: childrenRect.width
        height: childrenRect.height

        Pill.SymbolIcon {
            // The exact glyph set: freedesktop-named symbolic SVGs, sized to
            // the nominal icon box and flattened to the widget's colour.
            visible: root.icon.length > 0
            name: root.icon
            size: root.iconSize * root.scale
            color: root.iconColor
        }

        Text {
            visible: root.label.length > 0
            text: root.label
            horizontalAlignment: Text.AlignHCenter
            color: root.iconColor
            lineHeightMode: root.labelLineHeight > 0 ? Text.FixedHeight : Text.ProportionalHeight
            lineHeight: root.labelLineHeight > 0 ? root.labelLineHeight * root.scale : 1
            font {
                family: Theme.fontPrimary
                pixelSize: root.labelSize * root.scale
                weight: Font.DemiBold
                features: ({ "tnum": 1 })
            }
        }
    }

    HoverHandler { id: hover; enabled: root.interactive }

    MouseArea {
        anchors.fill: parent
        enabled: root.interactive
        acceptedButtons: Qt.LeftButton
        onClicked: root.clicked()
    }

    WheelHandler {
        enabled: root.scrollable
        onWheel: event => root.scrolled(event.angleDelta.y > 0 ? 1 : -1)
    }
}
