pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import "Singletons"

// The wallpaper's subject, cut out into a transparent PNG by the daemon and
// drawn in front of the desktop widgets (docs/depth.md). A plain Image with no
// MouseArea, so widget drag and the desktop right-click menu pass straight
// through. It crops exactly like the wallpaper backdrop (this switch mirrors
// wallpaper/Backdrop.fillModeFor - keep the two in sync) so the cutout stays
// pixel-locked to the picture behind it and never reveals a seam.
Item {
    id: root

    // the cutout url the daemon published for this screen (file://...?v=rev),
    // "" when depth is off, still generating, a video, or the engine is absent.
    property string url: ""
    // the wallpaper's content fit, so the cutout crops identically.
    property string fit: "Cover"
    // full strength while composing, so the user sees the true overlap as they
    // drag the clock into place even mid-tune.
    property bool composing: false

    anchors.fill: parent
    visible: root.url !== "" && Config.enabled
    opacity: root.composing ? 1.0 : Config.lift
    Behavior on opacity {
        NumberAnimation {
            duration: 200
            easing.type: Easing.OutCubic
        }
    }

    function _fillMode(im) {
        switch (root.fit) {
        case "Contain":
            return Image.PreserveAspectFit;
        case "Fill":
            return Image.Stretch;
        case "ScaleDown":
            return (im.sourceSize.width <= root.width && im.sourceSize.height <= root.height) ? Image.Pad : Image.PreserveAspectFit;
        default:
            return Image.PreserveAspectCrop; // Cover
        }
    }

    Image {
        id: img
        anchors.fill: parent
        source: root.url
        cache: false
        asynchronous: true
        fillMode: root._fillMode(img)
        sourceSize.width: root.width
        sourceSize.height: root.height
        // fade the cutout in when it finishes decoding, so a regenerated overlay
        // (new wallpaper or model) arrives softly instead of popping.
        opacity: status === Image.Ready ? 1 : 0
        Behavior on opacity {
            NumberAnimation {
                duration: 320
                easing.type: Easing.OutCubic
            }
        }
    }

    // A subtle feather so the cutout edge sets into the scene rather than looking
    // pasted; the FBO is off entirely at zero.
    layer.enabled: Config.feather > 0.001
    layer.effect: MultiEffect {
        blurEnabled: true
        blurMax: 16
        blur: Config.feather
    }
}
