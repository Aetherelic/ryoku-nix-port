pragma ComponentBehavior: Bound

import QtQuick
import "Singletons"

// A crossfading full-bleed wallpaper. One Image holds the current picture; when
// the url changes (the daemon bumped the revision) the new file decodes into the
// hidden buffer and the two crossfade (Motion.wallpaperFade, linear) once it is
// ready, so a change fades instead of cutting (contract 08 sec 5). The two
// buffers ping-pong, so nothing is torn down mid-fade and a resize re-fits the
// same file rather than reloading it.
Item {
    id: view

    // The daemon publishes a cache file path plus a revision; the shell root folds
    // both into one url whose query busts Qt's pixmap cache, so even a re-theme of
    // the same path reloads. "" paints nothing (the window's paper colour shows).
    property string url: ""

    // Contract 08 sec 3.3: content_fit maps to Image.fillMode. ScaleDown is
    // Contain that never upscales, which QML has no fillMode for, so a picture
    // smaller than the surface is padded (native size, centred) and a larger one
    // is fit.
    property string fit: "Cover"

    function fillModeFor(img) {
        switch (view.fit) {
        case "Contain":
            return Image.PreserveAspectFit;
        case "Fill":
            return Image.Stretch;
        case "ScaleDown":
            return (img.sourceSize.width <= view.width && img.sourceSize.height <= view.height) ? Image.Pad : Image.PreserveAspectFit;
        default:
            return Image.PreserveAspectCrop; // Cover
        }
    }

    // Which buffer currently shows the wallpaper; the other is the load target.
    property bool aFront: true

    onUrlChanged: view.loadBack()

    function loadBack() {
        if (view.url === "")
            return;
        const back = view.aFront ? imgB : imgA;
        if (back.source == view.url) {
            if (back.status === Image.Ready)
                fade.restart();
            return;
        }
        back.source = view.url;
        // fade fires from the back buffer's onStatusChanged once it is Ready.
    }

    Image {
        id: imgA
        anchors.fill: parent
        cache: false
        asynchronous: true
        fillMode: view.fillModeFor(imgA)
        opacity: 1
        onStatusChanged: if (status === Image.Ready && !view.aFront && source == view.url)
            fade.restart()
    }
    Image {
        id: imgB
        anchors.fill: parent
        cache: false
        asynchronous: true
        fillMode: view.fillModeFor(imgB)
        opacity: 0
        onStatusChanged: if (status === Image.Ready && view.aFront && source == view.url)
            fade.restart()
    }

    // Fade the freshly decoded back buffer up and the old front down, then commit
    // the swap so the next change targets the other buffer.
    ParallelAnimation {
        id: fade
        readonly property Image incoming: view.aFront ? imgB : imgA
        readonly property Image outgoing: view.aFront ? imgA : imgB
        NumberAnimation {
            target: fade.incoming
            property: "opacity"
            to: 1
            duration: Motion.wallpaperFade
            easing.type: Easing.Linear
        }
        NumberAnimation {
            target: fade.outgoing
            property: "opacity"
            to: 0
            duration: Motion.wallpaperFade
            easing.type: Easing.Linear
        }
        onFinished: view.aFront = !view.aFront
    }
}
