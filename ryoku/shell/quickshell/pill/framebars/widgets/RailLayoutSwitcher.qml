pragma ComponentBehavior: Bound

import QtQuick

// Layout switcher button: the glyph reflects the active workspace's tiled layout,
// left click opens the layout menu (the fixed Dwindle/Master/Scrolling/Monocle
// choices). Contract 03 sec 2.5, sec 4.5.
Item {
    id: root

    required property string edge
    required property real scale
    required property bool active
    readonly property var layouts: layoutControl.layouts
    readonly property string current: layoutControl.current
    signal menuRequested(string id, rect ownerRect)

    implicitWidth: btn.implicitWidth
    implicitHeight: btn.implicitHeight

    LayoutControl {
        id: layoutControl
        active: root.active
    }

    // string -> glyph (contract 03 sec 4.5): dwindle/master/scrolling/monocle,
    // anything else falls back to the generic layout glyph.
    readonly property string glyph: {
        const l = layoutControl.current;
        return l === "dwindle" ? "layout-dwindle"
            : l === "master" ? "layout-master"
            : l === "scrolling" ? "layout-scrolling"
            : l === "monocle" ? "layout-monocle"
            : "layout";
    }

    RailButton {
        id: btn
        anchors.centerIn: parent
        edge: root.edge
        scale: root.scale
        icon: root.glyph
        onClicked: root.menuRequested("layout-switcher", Qt.rect(0, 0, root.width, root.height))
    }
}
