pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import shell.services
import "../../../components"

// Chat: the Super+S sidebar's view onto the Needle singleton (which owns the
// thread and the running turn). Renders streamed Markdown over a growing input;
// images attach via the picker, Ctrl+V, or drop.
Item {
    id: root

    property real s: 1
    property bool open: false

    // Paths queued to send with the next message (max 3, like the dashboard).
    property var pendingImages: []
    readonly property int maxImages: 3

    implicitHeight: 648 * root.s

    readonly property real minInputH: 20 * root.s
    readonly property real maxInputH: 132 * root.s

    function scrollEnd() { Qt.callLater(list.positionViewAtEnd); }

    function isImagePath(p) {
        return /\.(png|jpe?g|webp|gif|bmp|avif|svg)$/i.test(String(p));
    }
    function addImage(p) {
        var path = String(p).replace(/^file:\/\//, "");
        if (path.length === 0 || root.pendingImages.length >= root.maxImages)
            return;
        if (root.pendingImages.indexOf(path) >= 0)
            return;
        root.pendingImages = root.pendingImages.concat([path]);
    }
    function removeImage(i) {
        root.pendingImages = root.pendingImages.filter((_, idx) => idx !== i);
    }
    property bool modelMenuOpen: false
    function shortModel(id) {
        var t = String(id);
        var c = t.lastIndexOf(":");
        return c >= 0 ? t.slice(c + 1) : t;
    }

    function submit() {
        var q = input.text.trim();
        if ((q.length === 0 && root.pendingImages.length === 0) || Needle.busy)
            return;
        Needle.send(q, root.pendingImages);
        input.text = "";
        root.pendingImages = [];
    }

    Component.onCompleted: {
        Needle.noteOpened();
        Qt.callLater(input.forceActiveFocus);
        root.scrollEnd();
    }
    Component.onDestruction: Needle.noteClosed()
    onOpenChanged: if (root.open) Qt.callLater(input.forceActiveFocus)

    Connections {
        target: Needle
        function onTouched() { root.scrollEnd(); }
    }

    // File picker (paperclip): zenity returns the chosen path on stdout.
    Process {
        id: pickProc
        command: ["zenity", "--file-selection", "--title=Attach an image",
            "--file-filter=Images | *.png *.jpg *.jpeg *.webp *.gif *.bmp *.avif",
            "--file-filter=All files | *"]
        stdout: StdioCollector {
            id: pickOut
            onStreamFinished: {
                var p = ("" + pickOut.text).trim();
                if (p.length > 0 && root.isImagePath(p))
                    root.addImage(p);
            }
        }
    }

    // Ctrl+V image: if the clipboard holds an image, save it to a temp file and
    // attach it. Text paste is left to the TextArea (this prints nothing then).
    Process {
        id: pasteImgProc
        command: ["sh", "-c",
            't=$(wl-paste --list-types 2>/dev/null | grep -m1 -E "^image/"); [ -z "$t" ] && exit 0; ' +
            'd="${XDG_RUNTIME_DIR:-/tmp}/ryoku-chat"; mkdir -p "$d"; ext=${t#image/}; ' +
            'case "$ext" in jpeg) ext=jpg;; svg+xml) ext=svg;; esac; ' +
            'f="$d/paste-$(date +%s%N).$ext"; wl-paste --type "$t" > "$f" 2>/dev/null && printf "%s" "$f"']
        stdout: StdioCollector {
            id: pasteOut
            onStreamFinished: {
                var p = ("" + pasteOut.text).trim();
                if (p.length > 0)
                    root.addImage(p);
            }
        }
    }

    // Drop image files anywhere on the panel to attach them.
    DropArea {
        anchors.fill: parent
        onDropped: (drop) => {
            if (!drop.hasUrls)
                return;
            for (var i = 0; i < drop.urls.length; i++) {
                if (root.isImagePath(drop.urls[i]))
                    root.addImage(drop.urls[i]);
            }
            drop.accept();
        }
    }

    // ── header ──
    Item {
        id: header
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 14 * root.s
        height: 20 * root.s

        Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: "RASHIN"
            color: Theme.inkOn(Theme.effectiveSurface, Theme.onSurfaceVariant, 3.0)
            font.family: Theme.mono
            font.pixelSize: 9 * root.s
            font.letterSpacing: 1.5
            font.weight: Font.DemiBold
        }

        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4 * root.s
            Rectangle {
                id: modelChip
                anchors.verticalCenter: parent.verticalCenter
                height: 18 * root.s
                width: chipRow.implicitWidth + 12 * root.s
                radius: 9 * root.s
                visible: Needle.currentModel.length > 0
                color: chipArea.containsMouse || root.modelMenuOpen
                    ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.18)
                    : Qt.rgba(Theme.onSurface.r, Theme.onSurface.g, Theme.onSurface.b, 0.06)
                Behavior on color { ColorAnimation { duration: Motion.fast } }
                Row {
                    id: chipRow
                    anchors.centerIn: parent
                    spacing: 3 * root.s
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.shortModel(Needle.currentModel)
                        color: Theme.inkOn(Theme.effectiveSurface, Theme.onSurface)
                        font.family: Theme.mono
                        font.pixelSize: 8 * root.s
                    }
                    MaterialIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "expand_more"
                        font.pixelSize: 10 * root.s
                        color: Theme.inkOn(Theme.effectiveSurface, Theme.onSurfaceVariant, 3.0)
                    }
                }
                MouseArea {
                    id: chipArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.modelMenuOpen = !root.modelMenuOpen
                }
            }

            Repeater {
                model: [
                    { icon: "add_comment", act: "new" },
                    { icon: "open_in_new", act: "dash" }
                ]
                delegate: Rectangle {
                    id: hbtn
                    required property var modelData
                    width: 24 * root.s
                    height: 24 * root.s
                    radius: width / 2
                    color: hArea.containsMouse
                        ? Qt.rgba(Theme.onSurface.r, Theme.onSurface.g, Theme.onSurface.b, 0.10)
                        : "transparent"
                    Behavior on color { ColorAnimation { duration: Motion.fast } }

                    MaterialIcon {
                        anchors.centerIn: parent
                        font.pixelSize: 13 * root.s
                        text: hbtn.modelData.icon
                        color: Theme.inkOn(Theme.effectiveSurface, Theme.onSurfaceVariant, 3.0)
                    }
                    MouseArea {
                        id: hArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (hbtn.modelData.act === "new") {
                                Needle.newChat();
                                root.pendingImages = [];
                                Qt.callLater(input.forceActiveFocus);
                            } else {
                                Needle.openDashboard();
                            }
                        }
                    }
                }
            }
        }
    }
    // model picker dropdown; the scrim behind it closes on an outside click.
    MouseArea {
        anchors.fill: parent
        visible: root.modelMenuOpen
        z: 20
        onClicked: root.modelMenuOpen = false
    }
    Rectangle {
        visible: root.modelMenuOpen
        z: 21
        anchors.top: header.bottom
        anchors.right: parent.right
        anchors.topMargin: 4 * root.s
        anchors.rightMargin: 14 * root.s
        width: 220 * root.s
        height: Math.min(260 * root.s, modelList.contentHeight + 8 * root.s)
        radius: Theme.radiusWidget
        color: Theme.surfaceContainer
        border.width: Theme.borderWidth
        border.color: Theme.outline
        SumiEdge { radius: Theme.radiusWidget }
        ListView {
            id: modelList
            anchors.fill: parent
            anchors.margins: 4 * root.s
            clip: true
            model: Needle.models
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
            delegate: Rectangle {
                id: mrow
                required property int index
                required property var modelData
                width: ListView.view ? ListView.view.width : 0
                height: 30 * root.s
                radius: 6 * root.s
                readonly property bool current: Needle.currentModel === mrow.modelData.id
                color: mrowArea.containsMouse
                    ? Qt.rgba(Theme.onSurface.r, Theme.onSurface.g, Theme.onSurface.b, 0.10)
                    : mrow.current ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.14)
                    : "transparent"
                Text {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: 8 * root.s
                    anchors.rightMargin: 8 * root.s
                    text: mrow.modelData.name || mrow.modelData.id
                    elide: Text.ElideRight
                    color: mrow.current ? Theme.primary : Theme.inkOn(Theme.effectiveSurface, Theme.onSurface)
                    font.family: Theme.fontPrimary
                    font.pixelSize: 10 * root.s
                }
                MouseArea {
                    id: mrowArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        Needle.setModel(mrow.modelData.id);
                        root.modelMenuOpen = false;
                    }
                }
            }
        }
    }

    // ── transcript ──
    ListView {
        id: list
        anchors.top: header.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: inputWrap.top
        anchors.leftMargin: 14 * root.s
        anchors.rightMargin: 14 * root.s
        anchors.topMargin: 8 * root.s
        anchors.bottomMargin: 8 * root.s
        clip: true
        spacing: 12 * root.s
        model: Needle.convo
        boundsBehavior: Flickable.StopAtBounds
        cacheBuffer: 4000

        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        onCountChanged: root.scrollEnd()

        delegate: Column {
            id: msg
            required property int index
            required property string who
            required property string body
            required property string imagesJson
            required property string working
            required property bool streaming
            required property bool failed

            width: ListView.view ? ListView.view.width : 0
            spacing: 5 * root.s

            readonly property bool isUser: msg.who === "user"

            // role tag
            Text {
                text: msg.isUser ? "YOU" : "NEEDLE"
                color: msg.isUser
                    ? Theme.inkOn(Theme.effectiveSurface, Theme.onSurfaceVariant, 3.0)
                    : Theme.primary
                font.family: Theme.mono
                font.pixelSize: 7.5 * root.s
                font.letterSpacing: 1.2
                font.weight: Font.DemiBold
                anchors.right: msg.isUser ? parent.right : undefined
            }

            // bubble
            Rectangle {
                width: msg.isUser ? Math.min(parent.width, Math.max(bubbleText.implicitWidth + 24 * root.s, imgCol.implicitWidth + 16 * root.s)) : parent.width
                anchors.right: msg.isUser ? parent.right : undefined
                implicitHeight: bodyCol.implicitHeight + 16 * root.s
                radius: Theme.radiusWidget
                color: msg.isUser
                    ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.14)
                    : Qt.rgba(Theme.onSurface.r, Theme.onSurface.g, Theme.onSurface.b, 0.05)
                border.width: 1
                border.color: msg.isUser
                    ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.28)
                    : Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.30)

                Column {
                    id: bodyCol
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 8 * root.s
                    spacing: 6 * root.s

                    // working indicator (agent, pre-answer)
                    Row {
                        visible: !msg.isUser && msg.streaming && msg.body.length === 0
                        spacing: 6 * root.s
                        Rectangle {
                            width: 6 * root.s; height: 6 * root.s; radius: width / 2
                            anchors.verticalCenter: parent.verticalCenter
                            color: Theme.primary
                            SequentialAnimation on opacity {
                                running: !msg.isUser && msg.streaming && msg.body.length === 0
                                loops: Animation.Infinite
                                NumberAnimation { from: 0.3; to: 1; duration: 520 }
                                NumberAnimation { from: 1; to: 0.3; duration: 520 }
                            }
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: msg.working
                            color: Theme.inkOn(Theme.effectiveSurface, Theme.onSurfaceVariant, 3.0)
                            font.family: Theme.fontPrimary
                            font.pixelSize: 11 * root.s
                        }
                    }

                    // attached / produced images
                    Column {
                        id: imgCol
                        width: parent.width
                        spacing: 6 * root.s
                        Repeater {
                            model: {
                                try { return JSON.parse(msg.imagesJson) || []; }
                                catch (e) { return []; }
                            }
                            delegate: Rectangle {
                                id: imgCell
                                required property string modelData
                                width: Math.min(parent.width, 200 * root.s)
                                height: Math.min(160 * root.s, width * (thumb.implicitHeight > 0 ? thumb.implicitHeight / Math.max(1, thumb.implicitWidth) : 0.6))
                                radius: 6 * root.s
                                color: "transparent"
                                clip: true
                                Image {
                                    id: thumb
                                    anchors.fill: parent
                                    fillMode: Image.PreserveAspectFit
                                    horizontalAlignment: Image.AlignLeft
                                    source: "file://" + imgCell.modelData
                                    asynchronous: true
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: Quickshell.execDetached(["xdg-open", imgCell.modelData])
                                }
                            }
                        }
                    }

                    // message body: Markdown for the agent, plain for the user.
                    TextEdit {
                        id: bubbleText
                        width: parent.width
                        visible: msg.body.length > 0
                        text: msg.body
                        readOnly: true
                        selectByMouse: true
                        wrapMode: TextEdit.Wrap
                        textFormat: msg.isUser ? TextEdit.PlainText : TextEdit.MarkdownText
                        color: msg.failed ? Theme.vermLit : Theme.inkOn(Theme.effectiveSurface, Theme.onSurface)
                        selectionColor: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.35)
                        font.family: Theme.fontPrimary
                        font.pixelSize: 12.5 * root.s
                        selectedTextColor: color
                        onLinkActivated: (url) => Quickshell.execDetached(["xdg-open", url])
                    }
                }

                // copy affordance (agent answers)
                MaterialIcon {
                    visible: !msg.isUser && !msg.streaming && msg.body.length > 0 && copyArea.containsMouse
                    anchors.top: parent.top
                    anchors.right: parent.right
                    anchors.margins: 6 * root.s
                    font.pixelSize: 13 * root.s
                    text: "content_copy"
                    color: Theme.inkOn(Theme.effectiveSurface, Theme.onSurfaceVariant, 3.0)
                }
                MouseArea {
                    id: copyArea
                    visible: !msg.isUser && !msg.streaming && msg.body.length > 0
                    anchors.top: parent.top
                    anchors.right: parent.right
                    width: 26 * root.s
                    height: 26 * root.s
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Needle.copyText(msg.body)
                }
            }
        }
    }

    // empty state
    Column {
        anchors.centerIn: list
        width: list.width - 40 * root.s
        spacing: 8 * root.s
        visible: Needle.convo.count === 0

        MaterialIcon {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "cognition"
            font.pixelSize: 30 * root.s
            fill: 0
            color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.55)
        }
        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: "Ask the needle anything. It knows this machine, your desktop, and the Ryoku source. Drop or paste an image to ask about it."
            wrapMode: Text.WordWrap
            color: Theme.inkOn(Theme.effectiveSurface, Theme.onSurfaceVariant, 3.0)
            font.family: Theme.fontPrimary
            font.pixelSize: 11.5 * root.s
            lineHeight: 1.25
        }
    }

    // ── input ──
    Rectangle {
        id: inputWrap
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 12 * root.s
        radius: Theme.radiusWidget
        color: Theme.surface
        border.width: Theme.borderWidth
        border.color: input.activeFocus ? Theme.primary : Theme.outline
        Behavior on border.color { ColorAnimation { duration: Motion.fast } }
        implicitHeight: inputCol.implicitHeight + 14 * root.s
        SumiEdge { radius: Theme.radiusWidget }

        Column {
            id: inputCol
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 7 * root.s
            spacing: 7 * root.s

            // pending attachments strip
            Flow {
                width: parent.width
                spacing: 6 * root.s
                visible: root.pendingImages.length > 0
                Repeater {
                    model: root.pendingImages
                    delegate: Rectangle {
                        id: pend
                        required property int index
                        required property string modelData
                        width: 46 * root.s
                        height: 46 * root.s
                        radius: 6 * root.s
                        color: Qt.rgba(Theme.onSurface.r, Theme.onSurface.g, Theme.onSurface.b, 0.06)
                        clip: true
                        Image {
                            anchors.fill: parent
                            fillMode: Image.PreserveAspectCrop
                            source: "file://" + pend.modelData
                            asynchronous: true
                        }
                        Rectangle {
                            anchors.top: parent.top
                            anchors.right: parent.right
                            width: 16 * root.s
                            height: 16 * root.s
                            radius: width / 2
                            color: Qt.rgba(0, 0, 0, 0.6)
                            MaterialIcon {
                                anchors.centerIn: parent
                                text: "close"
                                font.pixelSize: 11 * root.s
                                color: "white"
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.removeImage(pend.index)
                            }
                        }
                    }
                }
            }

            // input row: attach | field | send
            Item {
                width: parent.width
                height: Math.max(26 * root.s, inputScroll.height)

                Rectangle {
                    id: attachBtn
                    anchors.left: parent.left
                    anchors.bottom: parent.bottom
                    width: 26 * root.s
                    height: 26 * root.s
                    radius: width / 2
                    enabled: root.pendingImages.length < root.maxImages
                    opacity: enabled ? 1 : 0.4
                    color: attachArea.containsMouse
                        ? Qt.rgba(Theme.onSurface.r, Theme.onSurface.g, Theme.onSurface.b, 0.10)
                        : "transparent"
                    Behavior on color { ColorAnimation { duration: Motion.fast } }
                    MaterialIcon {
                        anchors.centerIn: parent
                        text: "add_photo_alternate"
                        font.pixelSize: 15 * root.s
                        color: Theme.inkOn(Theme.effectiveSurface, Theme.onSurfaceVariant, 3.0)
                    }
                    MouseArea {
                        id: attachArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: if (attachBtn.enabled) pickProc.running = true
                    }
                }

                ScrollView {
                    id: inputScroll
                    anchors.left: attachBtn.right
                    anchors.right: sendBtn.left
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: 6 * root.s
                    anchors.rightMargin: 6 * root.s
                    height: Math.min(root.maxInputH, Math.max(root.minInputH, input.implicitHeight))
                    clip: true

                    TextArea {
                        id: input
                        background: null
                        padding: 0
                        wrapMode: TextArea.Wrap
                        placeholderText: "Message the needle"
                        placeholderTextColor: Theme.inkOn(Theme.effectiveSurface, Theme.onSurfaceVariant, 3.0)
                        color: Theme.inkOn(Theme.effectiveSurface, Theme.onSurface)
                        selectionColor: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.35)
                        selectByMouse: true
                        font.family: Theme.fontPrimary
                        font.pixelSize: 12.5 * root.s
                        // Ctrl+V: let the text paste happen, and also check the
                        // clipboard for an image to attach (harmless for text).
                        Keys.onPressed: (e) => {
                            if ((e.key === Qt.Key_Return || e.key === Qt.Key_Enter) && !(e.modifiers & Qt.ShiftModifier)) {
                                root.submit();
                                e.accepted = true;
                            } else if (e.key === Qt.Key_Escape && Needle.busy) {
                                Needle.cancel();
                                e.accepted = true;
                            } else if (e.key === Qt.Key_V && (e.modifiers & Qt.ControlModifier)) {
                                pasteImgProc.running = true;
                            }
                        }
                    }
                }

                // send / cancel
                Rectangle {
                    id: sendBtn
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    width: 26 * root.s
                    height: 26 * root.s
                    radius: width / 2
                    readonly property bool ready: input.text.trim().length > 0 || root.pendingImages.length > 0
                    color: Needle.busy ? Qt.rgba(Theme.vermLit.r, Theme.vermLit.g, Theme.vermLit.b, 0.18)
                        : ready ? Theme.primary
                        : Qt.rgba(Theme.onSurface.r, Theme.onSurface.g, Theme.onSurface.b, 0.08)
                    Behavior on color { ColorAnimation { duration: Motion.fast } }

                    MaterialIcon {
                        anchors.centerIn: parent
                        font.pixelSize: 15 * root.s
                        text: Needle.busy ? "stop" : "arrow_upward"
                        color: Needle.busy ? Theme.vermLit
                            : sendBtn.ready ? Theme.inkOn(Theme.primary, Theme.onPrimary)
                            : Theme.inkOn(Theme.effectiveSurface, Theme.onSurfaceVariant, 3.0)
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Needle.busy ? Needle.cancel() : root.submit()
                    }
                }
            }
        }
    }
}
