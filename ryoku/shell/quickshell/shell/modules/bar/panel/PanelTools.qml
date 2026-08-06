pragma ComponentBehavior: Bound

import QtQuick
import shell.services
import "../../../components"
import "../framebars/menus" as Menus

// Tools: the kept download / convert / install backends with a clean face.
// Paste a link to fetch it into the stash (cobalt drives a sequential queue);
// the list shows what landed; Convert compresses stashed media, Install runs a
// stashed package. No LocalSend, no file board -- those went with the old stash.
Item {
    id: root

    property real s: 1
    property bool open: false
    property string monitorName: ""
    property string surfaceId: ""

    property string urlText: ""
    implicitHeight: col.implicitHeight + 24 * root.s

    function startDownload() {
        if (root.urlText.trim().length === 0)
            return;
        Stash.enqueueDownload(root.urlText, Stash.dlMode);
        root.urlText = "";
    }

    function fileGlyph(name) {
        const e = ("" + name).toLowerCase().split(".").pop();
        if (/^(png|jpe?g|webp|gif|bmp|tiff?|avif)$/.test(e)) return "image";
        if (/^(mp4|mkv|webm|mov|avi|m4v)$/.test(e)) return "movie";
        if (/^(mp3|flac|wav|ogg|opus|m4a|aac)$/.test(e)) return "music_note";
        if (/^(zip|tar|gz|xz|zst|bz2|7z|rar|tgz)$/.test(e)) return "folder_zip";
        if (/^(appimage|deb|rpm|flatpak|pkg)$/.test(e)) return "deployed_code";
        return "draft";
    }

    readonly property var modes: [
        { id: "auto", label: qsTr("Auto") },
        { id: "audio", label: qsTr("Audio") },
        { id: "mute", label: qsTr("Mute") }
    ]

    Flickable {
        anchors.fill: parent
        anchors.leftMargin: 18 * root.s
        anchors.rightMargin: 18 * root.s
        anchors.topMargin: 16 * root.s
        anchors.bottomMargin: 8 * root.s
        contentWidth: width
        contentHeight: col.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height

        Column {
            id: col
            width: parent.width
            spacing: 10 * root.s

            Menus.QsSection { width: parent.width; label: qsTr("Download") }

            Rectangle {
                width: parent.width
                height: 46 * root.s
                radius: Theme.radiusWidget
                color: Theme.surface
                border.width: Theme.borderWidth
                border.color: urlInput.activeFocus ? Theme.primary : Theme.outline
                Behavior on border.color { ColorAnimation { duration: Motion.fast } }
                SumiEdge {}

                Row {
                    anchors.fill: parent
                    anchors.leftMargin: 12 * root.s
                    anchors.rightMargin: 12 * root.s
                    spacing: 9 * root.s

                    MaterialIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        font.pixelSize: 18 * root.s
                        text: "link"
                        color: Theme.inkOn(Theme.effectiveSurface, Theme.onSurfaceVariant, 3.0)
                    }
                    TextInput {
                        id: urlInput
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 27 * root.s - parent.spacing
                        text: root.urlText
                        onTextChanged: root.urlText = text
                        color: Theme.inkOn(Theme.effectiveSurface, Theme.onSurface)
                        font.family: Theme.fontPrimary
                        font.pixelSize: Theme.fontMd * root.s
                        clip: true
                        selectByMouse: true
                        onAccepted: root.startDownload()

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: urlInput.text.length === 0
                            text: qsTr("Paste a link to download")
                            color: Theme.inkOn(Theme.effectiveSurface, Theme.onSurfaceVariant, 3.0)
                            font: urlInput.font
                        }
                    }
                }
            }

            Row {
                width: parent.width
                spacing: 6 * root.s
                readonly property real segW: (width - 2 * spacing) / 3

                Repeater {
                    model: root.modes
                    delegate: Rectangle {
                        required property var modelData
                        readonly property bool on: Stash.dlMode === modelData.id
                        width: parent.segW
                        height: 34 * root.s
                        radius: Theme.radiusWidget
                        color: on ? Theme.primary : Qt.rgba(Theme.onSurface.r, Theme.onSurface.g, Theme.onSurface.b, 0.05)
                        border.width: 1
                        border.color: on ? "transparent" : Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.3)
                        Behavior on color { ColorAnimation { duration: Motion.fast } }

                        Text {
                            anchors.centerIn: parent
                            text: modelData.label
                            color: parent.on ? Theme.inkOn(Theme.primary, Theme.onPrimary)
                                : Theme.inkOn(Theme.effectiveSurface, Theme.onSurfaceVariant, 3.0)
                            font.family: Theme.fontPrimary
                            font.pixelSize: Theme.fontSm * root.s
                            font.weight: parent.on ? Font.DemiBold : Font.Normal
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Stash.dlMode = modelData.id
                        }
                    }
                }
            }

            ActionButton {
                width: parent.width
                label: qsTr("Download")
                icon: "download"
                primary: root.urlText.trim().length > 0
                enabled: root.urlText.trim().length > 0
                onTapped: root.startDownload()
            }

            Column {
                width: parent.width
                spacing: 6 * root.s
                visible: Stash.queueModel.count > 0

                Repeater {
                    model: Stash.queueModel
                    delegate: Rectangle {
                        required property var model
                        width: parent.width
                        height: 42 * root.s
                        radius: Theme.radiusWidget
                        color: Qt.rgba(Theme.onSurface.r, Theme.onSurface.g, Theme.onSurface.b, 0.05)

                        Column {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: 12 * root.s
                            anchors.rightMargin: 12 * root.s
                            spacing: 5 * root.s

                            Item {
                                width: parent.width
                                height: qName.implicitHeight

                                Text {
                                    id: qName
                                    anchors.left: parent.left
                                    anchors.right: qState.left
                                    anchors.rightMargin: 8 * root.s
                                    text: model.name && model.name.length > 0 ? model.name : model.arg
                                    elide: Text.ElideRight
                                    color: Theme.inkOn(Theme.effectiveSurface, Theme.onSurface)
                                    font.family: Theme.fontPrimary
                                    font.pixelSize: Theme.fontSm * root.s
                                }
                                Text {
                                    id: qState
                                    anchors.right: parent.right
                                    text: model.state === "running" ? model.pct + "%" : model.state
                                    color: model.state === "error" ? Theme.vermLit
                                        : Theme.inkOn(Theme.effectiveSurface, Theme.onSurfaceVariant, 3.0)
                                    font.family: Theme.mono
                                    font.pixelSize: (Theme.fontSm - 2) * root.s
                                }
                            }
                            Rectangle {
                                width: parent.width
                                height: 2
                                radius: 1
                                color: Qt.rgba(Theme.onSurface.r, Theme.onSurface.g, Theme.onSurface.b, 0.1)
                                Rectangle {
                                    height: parent.height
                                    radius: 1
                                    width: parent.width * Math.max(0, Math.min(1, (model.pct || 0) / 100))
                                    color: Theme.primary
                                    Behavior on width { NumberAnimation { duration: Motion.fast } }
                                }
                            }
                        }
                    }
                }
            }

            Menus.QsSection { width: parent.width; label: qsTr("In stash") }

            Text {
                width: parent.width
                visible: Stash.count === 0
                text: qsTr("Nothing stashed yet. Downloads land here.")
                wrapMode: Text.WordWrap
                color: Theme.inkOn(Theme.effectiveSurface, Theme.onSurfaceVariant, 3.0)
                font.family: Theme.fontPrimary
                font.pixelSize: Theme.fontSm * root.s
            }

            Column {
                width: parent.width
                spacing: 6 * root.s

                Repeater {
                    model: Stash.files
                    delegate: Rectangle {
                        id: fileRow
                        required property var model
                        width: parent.width
                        height: 44 * root.s
                        radius: Theme.radiusWidget
                        color: rowArea.containsMouse
                            ? Qt.rgba(Theme.onSurface.r, Theme.onSurface.g, Theme.onSurface.b, 0.08)
                            : Qt.rgba(Theme.onSurface.r, Theme.onSurface.g, Theme.onSurface.b, 0.04)
                        Behavior on color { ColorAnimation { duration: Motion.fast } }

                        MouseArea {
                            id: rowArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Stash.openFile(fileRow.model.filePath)
                        }

                        Row {
                            anchors.left: parent.left
                            anchors.right: rmBtn.left
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: 12 * root.s
                            anchors.rightMargin: 6 * root.s
                            spacing: 10 * root.s

                            MaterialIcon {
                                anchors.verticalCenter: parent.verticalCenter
                                font.pixelSize: 18 * root.s
                                text: root.fileGlyph(fileRow.model.fileName)
                                color: Theme.inkOn(Theme.effectiveSurface, Theme.onSurfaceVariant, 3.0)
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - 28 * root.s - parent.spacing
                                text: fileRow.model.fileName
                                elide: Text.ElideMiddle
                                color: Theme.inkOn(Theme.effectiveSurface, Theme.onSurface)
                                font.family: Theme.fontPrimary
                                font.pixelSize: Theme.fontSm * root.s
                            }
                        }

                        MaterialIcon {
                            id: rmBtn
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.rightMargin: 10 * root.s
                            font.pixelSize: 17 * root.s
                            text: "close"
                            color: Theme.inkOn(Theme.effectiveSurface, rmArea.containsMouse ? Theme.onSurface : Theme.onSurfaceVariant, 3.0)
                            MouseArea {
                                id: rmArea
                                anchors.fill: parent
                                anchors.margins: -8 * root.s
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Stash.removeFile(fileRow.model.filePath)
                            }
                        }
                    }
                }
            }

            Menus.QsSection {
                width: parent.width
                label: qsTr("Convert & install")
                visible: Stash.hasMedia || Stash.hasInstallable
            }

            ActionButton {
                width: parent.width
                visible: Stash.hasMedia
                label: qsTr("Compress media")
                icon: "compress"
                enabled: Stash.taskState === "idle"
                onTapped: Stash.requestCompress(root.monitorName, root.surfaceId)
            }
            ActionButton {
                width: parent.width
                visible: Stash.hasInstallable
                label: qsTr("Install package")
                icon: "install_desktop"
                enabled: Stash.taskState === "idle"
                onTapped: Stash.requestInstall(root.monitorName, root.surfaceId)
            }

            Rectangle {
                width: parent.width
                visible: Stash.taskState !== "idle"
                radius: Theme.radiusWidget
                color: Theme.surface
                border.width: Theme.borderWidth
                border.color: Theme.outline
                implicitHeight: taskCol.implicitHeight + 2 * (12 * root.s)
                SumiEdge {}

                Column {
                    id: taskCol
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 12 * root.s
                    spacing: 8 * root.s

                    Text {
                        width: parent.width
                        wrapMode: Text.WordWrap
                        text: Stash.taskState === "confirm"
                                ? (Stash.task === "install" ? qsTr("Install the stashed package?") : qsTr("Compress stashed media?"))
                            : Stash.taskState === "running" ? qsTr("Working…")
                            : Stash.taskState === "error" ? (Stash.taskMsg.length > 0 ? Stash.taskMsg : qsTr("Failed"))
                            : qsTr("Done")
                        color: Theme.inkOn(Theme.effectiveSurface, Theme.onSurface)
                        font.family: Theme.fontPrimary
                        font.pixelSize: Theme.fontSm * root.s
                    }
                    Row {
                        spacing: 8 * root.s
                        visible: Stash.taskState === "confirm"
                        ActionButton {
                            width: 110 * root.s
                            label: qsTr("Confirm")
                            primary: true
                            onTapped: Stash.confirmTask()
                        }
                        ActionButton {
                            width: 90 * root.s
                            label: qsTr("Cancel")
                            onTapped: Stash.dismissTask()
                        }
                    }
                    ActionButton {
                        visible: Stash.taskState === "done" || Stash.taskState === "error"
                        width: 90 * root.s
                        label: qsTr("Dismiss")
                        onTapped: Stash.dismissTask()
                    }
                }
            }

            Item { width: 1; height: 6 * root.s }
        }
    }

    // primary = bone plate + dark ink; otherwise a quiet outlined tile.
    component ActionButton: Item {
        id: btn
        property string label: ""
        property string icon: ""
        property bool primary: false
        signal tapped()

        implicitHeight: 42 * root.s
        opacity: btn.enabled ? 1 : 0.4

        Rectangle {
            anchors.fill: parent
            radius: Theme.radiusWidget
            color: btn.primary ? Theme.primary
                : ba.containsMouse ? Qt.rgba(Theme.onSurface.r, Theme.onSurface.g, Theme.onSurface.b, 0.08)
                : Qt.rgba(Theme.onSurface.r, Theme.onSurface.g, Theme.onSurface.b, 0.04)
            border.width: btn.primary ? 0 : Theme.borderWidth
            border.color: Theme.outline
            Behavior on color { ColorAnimation { duration: Motion.fast } }
            SumiEdge { visible: btn.primary }

            Row {
                anchors.centerIn: parent
                spacing: 8 * root.s

                MaterialIcon {
                    visible: btn.icon.length > 0
                    anchors.verticalCenter: parent.verticalCenter
                    font.pixelSize: 18 * root.s
                    text: btn.icon
                    color: btn.primary ? Theme.inkOn(Theme.primary, Theme.onPrimary)
                        : Theme.inkOn(Theme.effectiveSurface, Theme.onSurface)
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: btn.label
                    color: btn.primary ? Theme.inkOn(Theme.primary, Theme.onPrimary)
                        : Theme.inkOn(Theme.effectiveSurface, Theme.onSurface)
                    font.family: Theme.fontPrimary
                    font.pixelSize: Theme.fontSm * root.s
                    font.weight: Font.DemiBold
                }
            }
        }

        scale: ba.pressed && btn.enabled ? 0.97 : 1
        Behavior on scale { NumberAnimation { duration: Motion.fast } }

        MouseArea {
            id: ba
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: btn.tapped()
        }
    }
}
