pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import "../.." as Pill
import "../../Singletons"

// The quick-settings sidebar: the shell's system-settings home. One full-height
// left panel with three bands - a clock/battery header, the control body
// (connectivity tile grid, sound and display sliders, power profile, media),
// and a session footer pinned to the bottom edge. Wifi, bluetooth, and audio
// devices open as slide-in detail pages inside the same panel, so navigation
// never spawns a second surface and never grows an accordion mid-list.
// (Divergence from contract 06's fixed drawer stack, by user direction.)
Item {
    id: root

    property real s: 1
    property bool open: false
    // Full available body height, passed down from MenuColumn when this widget
    // is the panel's sole occupant; 0 falls back to natural stacking height.
    property real avail: 0
    signal requestClose()

    implicitHeight: root.avail > 0 ? root.avail : mainBody.implicitHeight

    // ---- detail-page navigation --------------------------------------------
    // "" = main; else network | bluetooth | audio-out | audio-in.
    property string page: ""
    // A bar indicator can deep-link into a page: this initial page is applied
    // when the sidebar opens (and while open, if it changes). "" is the main view.
    property string initialPage: ""
    // Pages mount on first visit and stay cached (the iNiR lesson), so opening
    // the sidebar loads only the main view. seen[page] latches on first show.
    property var seen: ({})
    function pageTitle() {
        switch (root.page) {
        case "network": return qsTr("Wi-Fi");
        case "bluetooth": return qsTr("Bluetooth");
        case "audio-out": return qsTr("Sound output");
        case "audio-in": return qsTr("Microphone");
        case "theme": return qsTr("Colour scheme");
        case "notifications": return qsTr("Notifications");
        case "clipboard": return qsTr("Clipboard");
        case "media": return qsTr("Media");
        }
        return "";
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
        enabled: root.open
    }

    // Keep the toggle probes warm while the sidebar shows (wifi/night state).
    property bool watching: false
    function syncWatch() {
        if (root.open && !root.watching) { Toggles.watchers += 1; root.watching = true; }
        else if (!root.open && root.watching) { Toggles.watchers -= 1; root.watching = false; }
    }
    onOpenChanged: {
        if (root.open) { if (root.initialPage !== "") root.page = root.initialPage; }
        else root.page = "";
        root.syncWatch();
    }
    onInitialPageChanged: if (root.open && root.initialPage !== "") root.page = root.initialPage;
    onPageChanged: {
        if (root.page !== "" && !root.seen[root.page]) {
            const next = Object.assign({}, root.seen);
            next[root.page] = true;
            root.seen = next;
        }
    }

    // ---- main band ----------------------------------------------------------
    Item {
        id: mainBody
        width: parent.width
        height: parent.height
        // Push navigation: the main band glides left under the incoming page
        // (a third of the travel, the classic parallax) and stays fully opaque;
        // the long OutQuint settle keeps the speed natural, never snappy.
        x: (root.page !== "") ? -root.width / 3 : 0
        visible: x > -root.width / 3 + 0.5
        implicitHeight: headerCol.implicitHeight + 420
        Behavior on x { NumberAnimation { duration: Motion.push; easing.type: Motion.pushCurve } }

        Column {
            id: headerCol
            width: parent.width
            spacing: 4

            // Row 1: the clock left, session actions right (user decision).
            Item {
                width: parent.width
                height: 44

                Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: Qt.formatTime(clock.date, "HH:mm")
                    color: Theme.inkOn(Theme.effectiveSurface, Theme.onSurface)
                    font.family: Theme.fontPrimary
                    font.pixelSize: 34
                    font.weight: Font.Bold
                }

                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8

                    QsIconButton {
                        icon: "logout"
                        tip: qsTr("Log out")
                        onClicked: Hyprland.dispatch("hl.dsp.exit()")
                    }
                    QsIconButton {
                        icon: "lock"
                        tip: qsTr("Lock")
                        onClicked: { Quickshell.execDetached(["ryoku-shell", "lock"]); root.requestClose(); }
                    }
                    QsIconButton {
                        icon: "restart_alt"
                        danger: true
                        tip: qsTr("Reboot")
                        onClicked: Quickshell.execDetached(["systemctl", "reboot"])
                    }
                    QsIconButton {
                        icon: "power_settings_new"
                        danger: true
                        tip: qsTr("Shut down")
                        onClicked: Quickshell.execDetached(["systemctl", "poweroff"])
                    }
                }
            }

            // Row 2: the date left, battery right.
            Item {
                width: parent.width
                height: 24

                Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: Qt.locale().toString(clock.date, "dddd") + ", " + Qt.formatDate(clock.date, "MMM d, yyyy")
                    color: Theme.inkOn(Theme.effectiveSurface, Theme.onSurfaceVariant, 3.0)
                    font.family: Theme.fontPrimary
                    font.pixelSize: Theme.fontSm
                }

                Rectangle {
                    visible: Battery.present
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: battRow.implicitWidth + 20
                    height: 22
                    radius: 11
                    color: Qt.rgba(Theme.onSurface.r, Theme.onSurface.g, Theme.onSurface.b, 0.07)
                    border.width: 1
                    border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.25)
                    Row {
                        id: battRow
                        anchors.centerIn: parent
                        spacing: 4
                        Pill.MaterialIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            font.pixelSize: 14
                            text: Battery.charging ? "bolt" : "battery_full"
                            color: Theme.inkOn(Theme.effectiveSurface, Battery.charging ? Theme.primary : Theme.onSurfaceVariant, 3.0)
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: Battery.pct + "%"
                            color: Theme.inkOn(Theme.effectiveSurface, Theme.onSurface)
                            font.family: Theme.fontPrimary
                            font.pixelSize: Theme.fontSm - 1
                            font.weight: Font.DemiBold
                        }
                    }
                }
            }
        }

        // The control flow scrolls between the fixed header and the docked
        // power/footer band, so tall content (calendar, weather) never runs
        // under the dock.
        Flickable {
            anchors.top: headerCol.bottom
            anchors.topMargin: 12
            anchors.bottom: bottomDock.top
            anchors.bottomMargin: 12
            width: parent.width
            contentWidth: width
            contentHeight: flowCol.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            interactive: contentHeight > height

        Column {
            id: flowCol
            width: parent.width
            spacing: 14

            // Connectivity grid.
            QsSection { width: parent.width; label: qsTr("Connect") }
            Grid {
                id: tileGrid
                width: parent.width
                columns: 2
                columnSpacing: 8
                rowSpacing: 8
                readonly property real tileW: (width - columnSpacing) / 2

                QsTile {
                    width: tileGrid.tileW
                    icon: Network.kind === "ethernet" ? "lan" : "wifi"
                    label: qsTr("Wi-Fi")
                    sub: !Toggles.wifiOn ? qsTr("Off")
                        : Network.activeSsid !== "" ? Network.activeSsid : qsTr("On")
                    on: Toggles.wifiOn
                    hasPage: true
                    pageTip: qsTr("Wi-Fi networks")
                    onToggled: Toggles.toggleWifi()
                    onPageRequested: root.page = "network"
                }
                QsTile {
                    width: tileGrid.tileW
                    icon: "bluetooth"
                    label: qsTr("Bluetooth")
                    sub: Toggles.btOn ? qsTr("On") : qsTr("Off")
                    on: Toggles.btOn
                    hasPage: true
                    pageTip: qsTr("Bluetooth devices")
                    onToggled: Toggles.toggleBt()
                    onPageRequested: root.page = "bluetooth"
                }
                QsTile {
                    width: tileGrid.tileW
                    icon: "flight"
                    label: qsTr("Airplane")
                    sub: Toggles.wifiOn ? qsTr("Off") : qsTr("On")
                    on: !Toggles.wifiOn
                    onToggled: Toggles.toggleWifi()
                }
                QsTile {
                    width: tileGrid.tileW
                    icon: "bedtime"
                    label: qsTr("Night light")
                    sub: Toggles.nightOn ? qsTr("On") : qsTr("Off")
                    on: Toggles.nightOn
                    onToggled: Toggles.toggleNight()
                }
            }

            // Sound and display sliders.
            QsSection { width: parent.width; label: qsTr("Sound & display") }
            Column {
                width: parent.width
                spacing: 4

                QsSlider {
                    width: parent.width
                    icon: "speaker"
                    lit: root.open && !(root.page !== "")
                    value: Audio.sink ? Audio.sink.audio.volume : 0
                    muted: Audio.sink ? Audio.sink.audio.muted : false
                    valueLabel: !Audio.sink ? "" : (Audio.sink.audio.muted ? qsTr("off") : Math.round(Audio.sink.audio.volume * 100) + "%")
                    peakNode: Audio.sink
                    peakEnabled: root.open && !(root.page !== "") && !!Audio.sink
                    hasPage: true
                    pageTip: qsTr("Output devices")
                    onMoved: v => { if (Audio.sink) Audio.sink.audio.volume = v; }
                    onIconTapped: { if (Audio.sink) Audio.sink.audio.muted = !Audio.sink.audio.muted; }
                    onPageRequested: root.page = "audio-out"
                }
                QsSlider {
                    width: parent.width
                    icon: "mic"
                    lit: root.open && !(root.page !== "")
                    value: Audio.source && Audio.source.audio ? Audio.source.audio.volume : 0
                    muted: Audio.source && Audio.source.audio ? Audio.source.audio.muted : false
                    valueLabel: !Audio.source || !Audio.source.audio ? ""
                        : (Audio.source.audio.muted ? qsTr("off") : Math.round(Audio.source.audio.volume * 100) + "%")
                    peakNode: Audio.source
                    peakEnabled: root.open && !(root.page !== "") && !!Audio.source
                    hasPage: true
                    pageTip: qsTr("Input devices")
                    onMoved: v => { if (Audio.source && Audio.source.audio) Audio.source.audio.volume = v; }
                    onIconTapped: { if (Audio.source && Audio.source.audio) Audio.source.audio.muted = !Audio.source.audio.muted; }
                    onPageRequested: root.page = "audio-in"
                }
            }

            Pill.BrightnessControl {
                width: parent.width
                s: 1
                active: root.open && !(root.page !== "")
            }

            // Shelf: notifications, clipboard, and the media player each open as
            // a slide-in page (their sparse standalone menus retired into here).
            QsSection { width: parent.width; label: qsTr("Shelf") }
            Column {
                width: parent.width
                spacing: 8
                QsNavRow {
                    width: parent.width
                    icon: Flags.dnd ? "notifications_off" : "notifications"
                    label: qsTr("Notifications")
                    sub: Notifs.history.length > 0 ? String(Notifs.history.length) : qsTr("None")
                    onActivated: root.page = "notifications"
                }
                QsNavRow {
                    width: parent.width
                    icon: "content_paste"
                    label: qsTr("Clipboard")
                    sub: Clipboard.entries.length > 0 ? String(Clipboard.entries.length) : qsTr("Empty")
                    onActivated: root.page = "clipboard"
                }
                QsNavRow {
                    width: parent.width
                    icon: "music_note"
                    label: qsTr("Media")
                    sub: Media.present ? Media.line : qsTr("Nothing playing")
                    onActivated: root.page = "media"
                }
            }

            // The clock menu body, the translated reference surface (calendar,
            // weather, conditions), moved whole into the sidebar. One calendar
            // for the shell; the standalone clock menu is retired.
            MenuClock { width: parent.width; s: root.s; open: root.open && root.page === "" }
        }
        }

        // Sumi edge: the lit top line of the docked footer band, separating it
        // from the scrolling content above.
        Rectangle {
            anchors.left: bottomDock.left
            anchors.right: bottomDock.right
            anchors.bottom: bottomDock.top
            anchors.bottomMargin: 12
            height: 1
            color: Qt.rgba(Theme.onSurface.r, Theme.onSurface.g, Theme.onSurface.b, 0.10)
        }

        // Power and session footer docked to the panel's bottom edge.
        Column {
            id: bottomDock
            anchors.bottom: parent.bottom
            width: parent.width
            spacing: 8

            QsSection {
                visible: PowerProfiles.available
                width: parent.width
                label: qsTr("Power")
            }
            QsSeg {
                visible: PowerProfiles.available
                width: parent.width
                current: PowerProfiles.profile
                options: PowerProfiles.profiles.map(p => ({
                    id: p,
                    label: p === "power-saver" ? qsTr("Saver")
                        : p.charAt(0).toUpperCase() + p.slice(1)
                }))
                onChose: id => PowerProfiles.setProfile(id)
            }

            Rectangle {
                width: parent.width
                height: 1
                color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.25)
            }

            Item {
                width: parent.width
                height: 38

                Row {
                    anchors.left: parent.left
                    spacing: 8
                    QsIconButton {
                        icon: "settings"
                        tip: qsTr("Ryoku Hub")
                        onClicked: { Quickshell.execDetached(["ryoku-shell", "hub", "open"]); root.requestClose(); }
                    }
                    QsIconButton {
                        icon: "colorize"
                        tip: qsTr("Pick a colour")
                        onClicked: { Quickshell.execDetached(["ryoku-cmd-color-picker"]); root.requestClose(); }
                    }
                }

            }
        }
    }

    // ---- detail page band ---------------------------------------------------
    Item {
        id: pageBody
        width: parent.width
        height: parent.height
        // The page rides in over the gliding main band, full width, no fade.
        x: (root.page !== "") ? 0 : root.width
        visible: x < root.width - 0.5
        Behavior on x { NumberAnimation { duration: Motion.push; easing.type: Motion.pushCurve } }

        // Opaque panel backing: the page rides in as a solid sheet, so the
        // parallaxing main band never shows through mid-transition.
        Rectangle {
            anchors.fill: parent
            color: Theme.surface
        }

        Column {
            anchors.fill: parent
            spacing: 8

            Item {
                width: parent.width
                height: 42

                QsIconButton {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    icon: "arrow_back"
                    onClicked: root.page = ""
                }
                Text {
                    anchors.centerIn: parent
                    text: root.pageTitle()
                    color: Theme.inkOn(Theme.effectiveSurface, Theme.onSurface)
                    font.family: Theme.fontPrimary
                    font.pixelSize: Theme.fontMd
                    font.weight: Font.DemiBold
                }
            }

            Flickable {
                width: parent.width
                height: parent.height - 50
                contentWidth: width
                contentHeight: pageStack.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                interactive: contentHeight > height

                Column {
                    id: pageStack
                    width: parent.width

                    Loader {
                        width: pageStack.width
                        active: root.seen["network"] === true
                        visible: root.page === "network"
                        sourceComponent: Component {
                            MenuNetwork {
                                pageMode: true
                                width: parent.width
                                s: root.s
                                open: root.open && root.page === "network"
                            }
                        }
                    }
                    Loader {
                        width: pageStack.width
                        active: root.seen["bluetooth"] === true
                        visible: root.page === "bluetooth"
                        sourceComponent: Component {
                            MenuBluetooth {
                                pageMode: true
                                width: parent.width
                                s: root.s
                                open: root.open && root.page === "bluetooth"
                            }
                        }
                    }
                    Loader {
                        width: pageStack.width
                        active: root.seen["audio-out"] === true
                        visible: root.page === "audio-out"
                        sourceComponent: Component {
                            MenuAudioOutput {
                                pageMode: true
                                width: parent.width
                                s: root.s
                                open: root.open && root.page === "audio-out"
                            }
                        }
                    }
                    Loader {
                        width: pageStack.width
                        active: root.seen["audio-in"] === true
                        visible: root.page === "audio-in"
                        sourceComponent: Component {
                            MenuAudioInput {
                                pageMode: true
                                width: parent.width
                                s: root.s
                                open: root.open && root.page === "audio-in"
                            }
                        }
                    }
                    Loader {
                        width: pageStack.width
                        active: root.seen["theme"] === true
                        visible: root.page === "theme"
                        sourceComponent: Component {
                            MenuTheme {
                                width: parent.width
                                s: root.s
                                open: root.open && root.page === "theme"
                            }
                        }
                    }
                    Loader {
                        width: pageStack.width
                        active: root.seen["notifications"] === true
                        visible: root.page === "notifications"
                        sourceComponent: Component {
                            MenuNotifications {
                                width: parent.width
                                s: root.s
                                open: root.open && root.page === "notifications"
                                onRequestClose: root.requestClose()
                            }
                        }
                    }
                    Loader {
                        width: pageStack.width
                        active: root.seen["clipboard"] === true
                        visible: root.page === "clipboard"
                        sourceComponent: Component {
                            MenuClipboard {
                                width: parent.width
                                s: root.s
                                open: root.open && root.page === "clipboard"
                                onRequestClose: root.requestClose()
                            }
                        }
                    }
                    Loader {
                        width: pageStack.width
                        active: root.seen["media"] === true
                        visible: root.page === "media"
                        sourceComponent: Component {
                            Column {
                                width: parent.width
                                spacing: 8
                                MenuMedia {
                                    width: parent.width
                                    s: root.s
                                    open: root.open && root.page === "media"
                                }
                                Text {
                                    width: parent.width
                                    visible: !Media.present
                                    text: qsTr("Nothing playing")
                                    color: Theme.inkOn(Theme.effectiveSurface, Theme.onSurfaceVariant, 3.0)
                                    font.family: Theme.fontPrimary
                                    font.pixelSize: Theme.fontMd
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
