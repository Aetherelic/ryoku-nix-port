import QtQuick

QtObject {
    required property var keyring
    signal focusRestored()

    function handleClosed(id, context) {
        if (id !== "keyring" || !context || context.promptId !== keyring.promptId || !keyring.active || keyring.busy) return;
        keyring.dismiss();
        focusRestored();
    }
}
