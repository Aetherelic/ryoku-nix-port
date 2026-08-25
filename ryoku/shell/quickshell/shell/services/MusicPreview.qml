pragma Singleton

import QtQuick

// Dock -> music-card hover state, mirroring DockPreview: DockMedia writes the
// chip's screen-centre and the band edge on hover; MusicHoverPopout reads them.
QtObject {
    id: root

    property bool hovered: false
    property real gx: -1
    property real gy: -1
    property string edge: "bottom"
    property real margin: 0
}
