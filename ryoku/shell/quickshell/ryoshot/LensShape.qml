import QtQuick
import QtQuick.Shapes

// One spotlight outline in any of its three shapes. Both the dim mask and the
// visible rim draw from this, so a lens and the hole it punches never disagree.
// The unused branch collapses to zero extent rather than being swapped in, which
// keeps the geometry a plain binding.
Item {
    id: lens

    property string shape: "ellipse"
    property color fill: "transparent"
    property color stroke: "transparent"
    property real strokeW: 0

    readonly property bool round: shape === "ellipse"
    readonly property real inset: strokeW / 2
    readonly property real cornerRadius: {
        if (shape !== "rounded") return 0;
        var shorter = Math.min(width, height);
        return Math.min(shorter / 2, Math.max(3, Math.min(28, shorter * 0.12)));
    }

    Shape {
        anchors.fill: parent
        antialiasing: true
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: lens.fill
            strokeColor: lens.stroke
            strokeWidth: lens.strokeW
            PathAngleArc {
                centerX: lens.width / 2
                centerY: lens.height / 2
                radiusX: lens.round ? Math.max(0, lens.width / 2 - lens.inset) : 0
                radiusY: lens.round ? Math.max(0, lens.height / 2 - lens.inset) : 0
                startAngle: 0
                sweepAngle: 360
            }
        }

        ShapePath {
            fillColor: lens.fill
            strokeColor: lens.stroke
            strokeWidth: lens.strokeW
            PathRectangle {
                x: lens.inset
                y: lens.inset
                width: lens.round ? 0 : Math.max(0, lens.width - lens.strokeW)
                height: lens.round ? 0 : Math.max(0, lens.height - lens.strokeW)
                radius: lens.cornerRadius
            }
        }
    }
}
