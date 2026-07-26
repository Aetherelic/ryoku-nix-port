pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Services.Mpris
import "../.." as Pill
import "../../Singletons"

// Media player entry (contract 06 sec 2.10): a bordered now-playing card with a
// centered title and artist, a debounced seek scrubber flanked by elapsed and
// total time, and a centered transport row (shuffle, previous, play/pause, next,
// loop) whose buttons dim to their capability flags. With more than one real
// player a switcher header names the active one and steps between them.
//
// The whole entry stays hidden (no reserved height) until a real player exists;
// the shared Media pick already drops the live-wallpaper player. There is no
// album art: the reference card intentionally shows only text, scrubber and
// transport (contract 06 sec 6/9).
Item {
    id: root

    property real s: 1
    required property bool open

    // Non-wallpaper players in service order (no client sort); the same pick the
    // rest of the shell shares, so Media.player is one of these when non-empty.
    readonly property var players: Mpris.players.values.filter(function (p) { return p && !Media.isWallpaper(p); })
    // A local switcher pick overrides Media's auto-choice and falls back to it
    // once the picked player leaves the list.
    property var picked: null
    readonly property var player: (root.picked && root.players.indexOf(root.picked) !== -1) ? root.picked : Media.player
    readonly property int idx: root.player ? root.players.indexOf(root.player) : -1

    visible: root.players.length > 0
    implicitHeight: root.players.length > 0 ? content.implicitHeight : 0

    // --- seek state ---------------------------------------------------------
    // Polled elapsed seconds: the raw player.position only refreshes when read.
    property real posn: 0
    readonly property real len: (root.player && root.player.length > 0) ? root.player.length : 0
    readonly property real liveFrac: root.len > 0 ? Math.max(0, Math.min(1, root.posn / root.len)) : 0
    // While a seek is armed the scrubber and elapsed label hold the target so the
    // thumb never snaps back to a stream position that has not caught up yet.
    property bool seekArmed: false
    property bool seekSent: false
    property real seekFrac: 0
    readonly property real shownFrac: root.seekArmed ? root.seekFrac : root.liveFrac

    // "{h}:{mm}:{ss}" past an hour, else "{m}:{ss}".
    function fmtTime(sec) {
        sec = Math.max(0, Math.floor(sec));
        const h = Math.floor(sec / 3600);
        const m = Math.floor((sec % 3600) / 60);
        const r = sec % 60;
        const ss = (r < 10 ? "0" : "") + r;
        if (h >= 1)
            return h + ":" + (m < 10 ? "0" : "") + m + ":" + ss;
        return m + ":" + ss;
    }

    // Each scrub change previews immediately and restarts the debounce; the real
    // seek only lands 300ms after the last change stops (contract 06 sec 4/5).
    function onScrub(frac) {
        root.seekFrac = Math.max(0, Math.min(1, frac));
        root.seekArmed = true;
        root.seekSent = false;
        seekDebounce.restart();
    }

    function refreshPos() {
        root.posn = root.player ? root.player.position : 0;
    }

    // A switch or track change abandons any pending seek and re-reads position.
    onPlayerChanged: {
        seekDebounce.stop();
        seekIgnore.stop();
        root.seekArmed = false;
        root.seekSent = false;
        root.refreshPos();
    }

    Timer {
        id: posPoll
        interval: 1000
        repeat: true
        running: root.open && root.player !== null
        triggeredOnStart: true
        onTriggered: {
            root.refreshPos();
            // Resume live updates early once the stream reflects a sent seek.
            if (root.seekSent && Math.abs(root.posn - root.seekFrac * root.len) < 1.5) {
                root.seekArmed = false;
                root.seekSent = false;
                seekIgnore.stop();
            }
        }
    }

    Timer {
        id: seekDebounce
        interval: 300
        repeat: false
        onTriggered: {
            if (root.player && root.len > 0) {
                root.player.position = root.seekFrac * root.len;
                root.seekSent = true;
                seekIgnore.restart();
            } else {
                root.seekArmed = false;
            }
        }
    }

    // The stream never reflected the seek inside the window, so trust it again.
    Timer {
        id: seekIgnore
        interval: 3000
        repeat: false
        onTriggered: {
            root.seekArmed = false;
            root.seekSent = false;
        }
    }

    function iconShuffle() {
        return (root.player && root.player.shuffle) ? "shuffle_on" : "shuffle";
    }
    function iconLoop() {
        if (root.player) {
            if (root.player.loopState === MprisLoopState.Track)
                return "repeat_one_on";
            if (root.player.loopState === MprisLoopState.Playlist)
                return "repeat_on";
        }
        return "repeat";
    }
    // None -> Playlist -> Track -> None (contract 06 sec 4).
    function cycleLoop() {
        if (!root.player)
            return;
        if (root.player.loopState === MprisLoopState.None)
            root.player.loopState = MprisLoopState.Playlist;
        else if (root.player.loopState === MprisLoopState.Playlist)
            root.player.loopState = MprisLoopState.Track;
        else
            root.player.loopState = MprisLoopState.None;
    }

    // A surface tile carrying one centered Material Symbols glyph; content dims to
    // the disabled tone through the shared MenuButton when its capability is off.
    component IconButton: MenuButton {
        id: ib
        property alias iconName: glyph.text
        minW: Theme.iconSm + ib.pad * 2
        minH: Theme.iconSm + ib.pad * 2
        Pill.MaterialIcon {
            id: glyph
            anchors.centerIn: parent
            font.pixelSize: Theme.iconSm
            color: ib.contentColor
        }
    }

    Column {
        id: content
        width: parent.width
        spacing: Theme.paddingMd

        // --- switcher header (only with more than one player) ---------------
        Item {
            id: switcher
            width: parent.width
            visible: root.players.length > 1
            height: visible ? Math.max(swName.implicitHeight, switchBtns.implicitHeight) : 0

            Text {
                id: swName
                anchors.left: parent.left
                anchors.right: switchBtns.left
                anchors.rightMargin: Theme.paddingMd
                anchors.verticalCenter: parent.verticalCenter
                text: root.player ? (root.player.identity.length > 0 ? root.player.identity : root.player.dbusName) : ""
                color: Theme.onSurfaceVariant
                font.family: Theme.fontPrimary
                font.pixelSize: Theme.fontSm
                font.weight: Font.Bold
                elide: Text.ElideRight
            }
            Row {
                id: switchBtns
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.paddingMd

                IconButton {
                    iconName: "chevron_left"
                    enabled: root.idx > 0
                    onClicked: if (root.idx > 0) root.picked = root.players[root.idx - 1]
                }
                IconButton {
                    iconName: "chevron_right"
                    enabled: root.idx >= 0 && root.idx + 1 < root.players.length
                    onClicked: if (root.idx >= 0 && root.idx + 1 < root.players.length) root.picked = root.players[root.idx + 1]
                }
            }
        }

        // --- the bordered now-playing card ----------------------------------
        Rectangle {
            id: card
            width: parent.width
            color: "transparent"
            radius: Theme.radiusWidget
            border.width: Theme.borderWidth
            border.color: Theme.outline
            implicitHeight: cardCol.implicitHeight + Theme.paddingMd * 2

            Column {
                id: cardCol
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Theme.paddingMd
                spacing: Theme.paddingSm

                // Title (dimmer variant tone) and artist, both centered; a long
                // line elides rather than marqueeing (see report).
                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: root.player ? (root.player.trackTitle || "") : ""
                    color: Theme.onSurfaceVariant
                    font.family: Theme.fontPrimary
                    font.pixelSize: Theme.fontSm
                    font.weight: Font.Bold
                    elide: Text.ElideRight
                }
                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: root.player ? Theme.joinArtists(root.player.trackArtists, root.player.trackArtist) : ""
                    color: Theme.onSurface
                    font.family: Theme.fontPrimary
                    font.pixelSize: Theme.fontSm
                    font.weight: Font.Bold
                    elide: Text.ElideRight
                }

                // Time + scrubber row: elapsed | slider | total, 20px on each
                // side of the bar.
                Item {
                    width: parent.width
                    height: scrubber.implicitHeight

                    Text {
                        id: curTime
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.fmtTime(root.shownFrac * root.len)
                        color: Theme.onSurface
                        font.family: Theme.fontPrimary
                        font.pixelSize: Theme.fontSm
                    }
                    Text {
                        id: totTime
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.fmtTime(root.len)
                        color: Theme.onSurface
                        font.family: Theme.fontPrimary
                        font.pixelSize: Theme.fontSm
                    }
                    RevealerRowSlider {
                        id: scrubber
                        anchors.left: curTime.right
                        anchors.right: totTime.left
                        anchors.leftMargin: 20
                        anchors.rightMargin: 20
                        anchors.verticalCenter: parent.verticalCenter
                        rightMargin: 0
                        enabled: root.player ? root.player.canSeek : false
                        value: root.shownFrac
                        onMoved: frac => root.onScrub(frac)
                    }
                }

                // Centered transport row; each button dims to its capability.
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 12

                    IconButton {
                        iconName: root.iconShuffle()
                        enabled: root.player ? root.player.shuffleSupported : false
                        onClicked: if (root.player) root.player.shuffle = !root.player.shuffle
                    }
                    IconButton {
                        iconName: "skip_previous"
                        enabled: root.player ? root.player.canGoPrevious : false
                        onClicked: if (root.player) root.player.previous()
                    }
                    IconButton {
                        iconName: (root.player && root.player.isPlaying) ? "pause" : "play_arrow"
                        enabled: root.player ? root.player.canTogglePlaying : false
                        onClicked: if (root.player) root.player.togglePlaying()
                    }
                    IconButton {
                        iconName: "skip_next"
                        enabled: root.player ? root.player.canGoNext : false
                        onClicked: if (root.player) root.player.next()
                    }
                    IconButton {
                        iconName: root.iconLoop()
                        enabled: root.player ? root.player.loopSupported : false
                        onClicked: root.cycleLoop()
                    }
                }
            }
        }
    }
}
