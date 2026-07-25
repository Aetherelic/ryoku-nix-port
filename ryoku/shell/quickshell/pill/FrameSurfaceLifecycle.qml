import QtQuick

QtObject {
    required property var keyring
    signal focusRestored()

    function handleClosed(id) {
        if (id !== "keyring") return;
        keyring.dismiss();
        focusRestored();
    }
}
