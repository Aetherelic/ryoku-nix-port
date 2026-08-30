pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import "Singletons"

// The wallpaper's cutout subject, drawn in front of the desktop widgets
// (docs/depth.md). No MouseArea, so widget drag and the desktop menu pass
// through. The fill switch mirrors wallpaper/Backdrop.fillModeFor so the cutout
// crops identically to the wallpaper behind it.
Item {
    id: root

    property string url: ""
    property string fit: "Cover"
    property bool composing: false // full strength while placing

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
            return Image.PreserveAspectCrop;
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
        opacity: status === Image.Ready ? 1 : 0
        Behavior on opacity {
            NumberAnimation {
                duration: 320
                easing.type: Easing.OutCubic
            }
        }
    }

    // Edge feather and an optional cast shadow set the cutout into the scene; the
    // FBO stays off when both are zero.
    layer.enabled: Config.feather > 0.001 || Config.shadow > 0.001
    layer.effect: MultiEffect {
        blurEnabled: Config.feather > 0.001
        blurMax: 16
        blur: Config.feather
        shadowEnabled: Config.shadow > 0.001
        shadowColor: Qt.rgba(0, 0, 0, 0.72 * Config.shadow)
        shadowBlur: 0.55 + 0.45 * Config.shadow
        shadowVerticalOffset: Math.round(20 * Config.shadow)
        shadowHorizontalOffset: Math.round(12 * Config.shadow)
    }
}
