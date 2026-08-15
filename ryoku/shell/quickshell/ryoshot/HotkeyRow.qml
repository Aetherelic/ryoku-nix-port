import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import "lib/keymap.js" as Keymap
import "Singletons"
import Ryoku.Ui.Singletons

Item {
    id: hk

    property string luaPath: ""
    property string hotkey: "-"
    property bool listening: false

    signal rebound()
    signal closeRequested()

    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    FileView {
        id: reader
        path: hk.luaPath
        onLoaded: { var b = Keymap.parseBind(text()); if (b) hk.hotkey = b; }
    }

    FileView {
        id: writer
        path: hk.luaPath
        atomicWrites: true
        onSaved: { reloadProc.running = true; hk.rebound(); }
        onSaveFailed: (err) => console.log("ryoshot: ryoshot.lua write failed: " + err)
    }

    Process {
        id: reloadProc
        command: ["setsid", "-f", "sh", "-c", "sleep 0.5; hyprctl reload"]
    }

    function applyBind(bind) {
        hk.hotkey = bind;
        hk.listening = false;
        writer.setText(Keymap.luaFile(bind));
    }

    RowLayout {
        id: row
        anchors.fill: parent
        spacing: 10

        Text {
            text: hk.hotkey
            color: Theme.inkDim
            font.family: Theme.mono
            font.pixelSize: 13
            verticalAlignment: Text.AlignVCenter
        }

        Item { Layout.fillWidth: true }

        Rectangle {
            id: recBtn
            Layout.preferredHeight: 28
            Layout.preferredWidth: recLabel.implicitWidth + 24
            radius: 6
            color: hk.listening ? Theme.accent : (recHover.hovered ? Theme.press : Theme.hover)
            border.color: hk.listening ? Theme.accent : Theme.hair
            border.width: 1

            Text {
                id: recLabel
                anchors.centerIn: parent
                text: hk.listening ? I18n.tr("Press a key…") : I18n.tr("Record")
                color: hk.listening ? Theme.accentInk : Theme.inkDim
                font.family: Theme.mono
                font.pixelSize: 13
            }

            HoverHandler { id: recHover }
            TapHandler {
                onTapped: {
                    hk.listening = !hk.listening;
                    if (hk.listening) keyCatcher.forceActiveFocus();
                }
            }
        }
    }

    Item {
        id: keyCatcher
        focus: hk.visible
        Keys.onPressed: (e) => {
            e.accepted = true;
            if (e.key === Qt.Key_Escape) {
                if (hk.listening) hk.listening = false;
                else hk.closeRequested();
                return;
            }
            if (!hk.listening) return;
            var bind = Keymap.bindString(e.key, e.modifiers, e.text);
            if (bind !== null) hk.applyBind(bind);
        }
    }
}
