import QtQuick
import QtQuick.Effects

Item {
    id: media

    property url source: ""
    property bool immersive: false
    property bool active: true

    readonly property string cleanSource: String(source).split(/[?#]/)[0].toLowerCase()
    readonly property bool animated: cleanSource.endsWith(".gif")

    clip: true

    Image {
        id: bleed
        anchors.fill: parent
        source: media.immersive && media.source !== "" ? media.source : ""
        sourceSize: Qt.size(Math.max(1, Math.ceil(width)), Math.max(1, Math.ceil(height)))
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: true
        retainWhileLoading: true
        smooth: true
        visible: false
    }

    MultiEffect {
        anchors.fill: parent
        source: bleed
        scale: 1.12
        visible: media.immersive && bleed.status === Image.Ready
        blurEnabled: visible
        blur: 0.96
        blurMax: 48
        saturation: 0.12
    }

    Rectangle {
        anchors.fill: parent
        visible: media.immersive
        color: "#26000000"
    }

    Image {
        id: still
        anchors.fill: parent
        anchors.margins: media.immersive
                ? Math.round(Math.min(media.width, media.height) * 0.025) : 0
        source: !media.animated ? media.source : ""
        sourceSize: Qt.size(Math.max(1, Math.ceil(media.width * 2)),
                            Math.max(1, Math.ceil(media.height * 2)))
        fillMode: media.immersive ? Image.PreserveAspectFit : Image.PreserveAspectCrop
        asynchronous: true
        cache: true
        retainWhileLoading: true
        smooth: true
        visible: source !== "" && status === Image.Ready
        opacity: visible ? 1 : 0

        Behavior on opacity { NumberAnimation { duration: 180 } }
    }

    AnimatedImage {
        id: moving
        anchors.fill: parent
        anchors.margins: media.immersive
                ? Math.round(Math.min(media.width, media.height) * 0.025) : 0
        source: media.animated ? media.source : ""
        sourceSize: Qt.size(Math.max(1, Math.ceil(media.width * 2)),
                            Math.max(1, Math.ceil(media.height * 2)))
        fillMode: media.immersive ? Image.PreserveAspectFit : Image.PreserveAspectCrop
        asynchronous: true
        cache: true
        retainWhileLoading: true
        smooth: true
        playing: media.active && visible
        visible: source !== "" && status === AnimatedImage.Ready
        opacity: visible ? 1 : 0

        Behavior on opacity { NumberAnimation { duration: 180 } }
    }

    Rectangle {
        anchors.fill: parent
        visible: media.immersive
        gradient: Gradient {
            GradientStop { position: 0; color: "#18000000" }
            GradientStop { position: 0.58; color: "#08000000" }
            GradientStop { position: 1; color: "#62000000" }
        }
    }
}
