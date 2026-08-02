import QtQuick
import Ryoku.Ui.Singletons

Item {
    id: layer

    property bool open: false
    property string query: ""
    property int resultCount: 0

    signal queryEdited(string value)
    signal closeRequested()

    readonly property bool fieldActive: field.activeFocus

    visible: open
    clip: true

    function focusField() {
        if (open)
            field.forceActiveFocus();
    }

    function requestClose() {
        closeRequested();
    }

    onOpenChanged: {
        if (open)
            Qt.callLater(focusField);
    }

    Rectangle {
        anchors.fill: parent
        color: Tokens.paper
    }

    Rectangle {
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: Tokens.border
        color: Tokens.lineStrong
    }

    TextInput {
        id: field
        objectName: "ryostore-search-field"
        anchors {
            left: parent.left
            right: resultLabel.left
            verticalCenter: parent.verticalCenter
            leftMargin: Tokens.s6
            rightMargin: Tokens.s5
        }
        text: layer.query
        color: Tokens.ink
        selectionColor: Tokens.tint16
        selectedTextColor: Tokens.ink
        font.family: Tokens.ui
        font.pixelSize: Tokens.fRow
        activeFocusOnTab: true
        Accessible.role: Accessible.EditableText
        Accessible.name: "Search RyoStore"
        Accessible.description: "Type to filter the current showroom collection"
        onTextEdited: layer.queryEdited(text)
        Keys.onEscapePressed: event => {
            layer.requestClose();
            event.accepted = true;
        }

        Text {
            anchors.fill: parent
            visible: field.text === ""
            text: "Search products"
            color: Tokens.inkMuted
            font: field.font
        }
    }

    Text {
        id: resultLabel
        anchors { right: parent.right; verticalCenter: parent.verticalCenter; rightMargin: Tokens.s6 }
        text: String(layer.resultCount) + " RESULT" + (layer.resultCount === 1 ? "" : "S")
        color: Tokens.inkDim
        font.family: Tokens.mono
        font.pixelSize: Tokens.fMicro
        font.letterSpacing: Tokens.trackLabel
    }
}
