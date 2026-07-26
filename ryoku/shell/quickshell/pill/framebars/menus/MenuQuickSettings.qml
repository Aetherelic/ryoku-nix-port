pragma ComponentBehavior: Bound

import QtQuick
import "../../Singletons"

// The quick-settings stack (contract 06 sec 1): clock, network, bluetooth,
// audio out, audio in, power profiles, media player, then two four-tile quick
// action rows separated by 20px spacers. Rendered as one cohesive widget so the
// fixed reference stack does not depend on per-widget config. Entries abut with
// no gap (spacing 0); visual separation comes from each row's own surface tile,
// the media player's bordered card, and the explicit spacers.
Item {
    id: root

    property real s: 1
    property bool open: false
    signal requestClose()

    implicitHeight: col.implicitHeight

    Column {
        id: col
        width: root.width
        spacing: 0

        MenuClock { width: col.width; s: root.s; open: root.open }
        MenuNetwork { width: col.width; s: root.s; open: root.open }
        MenuBluetooth { width: col.width; s: root.s; open: root.open }
        MenuAudioOutput { width: col.width; s: root.s; open: root.open }
        MenuAudioInput { width: col.width; s: root.s; open: root.open }
        MenuPowerProfile { width: col.width; s: root.s; open: root.open }
        MenuMedia { width: col.width; s: root.s; open: root.open }

        Item { width: col.width; height: 20 }

        MenuQuickActions {
            width: col.width
            s: root.s
            open: root.open
            actions: ["airplane", "night-light", "color", "settings"]
            onRequestClose: root.requestClose()
        }

        Item { width: col.width; height: 20 }

        MenuQuickActions {
            width: col.width
            s: root.s
            open: root.open
            actions: ["logout", "lock", "reboot", "shutdown"]
            onRequestClose: root.requestClose()
        }
    }
}
