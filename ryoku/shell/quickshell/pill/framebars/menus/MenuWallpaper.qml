pragma ComponentBehavior: Bound

import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import "../../Singletons"

// The wallpaper grid (contract 08 sec 2.1 / 4.1): a three-lane, horizontally
// scrolling strip of 180x120 thumbnails inside a fixed 384px band, feathered by
// a surface-coloured 32px fade on each end. The source directory is scanned and
// watched natively through FolderListModel, so a wallpaper dropped into the
// folder appears without a poll and a removed one drops out. A single click
// applies a wallpaper through the daemon (`ryoku-shell wallpaper set`), the same
// intent path Super+W and the standalone switcher use, so the pick shares the
// transition, palette and state and never dismisses the menu.
//
// Thumbnails always render Cover (PreserveAspectCrop) regardless of the desktop
// content-fit setting: that setting scales the desktop surface, not the previews.
Item {
    id: root

    property real s: 1
    property bool open: false
    signal requestClose()

    // Ryoku keeps its wallpapers in ~/Pictures/Wallpapers, the same folder the
    // Super+W keybind, the daemon pool and the standalone switcher read.
    readonly property string wallDir: (Quickshell.env("HOME") || "") + "/Pictures/Wallpapers"

    // Reference thumbnail geometry: a 180x120 tile with a 4px cell margin and a
    // 2px border, so a cell is 188x128 and three lanes stack to the 384px band
    // (contract 08 sec 2.1).
    readonly property int thumbW: 180
    readonly property int thumbH: 120
    readonly property int cellMargin: 4
    readonly property int cellW: thumbW + cellMargin * 2
    readonly property int cellH: thumbH + cellMargin * 2
    readonly property int bandH: cellH * 3
    // The grid content is inset 32px from each end (contract 08 sec 2.1),
    // and the fade sits over that inset.
    readonly property int edgeFade: 32

    implicitHeight: header.implicitHeight + 16 + bandH

    // Apply a wallpaper. The daemon verb takes a filesystem path, so decode the
    // model's file URL back to one. A single click applies immediately and does
    // not close the menu (single-click activate, contract 08 sec 4.1).
    function apply(fileUrl) {
        const path = decodeURIComponent(("" + fileUrl).replace(/^file:\/\//, ""));
        if (path.length > 0)
            Quickshell.execDetached(["ryoku-shell", "wallpaper", "set", path]);
    }

    FolderListModel {
        id: folder
        folder: "file://" + root.wallDir
        showDirs: false
        showHidden: false
        showOnlyReadable: true
        sortField: FolderListModel.Name
        // Case-insensitive match of the eight image extensions the reference
        // enumerator accepts (png, jpg, jpeg, webp, bmp, svg, tiff, tif).
        caseSensitive: false
        nameFilters: ["*.png", "*.jpg", "*.jpeg", "*.webp", "*.bmp", "*.svg", "*.tiff", "*.tif"]
    }

    Column {
        width: parent.width
        spacing: 16

        // Header: the section title and the directory being shown (contract 08
        // sec 2.1 header).
        Column {
            id: header
            width: parent.width
            spacing: 2

            Text {
                text: qsTr("Wallpaper")
                color: Theme.onSurface
                font.family: Theme.fontPrimary
                font.pixelSize: Theme.fontXl
                font.weight: Font.Bold
            }
            Text {
                width: parent.width
                text: root.wallDir.replace(Quickshell.env("HOME") || "\u0000", "~")
                color: Theme.onSurface
                font.family: Theme.fontPrimary
                font.pixelSize: Theme.fontSm
                elide: Text.ElideMiddle
            }
        }

        // The fixed 384px band: the three-lane grid, its edge fades, and the
        // empty message. The grid is hidden while the folder is empty.
        Item {
            id: band
            width: parent.width
            height: root.bandH

            GridView {
                id: grid
                anchors.fill: parent
                visible: folder.count > 0
                clip: true
                model: folder

                // Three lanes on the cross axis, scrolling horizontally: fill a
                // column of three top-to-bottom, then step right.
                flow: GridView.FlowTopToBottom
                cellWidth: root.cellW
                cellHeight: root.cellH
                leftMargin: root.edgeFade
                rightMargin: root.edgeFade
                cacheBuffer: root.cellW * 8
                boundsBehavior: Flickable.StopAtBounds
                // Only steal a drag when the strip actually overflows its band.
                interactive: contentWidth > width

                delegate: Item {
                    id: cell
                    required property url fileUrl
                    width: root.cellW
                    height: root.cellH

                    Rectangle {
                        id: tile
                        anchors.centerIn: parent
                        width: root.thumbW
                        height: root.thumbH
                        radius: Theme.radiusWidget
                        color: "transparent"
                        border.width: Theme.borderWidth
                        // Outline at rest, on-surface on hover (contract 08 sec 5).
                        border.color: hov.hovered ? Theme.onSurface : Theme.outline
                        clip: true
                        // The 1.02 lift and border tint share Motion.thumbHover (150ms).
                        scale: hov.hovered ? 1.02 : 1.0
                        Behavior on scale {
                            NumberAnimation { duration: Motion.thumbHover; easing.type: Motion.easeType; easing.bezierCurve: Motion.easeCurve }
                        }
                        Behavior on border.color {
                            ColorAnimation { duration: Motion.thumbHover; easing.type: Motion.easeType; easing.bezierCurve: Motion.easeCurve }
                        }

                        Image {
                            anchors.fill: parent
                            anchors.margins: Theme.borderWidth
                            asynchronous: true
                            cache: true
                            fillMode: Image.PreserveAspectCrop
                            sourceSize: Qt.size(root.thumbW * 2, root.thumbH * 2)
                            source: cell.fileUrl
                        }

                        HoverHandler { id: hov; cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: root.apply(cell.fileUrl) }
                    }
                }

                // Vertical wheel drives horizontal scroll, 64px per notch
                // (contract 08 sec 2.1); a wheel notch is 120 angle units.
                WheelHandler {
                    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                    onWheel: event => {
                        const step = (event.angleDelta.y / 120) * 64;
                        const max = Math.max(0, grid.contentWidth + grid.leftMargin + grid.rightMargin - grid.width);
                        grid.contentX = Math.max(0, Math.min(max, grid.contentX - step));
                    }
                }
            }

            // Inset edge fade (contract 08 sec 2.5): 32px surface gradients over
            // the strip ends. Plain rectangles with no handlers, so tile hover
            // and click pass straight through (non-interactive).
            Rectangle {
                anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                width: root.edgeFade
                visible: grid.visible
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: Theme.surface }
                    GradientStop { position: 1.0; color: Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b, 0) }
                }
            }
            Rectangle {
                anchors { right: parent.right; top: parent.top; bottom: parent.bottom }
                width: root.edgeFade
                visible: grid.visible
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b, 0) }
                    GradientStop { position: 1.0; color: Theme.surface }
                }
            }

            // Empty / not-a-directory state (contract 08 sec 6): the grid is
            // hidden and this bold message stands in.
            Text {
                anchors.centerIn: parent
                visible: folder.count === 0
                text: qsTr("No wallpapers available")
                color: Theme.onSurface
                font.family: Theme.fontPrimary
                font.pixelSize: Theme.fontMd
                font.weight: Font.Bold
            }
        }
    }
}
