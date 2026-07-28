pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import "../.." as Pill
import "../../Singletons"

// Quick-settings panel: left 44px icon tab rail + content pane.
// Three tabs: Home (controls + hero + calendar), Notifications, Weather.
// Rail bottom: Hub gear + colour picker moved from the old footer.
//
// TAB PUSH MOTION: single opaque sheet with z-ordering so the INCOMING tab
// (z:2) always renders above the OUTGOING tab (z:1). Both slide simultaneously
// — incoming from +width to 0, outgoing parallax to -width/3. Opaque surface
// backing fills any transient gap. On interrupt, the outgoing snaps invisible
// (visible=false) and the new pair takes over with no half-states.
//
// DETAIL PAGES (network/bt/audio/theme/clipboard) push over the entire panel
// with the same push mechanics; clipboard is only reachable via Super+V.
Item {
    id: root

    property real s: 1
    property bool open: false
    property real avail: 0
    signal requestClose()

    property string initialPage: ""

    implicitHeight: root.avail > 0 ? root.avail : 480

    // ---- tab state ---------------------------------------------------------
    // Tab indices: 0 = Home, 1 = Notifications, 2 = Weather
    property int activeTab: 0
    property int prevTab: -1
    property var tabSeen: ({})

    function switchToTab(idx) {
        if (idx === root.activeTab) return;
        root.prevTab = root.activeTab;
        root.activeTab = idx;
        if (idx > 0 && !root.tabSeen[idx]) {
            const next = Object.assign({}, root.tabSeen);
            next[idx] = true;
            root.tabSeen = next;
        }
        prevSnapTimer.restart();
    }

    // After the push completes, retire the outgoing tab: visible becomes false,
    // its x snaps to contentW (invisible), ready for next entry from the right.
    Timer {
        id: prevSnapTimer
        interval: Motion.push + 80
        onTriggered: root.prevTab = -1
    }

    // ---- detail-page navigation --------------------------------------------
    property string page: ""
    property var pageSeen: ({})

    function pageTitle() {
        switch (root.page) {
        case "network":   return qsTr("Wi-Fi");
        case "bluetooth": return qsTr("Bluetooth");
        case "audio-out": return qsTr("Sound output");
        case "audio-in":  return qsTr("Microphone");
        case "theme":     return qsTr("Colour scheme");
        case "clipboard": return qsTr("Clipboard");
        }
        return "";
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
        enabled: root.open
    }

    property bool watching: false
    function syncWatch() {
        if (root.open && !root.watching) { Toggles.watchers += 1; root.watching = true; }
        else if (!root.open && root.watching) { Toggles.watchers -= 1; root.watching = false; }
    }

    function applyInitialPage() {
        if (!root.open || root.initialPage === "") return;
        switch (root.initialPage) {
        case "notifications": root.page = ""; root.switchToTab(1); break;
        case "weather":       root.page = ""; root.switchToTab(2); break;
        // calendar no longer a separate tab — stay on Home
        case "calendar":      root.page = ""; root.switchToTab(0); break;
        default:
            root.page = root.initialPage;
        }
    }

    onOpenChanged: {
        if (root.open) root.applyInitialPage();
        else root.page = "";
        root.syncWatch();
    }
    onInitialPageChanged: if (root.open && root.initialPage !== "") root.applyInitialPage()
    onPageChanged: {
        if (root.page !== "" && !root.pageSeen[root.page]) {
            const next = Object.assign({}, root.pageSeen);
            next[root.page] = true;
            root.pageSeen = next;
        }
    }

    // ========================================================================
    // MAIN BAND: rail (z:2 for side-tip visibility) + content pane.
    // Parallaxes left when a detail page opens.
    // ========================================================================
    Item {
        id: mainBand
        width: parent.width; height: parent.height
        x: (root.page !== "") ? -root.width / 3 : 0
        visible: x > -root.width / 3 + 0.5
        Behavior on x { NumberAnimation { duration: Motion.push; easing.type: Motion.pushCurve } }

        QsTabRail {
            id: rail
            z: 10   // high z so side-tip bubble (z:1000 within rail subtree) clears all tab sheets
            height: parent.height
            activeTab: root.activeTab
            onTabActivated: idx => root.switchToTab(idx)
            onRequestClose: root.requestClose()
        }

        // Clip region for the tab content. The opaque backing Rectangle inside
        // ensures neither the wallpaper nor parent bleed through between tabs.
        Item {
            id: contentPane
            x: rail.implicitWidth
            width: parent.width - rail.implicitWidth
            height: parent.height
            clip: true

            // Each tab provides its own opaque backing (see individual Loader Items).
            // No extra rect here; that avoids a tone-seam on top of the homeTabItem header.

            // ----------------------------------------------------------------
            // TAB 0 — Home (always loaded; never lazy)
            // z: 2 when incoming, 1 when outgoing, 0 otherwise.
            // ----------------------------------------------------------------
            Item {
                id: homeTabItem
                width: contentPane.width; height: contentPane.height
                z: root.activeTab === 0 ? 2 : root.prevTab === 0 ? 1 : 0
                x: root.activeTab === 0 ? 0
                    : root.prevTab === 0 ? -contentPane.width / 3
                    : contentPane.width
                visible: root.activeTab === 0 || root.prevTab === 0
                Behavior on x {
                    enabled: root.activeTab === 0 || root.prevTab === 0
                    NumberAnimation { duration: Motion.push; easing.type: Motion.pushCurve }
                }
                // Opaque backing — ensures surface shows cleanly during push transitions.
                Rectangle { anchors.fill: parent; color: Theme.surface; z: -1 }


                // ---- Fixed header ----------------------------------------
                Item {
                    id: homeHeader
                    anchors.top: parent.top; anchors.topMargin: 10
                    anchors.left: parent.left; anchors.leftMargin: 12
                    anchors.right: parent.right; anchors.rightMargin: 12
                    height: hdrCol.implicitHeight

                    Column {
                        id: hdrCol
                        width: parent.width
                        spacing: 4

                        // Clock left + session cluster right
                        Item {
                            id: clockRow
                            width: parent.width; height: 44

                            Text {
                                id: clockText
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                // Constrain right so it can never reach the session buttons
                                anchors.right: sessionRow.left; anchors.rightMargin: 8
                                text: Qt.formatTime(clock.date, "HH:mm")
                                color: Theme.inkOn(Theme.effectiveSurface, Theme.onSurface)
                                font.family: Theme.fontPrimary
                                font.pixelSize: 34; font.weight: Font.Bold
                                elide: Text.ElideRight
                            }
                            Row {
                                id: sessionRow
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 4

                                QsIconButton {
                                    icon: "logout"; tip: qsTr("Log out"); tipBelow: true
                                    onClicked: Hyprland.dispatch("hl.dsp.exit()")
                                }
                                QsIconButton {
                                    icon: "lock"; tip: qsTr("Lock"); tipBelow: true
                                    onClicked: { Quickshell.execDetached(["ryoku-shell", "lock"]); root.requestClose(); }
                                }
                                QsIconButton {
                                    icon: "restart_alt"; danger: true; tip: qsTr("Reboot"); tipBelow: true
                                    onClicked: Quickshell.execDetached(["systemctl", "reboot"])
                                }
                                QsIconButton {
                                    icon: "power_settings_new"; danger: true; tip: qsTr("Shut down"); tipBelow: true
                                    onClicked: Quickshell.execDetached(["systemctl", "poweroff"])
                                }
                            }
                        }

                        // Date left + battery pill right
                        Item {
                            width: parent.width; height: 24
                            Text {
                                anchors.left: parent.left
                                anchors.right: Battery.present ? battPill.left : parent.right
                                anchors.rightMargin: Battery.present ? 6 : 0
                                anchors.verticalCenter: parent.verticalCenter
                                text: Qt.locale().toString(clock.date, "dddd") + ", " + Qt.formatDate(clock.date, "MMM d, yyyy")
                                color: Theme.inkOn(Theme.effectiveSurface, Theme.onSurfaceVariant, 3.0)
                                font.family: Theme.fontPrimary; font.pixelSize: Theme.fontSm
                                elide: Text.ElideRight
                            }
                            Rectangle {
                                id: battPill
                                visible: Battery.present
                                anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                                width: battRow.implicitWidth + 16; height: 22; radius: 11
                                color: Qt.rgba(Theme.onSurface.r, Theme.onSurface.g, Theme.onSurface.b, 0.07)
                                border.width: 1
                                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.25)
                                Row {
                                    id: battRow
                                    anchors.centerIn: parent; spacing: 4
                                    Pill.MaterialIcon {
                                        anchors.verticalCenter: parent.verticalCenter
                                        font.pixelSize: 13
                                        text: Battery.charging ? "bolt" : "battery_full"
                                        color: Theme.inkOn(Theme.effectiveSurface, Battery.charging ? Theme.primary : Theme.onSurfaceVariant, 3.0)
                                    }
                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: Battery.pct + "%"
                                        color: Theme.inkOn(Theme.effectiveSurface, Theme.onSurface)
                                        font.family: Theme.fontPrimary; font.pixelSize: Theme.fontSm - 2
                                        font.weight: Font.DemiBold
                                    }
                                }
                            }
                        }
                    }
                }

                // ---- Scrollable controls ------------------------------------
                Flickable {
                    id: homeFlick
                    anchors.top: homeHeader.bottom; anchors.topMargin: 10
                    anchors.bottom: homeDock.top; anchors.bottomMargin: 8
                    anchors.left: parent.left; anchors.leftMargin: 12
                    anchors.right: parent.right; anchors.rightMargin: 12
                    contentWidth: width
                    contentHeight: homeFlow.implicitHeight
                    clip: true; boundsBehavior: Flickable.StopAtBounds
                    interactive: contentHeight > height

                    Column {
                        id: homeFlow
                        width: parent.width
                        spacing: 12

                        QsSection { width: parent.width; label: qsTr("Connect") }
                        Grid {
                            id: tileGrid
                            width: parent.width
                            columns: 2; columnSpacing: 8; rowSpacing: 8
                            readonly property real tileW: (width - columnSpacing) / 2

                            QsTile {
                                width: tileGrid.tileW
                                icon: Network.kind === "ethernet" ? "lan" : "wifi"
                                label: qsTr("Wi-Fi")
                                sub: !Toggles.wifiOn ? qsTr("Off") : Network.activeSsid !== "" ? Network.activeSsid : qsTr("On")
                                on: Toggles.wifiOn; hasPage: true; pageTip: qsTr("Wi-Fi networks")
                                onToggled: Toggles.toggleWifi()
                                onPageRequested: root.page = "network"
                            }
                            QsTile {
                                width: tileGrid.tileW
                                icon: "bluetooth"; label: qsTr("Bluetooth")
                                sub: Toggles.btOn ? qsTr("On") : qsTr("Off")
                                on: Toggles.btOn; hasPage: true; pageTip: qsTr("Bluetooth devices")
                                onToggled: Toggles.toggleBt()
                                onPageRequested: root.page = "bluetooth"
                            }
                            QsTile {
                                width: tileGrid.tileW
                                icon: "flight"; label: qsTr("Airplane")
                                sub: Toggles.wifiOn ? qsTr("Off") : qsTr("On")
                                on: !Toggles.wifiOn; onToggled: Toggles.toggleWifi()
                            }
                            QsTile {
                                width: tileGrid.tileW
                                icon: "bedtime"; label: qsTr("Night light")
                                sub: Toggles.nightOn ? qsTr("On") : qsTr("Off")
                                on: Toggles.nightOn; onToggled: Toggles.toggleNight()
                            }
                        }

                        QsSection { width: parent.width; label: qsTr("Sound & display") }
                        Column {
                            width: parent.width; spacing: 4
                            QsSlider {
                                width: parent.width; icon: "speaker"
                                lit: root.open && root.page === "" && root.activeTab === 0
                                value: Audio.sink ? Audio.sink.audio.volume : 0
                                muted: Audio.sink ? Audio.sink.audio.muted : false
                                valueLabel: !Audio.sink ? "" : (Audio.sink.audio.muted ? qsTr("off") : Math.round(Audio.sink.audio.volume * 100) + "%")
                                peakNode: Audio.sink
                                peakEnabled: root.open && root.page === "" && root.activeTab === 0 && !!Audio.sink
                                hasPage: true
                                onMoved: v => { if (Audio.sink) Audio.sink.audio.volume = v; }
                                onIconTapped: { if (Audio.sink) Audio.sink.audio.muted = !Audio.sink.audio.muted; }
                                onPageRequested: root.page = "audio-out"
                            }
                            QsSlider {
                                width: parent.width; icon: "mic"
                                lit: root.open && root.page === "" && root.activeTab === 0
                                value: Audio.source && Audio.source.audio ? Audio.source.audio.volume : 0
                                muted: Audio.source && Audio.source.audio ? Audio.source.audio.muted : false
                                valueLabel: !Audio.source || !Audio.source.audio ? "" : (Audio.source.audio.muted ? qsTr("off") : Math.round(Audio.source.audio.volume * 100) + "%")
                                peakNode: Audio.source
                                peakEnabled: root.open && root.page === "" && root.activeTab === 0 && !!Audio.source
                                hasPage: true
                                onMoved: v => { if (Audio.source && Audio.source.audio) Audio.source.audio.volume = v; }
                                onIconTapped: { if (Audio.source && Audio.source.audio) Audio.source.audio.muted = !Audio.source.audio.muted; }
                                onPageRequested: root.page = "audio-in"
                            }
                            Pill.BrightnessControl {
                                width: parent.width; s: 1
                                active: root.open && root.page === "" && root.activeTab === 0
                            }
                        }

                        // Media hero (visible only while a player exists)
                        MediaHero {
                            width: parent.width
                            active: root.open && root.activeTab === 0 && root.page === ""
                        }

                        // Calendar card — lives below the hero on the Home tab
                        QsSection { width: parent.width; label: qsTr("Calendar") }
                        QsCalendarEmbed {
                            width: parent.width; s: 1
                            open: root.open && root.activeTab === 0
                        }

                        // System monitor — computer stats below the calendar
                        QsSection { width: parent.width; label: qsTr("System") }
                        Pill.SysMonitor {
                            width: parent.width; s: 1
                            active: root.open && root.activeTab === 0 && root.page === ""
                        }
                    }
                }

                // ---- Power dock pinned to bottom ----------------------------
                Column {
                    id: homeDock
                    anchors.bottom: parent.bottom; anchors.bottomMargin: 10
                    anchors.left: parent.left; anchors.leftMargin: 12
                    anchors.right: parent.right; anchors.rightMargin: 12
                    spacing: 6

                    Rectangle {
                        width: parent.width; height: 1
                        color: Qt.rgba(Theme.onSurface.r, Theme.onSurface.g, Theme.onSurface.b, 0.10)
                    }
                    QsSection {
                        visible: PowerProfiles.available
                        width: parent.width; label: qsTr("Power")
                    }
                    QsSeg {
                        visible: PowerProfiles.available
                        width: parent.width
                        current: PowerProfiles.profile
                        options: PowerProfiles.profiles.map(p => ({
                            id: p,
                            label: p === "power-saver" ? qsTr("Saver") : p.charAt(0).toUpperCase() + p.slice(1)
                        }))
                        onChose: id => PowerProfiles.setProfile(id)
                    }
                }
            }

            // ----------------------------------------------------------------
            // TAB 1 — Notifications (lazy; z-ordered as active or prev)
            // ----------------------------------------------------------------
            Loader {
                id: notifsLoader
                width: contentPane.width; height: contentPane.height
                active: root.tabSeen[1] === true
                z: root.activeTab === 1 ? 2 : root.prevTab === 1 ? 1 : 0
                visible: root.activeTab === 1 || root.prevTab === 1
                x: root.activeTab === 1 ? 0
                    : root.prevTab === 1 ? -contentPane.width / 3
                    : contentPane.width
                Behavior on x {
                    enabled: root.activeTab === 1 || root.prevTab === 1
                    NumberAnimation { duration: Motion.push; easing.type: Motion.pushCurve }
                }
                sourceComponent: Component {
                    Item {
                        // parent = notifsLoader
                        width: parent.width; height: parent.height
                        // Opaque backing for this tab (prevents see-through if z changes)
                        Rectangle { anchors.fill: parent; color: Theme.surface }
                        Flickable {
                            anchors.fill: parent
                            contentWidth: width
                            contentHeight: notifsEmbed.height + 24
                            clip: true; boundsBehavior: Flickable.StopAtBounds
                            interactive: contentHeight > height
                            MenuNotifications {
                                id: notifsEmbed
                                x: 12; y: 12
                                width: parent.width - 24
                                s: root.s
                                open: root.open && root.activeTab === 1
                                onRequestClose: root.requestClose()
                            }
                        }
                    }
                }
            }

            // ----------------------------------------------------------------
            // TAB 2 — Weather (lazy; z-ordered as active or prev)
            // ----------------------------------------------------------------
            Loader {
                id: wxLoader
                width: contentPane.width; height: contentPane.height
                active: root.tabSeen[2] === true
                z: root.activeTab === 2 ? 2 : root.prevTab === 2 ? 1 : 0
                visible: root.activeTab === 2 || root.prevTab === 2
                x: root.activeTab === 2 ? 0
                    : root.prevTab === 2 ? -contentPane.width / 3
                    : contentPane.width
                Behavior on x {
                    enabled: root.activeTab === 2 || root.prevTab === 2
                    NumberAnimation { duration: Motion.push; easing.type: Motion.pushCurve }
                }
                sourceComponent: Component {
                    Item {
                        width: parent.width; height: parent.height
                        Rectangle { anchors.fill: parent; color: Theme.surface }
                        Flickable {
                            anchors.fill: parent
                            contentWidth: width
                            contentHeight: wxEmbed.height + 24
                            clip: true; boundsBehavior: Flickable.StopAtBounds
                            interactive: contentHeight > height
                            MenuWeather {
                                id: wxEmbed
                                x: 12; y: 12
                                width: parent.width - 24
                                s: root.s
                                open: root.open && root.activeTab === 2
                            }
                        }
                    }
                }
            }
        }
    }

    // ========================================================================
    // DETAIL PAGE BAND — pushes in over the whole panel (full-width opaque sheet)
    // ========================================================================
    Item {
        id: pageBand
        width: parent.width; height: parent.height
        x: (root.page !== "") ? 0 : root.width
        visible: x < root.width - 0.5
        Behavior on x { NumberAnimation { duration: Motion.push; easing.type: Motion.pushCurve } }

        Rectangle { anchors.fill: parent; color: Theme.surface }

        Column {
            anchors.fill: parent; spacing: 8

            Item {
                width: parent.width; height: 42
                QsIconButton {
                    anchors.left: parent.left; anchors.leftMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    icon: "arrow_back"; onClicked: root.page = ""
                }
                Text {
                    anchors.centerIn: parent
                    text: root.pageTitle()
                    color: Theme.inkOn(Theme.effectiveSurface, Theme.onSurface)
                    font.family: Theme.fontPrimary; font.pixelSize: Theme.fontMd; font.weight: Font.DemiBold
                }
            }

            Flickable {
                width: parent.width; height: parent.height - 50
                contentWidth: width; contentHeight: pageStack.implicitHeight
                clip: true; boundsBehavior: Flickable.StopAtBounds
                interactive: contentHeight > height

                Column {
                    id: pageStack; width: parent.width

                    Loader {
                        width: pageStack.width
                        active: root.pageSeen["network"] === true; visible: root.page === "network"
                        sourceComponent: Component {
                            MenuNetwork { pageMode: true; width: parent.width; s: root.s; open: root.open && root.page === "network" }
                        }
                    }
                    Loader {
                        width: pageStack.width
                        active: root.pageSeen["bluetooth"] === true; visible: root.page === "bluetooth"
                        sourceComponent: Component {
                            MenuBluetooth { pageMode: true; width: parent.width; s: root.s; open: root.open && root.page === "bluetooth" }
                        }
                    }
                    Loader {
                        width: pageStack.width
                        active: root.pageSeen["audio-out"] === true; visible: root.page === "audio-out"
                        sourceComponent: Component {
                            MenuAudioOutput { pageMode: true; width: parent.width; s: root.s; open: root.open && root.page === "audio-out" }
                        }
                    }
                    Loader {
                        width: pageStack.width
                        active: root.pageSeen["audio-in"] === true; visible: root.page === "audio-in"
                        sourceComponent: Component {
                            MenuAudioInput { pageMode: true; width: parent.width; s: root.s; open: root.open && root.page === "audio-in" }
                        }
                    }
                    Loader {
                        width: pageStack.width
                        active: root.pageSeen["theme"] === true; visible: root.page === "theme"
                        sourceComponent: Component {
                            MenuTheme { width: parent.width; s: root.s; open: root.open && root.page === "theme" }
                        }
                    }
                    // Clipboard: only reachable via Super+V deep link.
                    Loader {
                        width: pageStack.width
                        active: root.pageSeen["clipboard"] === true; visible: root.page === "clipboard"
                        sourceComponent: Component {
                            MenuClipboard {
                                width: parent.width; s: root.s
                                open: root.open && root.page === "clipboard"
                                onRequestClose: root.requestClose()
                            }
                        }
                    }
                }
            }
        }
    }
}
