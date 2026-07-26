pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "../.." as Pill
import "../../Singletons"

// The desktop portal screen-share picker (contract 09 sec 2c). It opens when the
// ryoku-share helper asks the daemon to pick a source, lists the connected
// screens and the shareable windows the portal offered, and sends the chosen
// source back through the Screenshare singleton. It is one of the two menus that
// take exclusive keyboard focus (wired in FrameMenuManager), so Escape reaches
// the frame and closes it; any dismissal without a selection answers the portal
// with an empty string, which it reads as a cancel. The menu is fixed at 410 and
// has no configurable width. State is the daemon `screenshare` topic; the
// screens come from the compositor. QML never speaks to the portal itself.
Item {
    id: root

    required property real s
    required property bool open
    signal requestClose()

    readonly property real pad: 20 * s
    implicitWidth: 410 * s
    implicitHeight: content.implicitHeight + pad * 2

    // The connected outputs, by Wayland name, are the screen sources; the portal
    // expects that name in a screen selection.
    readonly property var outputs: {
        const list = Quickshell.screens;
        const out = [];
        for (let i = 0; i < list.length; ++i)
            out.push(list[i].name);
        return out;
    }

    // Program names truncate at 30 characters, matching the reference picker.
    function truncate(name) {
        return name.length > 30 ? name.substring(0, 30) + "\u2026" : name;
    }

    // One flat model: a header before each group, then a button per source. A
    // single delegate renders both kinds, so there is one styling of a pick row.
    readonly property var rows: {
        const out = [];
        if (!root.open)
            return out;
        if (root.outputs.length > 0) {
            out.push({ header: true, text: qsTr("Screens") });
            for (const name of root.outputs)
                out.push({ header: false, icon: "desktop_windows", label: name, selection: "[SELECTION]/screen:" + name });
        }
        const programs = Screenshare.programs;
        for (const program of programs) {
            out.push({ header: true, text: root.truncate(program.name || "") });
            for (const win of (program.windows || []))
                out.push({ header: false, icon: "web_asset", label: (win.title && win.title.length > 0) ? win.title : win.id, selection: "[SELECTION]/window:" + win.id });
        }
        return out;
    }

    // Any dismissal without a pick answers the portal with a cancel. A prior
    // selection has already resolved this request, so the singleton drops this.
    onOpenChanged: if (!root.open) Screenshare.reply("")

    Flickable {
        anchors.fill: parent
        contentWidth: width
        contentHeight: content.implicitHeight + root.pad * 2
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height

        Column {
            id: content
            x: root.pad
            y: root.pad
            width: root.width - root.pad * 2
            spacing: 12 * root.s

            Text {
                width: parent.width
                text: qsTr("Choose what to share")
                color: Theme.onSurfaceVariant
                font.family: Theme.fontPrimary
                font.pixelSize: Theme.fontXl
                font.weight: Font.Bold
                wrapMode: Text.WordWrap
            }

            Repeater {
                model: root.rows

                delegate: Item {
                    id: row
                    required property var modelData
                    width: content.width
                    height: row.modelData.header ? headerText.implicitHeight + 6 * root.s : 40 * root.s

                    Text {
                        id: headerText
                        visible: row.modelData.header
                        width: parent.width
                        anchors.bottom: parent.bottom
                        text: row.modelData.header ? row.modelData.text : ""
                        horizontalAlignment: Text.AlignHCenter
                        color: Theme.onSurface
                        font.family: Theme.fontPrimary
                        font.pixelSize: Theme.fontLg
                        font.weight: Font.Bold
                        elide: Text.ElideRight
                    }

                    Rectangle {
                        visible: !row.modelData.header
                        anchors.fill: parent
                        radius: Theme.radiusWidget
                        color: pickHover.hovered ? Theme.vermLit : Theme.primary

                        Behavior on color { ColorAnimation { duration: Motion.rowFade; easing.type: Motion.easeType; easing.bezierCurve: Motion.easeCurve } }

                        Pill.MaterialIcon {
                            id: rowIcon
                            anchors.left: parent.left
                            anchors.leftMargin: Theme.paddingMd
                            anchors.verticalCenter: parent.verticalCenter
                            text: row.modelData.header ? "" : row.modelData.icon
                            font.pixelSize: Theme.iconSm
                            color: Theme.onPrimary
                        }

                        Text {
                            anchors.left: rowIcon.right
                            anchors.leftMargin: Theme.paddingMd
                            anchors.right: parent.right
                            anchors.rightMargin: Theme.paddingMd
                            anchors.verticalCenter: parent.verticalCenter
                            text: row.modelData.header ? "" : row.modelData.label
                            color: Theme.onPrimary
                            font.family: Theme.fontPrimary
                            font.pixelSize: Theme.fontSm
                            elide: Text.ElideRight
                        }

                        HoverHandler { id: pickHover; cursorShape: Qt.PointingHandCursor }
                        TapHandler {
                            onTapped: {
                                Screenshare.reply(row.modelData.selection);
                                root.requestClose();
                            }
                        }
                    }
                }
            }
        }
    }
}
