pragma ComponentBehavior: Bound

import QtQuick

// The static-icon widgets. Clipboard opens the quick-settings clipboard page,
// screenshot and wallpaper open their own menus, and the rest fire a direct
// action (lock/logout/reboot/shutdown/color-picker). Contract 04 sec 3.2.
Item {
    id: root

    required property string actionId
    required property string edge
    required property real scale
    signal menuRequested(string id, rect ownerRect)
    signal actionRequested(string id)

    // screenshot/wallpaper open their own menus; clipboard deep-links into the
    // quick-settings clipboard page (its standalone menu retired).
    readonly property var menuIds: ({ "screenshot": true, "wallpaper": true })
    readonly property var glyphs: ({
        "app-launcher": "view-app-grid",
        "lock": "system-lock-screen",
        "logout": "system-log-out",
        "reboot": "system-reboot",
        "shutdown": "system-shutdown",
        "screenshot": "video-display",
        "wallpaper": "wallpaper",
        "clipboard": "edit-paste",
        "color-picker": "color-select"
    })

    implicitWidth: btn.implicitWidth
    implicitHeight: btn.implicitHeight

    RailButton {
        id: btn
        anchors.centerIn: parent
        edge: root.edge
        scale: root.scale
        icon: root.glyphs[root.actionId] || "application-x-executable"
        onClicked: {
            if (root.actionId === "clipboard")
                root.menuRequested("quick-settings#clipboard", Qt.rect(0, 0, root.width, root.height));
            else if (root.menuIds[root.actionId])
                root.menuRequested(root.actionId, Qt.rect(0, 0, root.width, root.height));
            else
                root.actionRequested(root.actionId);
        }
    }
}
