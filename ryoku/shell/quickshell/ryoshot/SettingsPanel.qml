import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import "lib/keymap.js" as Keymap
import Ryoku.Ui.Singletons

Item {
    id: panel
    property string luaPath: ""
    property string hotkey: "-"
    property bool listening: false

    signal closeRequested()
    signal rebound()

    readonly property color glassBg: Qt.rgba(22 / 255, 17 / 255, 11 / 255, 0.97)
    readonly property color glassBorder: Qt.rgba(243 / 255, 237 / 255, 225 / 255, 0.14)
    readonly property color vermilion: "#e2342a"
    readonly property color idle: "#c7bfae"

    readonly property int arrow: 7
    implicitWidth: card.implicitWidth
    implicitHeight: card.implicitHeight + arrow

    FileView {
        id: reader
        path: panel.luaPath
        onLoaded: { var b = Keymap.parseBind(text()); if (b) panel.hotkey = b; }
    }

    FileView {
        id: writer
        path: panel.luaPath
        atomicWrites: true
        onSaved: { reloadProc.running = true; panel.rebound(); }
        onSaveFailed: (err) => console.log("ryoshot: ryoshot.lua write failed: " + err)
    }

    Process {
        id: reloadProc
        command: ["setsid", "-f", "sh", "-c", "sleep 0.5; hyprctl reload"]
    }

    function applyBind(bind) {
        panel.hotkey = bind;
        panel.listening = false;
        writer.setText(Keymap.luaFile(bind));
    }

    Rectangle {
        id: card
        width: parent.width
        height: parent.height - panel.arrow
        radius: 10
        color: panel.glassBg
        border.color: panel.glassBorder
        border.width: 1
        implicitWidth: content.implicitWidth + 20
        implicitHeight: 44

        RowLayout {
            id: content
            anchors.centerIn: parent
            spacing: 10

            Text {
                text: panel.hotkey
                color: panel.idle
                font.family: "JetBrains Mono"
                font.pixelSize: 13
                verticalAlignment: Text.AlignVCenter
            }

            Rectangle {
                id: recBtn
                Layout.preferredHeight: 28
                Layout.preferredWidth: recLabel.implicitWidth + 24
                radius: 6
                color: panel.listening ? panel.vermilion
                    : (recHover.hovered ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(1, 1, 1, 0.06))
                border.color: panel.listening ? panel.vermilion : panel.glassBorder
                border.width: 1

                Text {
                    id: recLabel
                    anchors.centerIn: parent
                    text: panel.listening ? I18n.tr("Press a key…") : I18n.tr("Record")
                    color: panel.listening ? "#ffffff" : panel.idle
                    font.family: "JetBrains Mono"
                    font.pixelSize: 13
                }

                HoverHandler { id: recHover }
                TapHandler {
                    onTapped: {
                        panel.listening = !panel.listening;
                        if (panel.listening) keyCatcher.forceActiveFocus();
                    }
                }
            }
        }
    }

    Canvas {
        width: panel.arrow * 2
        height: panel.arrow
        anchors.top: card.bottom
        anchors.horizontalCenter: card.horizontalCenter
        onPaint: {
            var ctx = getContext("2d");
            ctx.reset();
            ctx.beginPath();
            ctx.moveTo(0, 0);
            ctx.lineTo(width, 0);
            ctx.lineTo(width / 2, height);
            ctx.closePath();
            ctx.fillStyle = Qt.rgba(24 / 255, 28 / 255, 38 / 255, 0.97);
            ctx.fill();
        }
    }

    Item {
        id: keyCatcher
        focus: panel.visible
        Keys.onPressed: (e) => {
            e.accepted = true;
            if (e.key === Qt.Key_Escape) {
                if (panel.listening) panel.listening = false;
                else panel.closeRequested();
                return;
            }
            if (!panel.listening) return;
            var bind = Keymap.bindString(e.key, e.modifiers, e.text);
            if (bind !== null) panel.applyBind(bind);
        }
    }
}
