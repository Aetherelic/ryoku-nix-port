pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import Quickshell
import shell.services
import "../../../components"

// Chat: the Super+S sidebar's view onto the Needle singleton (which owns the
// conversation and the running ask, so the thread survives a close/reopen). A
// scrollable transcript of user/agent turns over a growing input. Answers
// render as Markdown, selectable and copyable; produced images preview inline.
// Opening after a long idle starts a fresh chat (Needle.noteOpened).
Item {
    id: root

    property real s: 1
    property bool open: false

    implicitHeight: 648 * root.s

    readonly property real minInputH: 20 * root.s
    readonly property real maxInputH: 132 * root.s

    function scrollEnd() { Qt.callLater(list.positionViewAtEnd); }

    function submit() {
        var q = input.text.trim();
        if (q.length === 0 || Needle.busy)
            return;
        Needle.send(q);
        input.text = "";
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
                width: msg.isUser ? Math.min(parent.width, bubbleText.implicitWidth + 24 * root.s) : parent.width
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

                    // produced images
                    Column {
                        width: parent.width
                        spacing: 6 * root.s
                        Repeater {
                            model: {
                                try { return JSON.parse(msg.imagesJson) || []; }
                                catch (e) { return []; }
                            }
                            delegate: Image {
                                id: img
                                required property string modelData
                                width: Math.min(parent.width, implicitWidth)
                                fillMode: Image.PreserveAspectFit
                                source: "file://" + img.modelData
                                asynchronous: true
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: Quickshell.execDetached(["xdg-open", img.modelData])
                                }
                            }
                        }
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
            text: "Ask the needle anything. It knows this machine, your desktop, and the Ryoku source."
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
        implicitHeight: Math.max(38 * root.s, inputScroll.height + 16 * root.s)
        SumiEdge { radius: Theme.radiusWidget }

        ScrollView {
            id: inputScroll
            anchors.left: parent.left
            anchors.right: sendBtn.left
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: 12 * root.s
            anchors.rightMargin: 8 * root.s
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
                Keys.onPressed: (e) => {
                    if ((e.key === Qt.Key_Return || e.key === Qt.Key_Enter) && !(e.modifiers & Qt.ShiftModifier)) {
                        root.submit();
                        e.accepted = true;
                    } else if (e.key === Qt.Key_Escape && Needle.busy) {
                        Needle.cancel();
                        e.accepted = true;
                    }
                }
            }
        }

        // send / cancel
        Rectangle {
            id: sendBtn
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 6 * root.s
            width: 26 * root.s
            height: 26 * root.s
            radius: width / 2
            readonly property bool ready: input.text.trim().length > 0
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
