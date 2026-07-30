import QtQuick
import QtQuick.Shapes
import QtQuick.Effects
import Quickshell.Widgets
import "../../shared/Singletons"
import "metrics.js" as MainMetrics
import "../../shared/lib/radio.js" as RadioLib
import "." as MainVariant

// Now-playing detail: cover art over a blurred bleed backdrop, title/artist, a
// compact prev/play-pause/next transport row, and the signature wavy seekbar (a
// sine while playing, flat when paused). Reads the active MPRIS player supplied
// by Launcher.qml. The FrameAnimation that drives the wave repaints only while
// playing and visible, so an idle launcher costs nothing. Transport buttons dim
// from the player's can* flags so the card degrades gracefully (streams/ads).
// Cover art comes from the active player or the live-radio engine; the music-note
// fallback keeps missing metadata explicit without a background network lookup.
Item {
    id: root

    property real s: 1
    property var player: null

    readonly property bool hasPlayer: player !== null && player !== undefined
    readonly property bool playing: hasPlayer && player.isPlaying
    // The ryoku radio wears a different coat: ON AIR eyebrow, station name, a
    // LIVE pulse where a track would show elapsed/total, and no seekbar — a
    // broadcast has no position to scrub.
    readonly property bool radio: hasPlayer && RadioLib.isRadioPlayer(player.dbusName, player.trackTitle)
    // The player's own title, but a raw URL-ish stream title (a browser tab, or an
    // mpv still resolving) is suppressed to a neutral label, not shown as a URL.
    readonly property string rawTitle: hasPlayer && player.trackTitle ? player.trackTitle : ""
    readonly property bool rawIsUrl: rawTitle.indexOf("watch?v=") !== -1
        || /^(https?:\/\/|www\.)/i.test(rawTitle)
    readonly property string title: radio ? rawTitle.slice(RadioLib.TITLE_PREFIX.length)
        : (rawTitle.length > 0 && !rawIsUrl ? rawTitle : "Nothing playing")
    readonly property string artist: radio
        ? (Radio.fellBack ? "internet radio · fallback station" : "internet radio · 24/7 live")
        : (hasPlayer ? Theme.joinArtists(player.trackArtists, player.trackArtist) : "")
    readonly property string artUrl:
        hasPlayer && player.trackArtUrl ? player.trackArtUrl : ""
    readonly property string effectiveArt:
        radio ? Radio.artUrl : artUrl
    readonly property real positionSec: hasPlayer ? player.position : 0
    readonly property real lengthSec: hasPlayer && player.length > 0 ? player.length : 0
    readonly property real frac: lengthSec > 0 ? Math.max(0, Math.min(1, positionSec / lengthSec)) : 0
    readonly property bool canPlay: hasPlayer && player.canTogglePlaying
    readonly property bool canNext: hasPlayer && player.canGoNext
    readonly property bool canPrev: hasPlayer && player.canGoPrevious
    // Scrub-to-seek: canSeek gates it (the player allows a seek and has a known
    // length); while dragging, the fill follows the cursor and the elapsed label
    // previews the target, committed to player.position on release. Never on a
    // radio: a live stream's "length" is whatever the buffer claims.
    readonly property bool canSeek: hasPlayer && !radio && player.canSeek && lengthSec > 0
    property bool scrubbing: false
    property real scrubFrac: 0

    // "m:ss" for the elapsed and total labels.
    function fmt(sec) {
        if (!(sec > 0))
            return "0:00";
        var s = Math.floor(sec);
        var m = Math.floor(s / 60);
        var r = s % 60;
        return m + ":" + (r < 10 ? "0" + r : r);
    }

    implicitHeight: 148 * s


    ClippingRectangle {
        anchors.fill: parent
        radius: MainMetrics.radiusRow * root.s
        color: Theme.drawer

        Image {
            id: bleed
            anchors.fill: parent
            source: root.effectiveArt
            sourceSize: Qt.size(128, 128)
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
            visible: false
        }
        MultiEffect {
            anchors.fill: parent
            source: bleed
            scale: 1.12
            visible: !Performance.blurDisabled && root.effectiveArt !== "" && bleed.status === Image.Ready
            blurEnabled: !Performance.blurDisabled
            blur: 0.95
            blurMax: 48
            saturation: 0.1
        }
        // Veil over the bleed so title/artist stay legible on any album art.
        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(Theme.drawer.r, Theme.drawer.g, Theme.drawer.b, 0.78)
        }


        ClippingRectangle {
            id: cover
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.margins: 12 * root.s
            width: height
            radius: Theme.radius
            color: Theme.tileBg

            Image {
                anchors.fill: parent
                source: root.effectiveArt
                sourceSize: Qt.size(Math.ceil(width * 2), Math.ceil(height * 2))
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
                visible: status === Image.Ready
            }
            // Music-note fallback when the player has no art URL. Kept as an
            // inline Text so NowPlaying has no external glyph dependency.
            Text {
                anchors.centerIn: parent
                visible: root.effectiveArt === "" && !root.radio
                text: "\u266a"
                color: Theme.subtle
                font.family: Theme.font
                font.pixelSize: 28 * root.s
            }
            // The radio's station plate: a broadcast mark instead of a cover \u2014
            // no album exists, and an iTunes guess would be someone else's.
            Column {
                anchors.centerIn: parent
                visible: root.radio && root.effectiveArt === ""
                spacing: 2 * root.s
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "\u25ce"
                    color: Theme.vermLit
                    font.family: Theme.font
                    font.pixelSize: 30 * root.s
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "ON AIR"
                    color: Theme.vermLit
                    font.family: Theme.mono
                    font.pixelSize: 9 * root.s
                    font.letterSpacing: 2
                }
            }
        }

        Column {
            id: meta
            anchors.left: cover.right
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.leftMargin: 14 * root.s
            anchors.rightMargin: 14 * root.s
            anchors.topMargin: 16 * root.s
            spacing: 4 * root.s

            Row {
                width: parent.width
                spacing: 6 * root.s
                MainVariant.BrandMark {
                    anchors.verticalCenter: parent.verticalCenter
                    size: MainMetrics.fontEyebrow * root.s
                    color: Theme.vermLit
                }
                // the radio's tally lamp: a slow pulse that says "broadcast",
                // where a track just states NOW PLAYING.
                Rectangle {
                    id: tallyDot
                    visible: root.radio
                    anchors.verticalCenter: parent.verticalCenter
                    width: 6 * root.s
                    height: width
                    radius: width / 2
                    color: Theme.vermLit
                    SequentialAnimation on opacity {
                        running: root.radio && root.visible && root.playing
                        loops: Animation.Infinite
                        NumberAnimation { from: 1; to: 0.25; duration: 900; easing.type: Easing.InOutSine }
                        NumberAnimation { from: 0.25; to: 1; duration: 900; easing.type: Easing.InOutSine }
                        onStopped: tallyDot.opacity = 1
                    }
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.radio ? "ON AIR · LIVE RADIO" : " NOW PLAYING"
                    color: Theme.vermLit
                    font.family: Theme.font
                    font.pixelSize: MainMetrics.fontEyebrow * root.s
                    font.letterSpacing: 1.5
                }
            }
            Text {
                width: parent.width
                text: root.title
                color: Theme.bright
                font.family: Theme.font
                font.pixelSize: MainMetrics.fontTitle * root.s
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }
            Text {
                width: parent.width
                text: root.artist
                color: Theme.subtle
                font.family: Theme.font
                font.pixelSize: MainMetrics.fontSubtitle * root.s
                elide: Text.ElideRight
                visible: root.artist.length > 0
            }
        }

        // MPRIS never pushes position, so poll it while playing to advance the
        // seek fill and the elapsed label; re-reading `position` is the standard
        // Quickshell pattern (see pill Media.qml).
        Timer {
            interval: 500
            running: root.visible && root.playing
            repeat: true
            onTriggered: if (root.player) root.player.positionChanged();
        }

        // Bottom media strip: elapsed time, a centered transport cluster, and
        // total time, with the wavy seekbar above. Buttons dim when the player
        // disallows the step so the affordance never lies about what will happen.
        Row {
            id: transport
            anchors.horizontalCenter: seek.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 12 * root.s
            spacing: 2 * root.s

            TransportBtn { s: root.s; glyph: "prev"; active: root.canPrev; onTap: root.player.previous() }
            TransportBtn { s: root.s; glyph: root.playing ? "pause" : "play"; active: root.canPlay; onTap: root.player.togglePlaying() }
            TransportBtn { s: root.s; glyph: "next"; active: root.canNext; onTap: root.player.next() }
        }

        Text {
            id: elapsed
            anchors.left: cover.right
            anchors.leftMargin: 14 * root.s
            anchors.verticalCenter: transport.verticalCenter
            // a broadcast has no elapsed: the corner carries the LIVE tally
            // instead, pulsing while on air, steady when paused.
            text: root.radio ? "● LIVE" : root.fmt(root.scrubbing ? root.scrubFrac * root.lengthSec : root.positionSec)
            color: root.radio ? Theme.vermLit : Theme.faint
            font.family: Theme.mono
            font.pixelSize: MainMetrics.fontEyebrow * root.s
            font.features: { "tnum": 1 }
            SequentialAnimation on opacity {
                running: root.radio && root.visible && root.playing
                loops: Animation.Infinite
                NumberAnimation { from: 1; to: 0.35; duration: 900; easing.type: Easing.InOutSine }
                NumberAnimation { from: 0.35; to: 1; duration: 900; easing.type: Easing.InOutSine }
                // the pulse can stop mid-fade (pause, or a track takes over);
                // land back at rest instead of wherever the wave was.
                onStopped: elapsed.opacity = 1
            }
        }
        Text {
            id: total
            anchors.right: parent.right
            anchors.rightMargin: 14 * root.s
            anchors.verticalCenter: transport.verticalCenter
            text: root.radio ? "24/7" : root.fmt(root.lengthSec)
            color: Theme.faint
            font.family: Theme.mono
            font.pixelSize: MainMetrics.fontEyebrow * root.s
            font.features: { "tnum": 1 }
        }

        // Wavy seekbar: a dry base line with a sine over the filled portion
        // while playing. drawFrac glides between the 500ms polls so the fill
        // advances smoothly instead of stepping.
        Canvas {
            id: seek
            anchors.left: cover.right
            anchors.right: parent.right
            anchors.bottom: transport.top
            anchors.leftMargin: 14 * root.s
            anchors.rightMargin: 14 * root.s
            anchors.bottomMargin: 6 * root.s
            height: 12 * root.s
            // a broadcast has no position: the bar would be a lie at 0:00
            // forever. The cava wave behind the card carries the motion.
            visible: !root.radio

            property real phase: 0
            // While scrubbing the fill snaps to the cursor (no glide); otherwise it
            // eases between the 500ms position polls so playback advances smoothly.
            property real drawFrac: root.scrubbing ? root.scrubFrac : root.frac
            Behavior on drawFrac { enabled: !root.scrubbing; NumberAnimation { duration: 480; easing.type: Easing.Linear } }
            onDrawFracChanged: requestPaint()

            // Scrub-to-seek: press or drag anywhere on the bar to preview a target,
            // commit it to the player's position on release. A generous vertical
            // hit area makes the thin bar easy to grab. Only when the player can
            // seek; otherwise the bar stays a pure indicator.
            MouseArea {
                anchors.fill: parent
                anchors.topMargin: -8 * root.s
                anchors.bottomMargin: -8 * root.s
                enabled: root.canSeek
                cursorShape: root.canSeek ? Qt.PointingHandCursor : Qt.ArrowCursor
                preventStealing: true
                function fracAt(x) { return Math.max(0, Math.min(1, x / seek.width)); }
                onPressed: (m) => { root.scrubbing = true; root.scrubFrac = fracAt(m.x); }
                onPositionChanged: (m) => { if (root.scrubbing) root.scrubFrac = fracAt(m.x); }
                onReleased: (m) => {
                    if (!root.scrubbing) return;
                    var target = fracAt(m.x) * root.lengthSec;
                    if (root.player) root.player.position = target;
                    root.scrubbing = false;
                }
                onCanceled: root.scrubbing = false
            }

            onPaint: {
                var ctx = getContext("2d");
                ctx.reset();
                var w = width;
                var cy = height / 2;
                var fillW = w * seek.drawFrac;

                ctx.strokeStyle = Theme.faint;
                ctx.lineWidth = 2 * root.s;
                ctx.beginPath();
                ctx.moveTo(fillW, cy);
                ctx.lineTo(w, cy);
                ctx.stroke();

                var amp = root.playing ? 3 * root.s : 0;
                var waves = Math.max(1, Math.round(fillW / (24 * root.s)));
                var steps = waves * 16;
                ctx.strokeStyle = Theme.vermLit;
                ctx.lineWidth = 2.5 * root.s;
                ctx.beginPath();
                for (var i = 0; i <= steps; i++) {
                    var x = (fillW * i) / steps;
                    var theta = waves * 2 * Math.PI * (i / steps) + seek.phase;
                    var y = cy + amp * Math.sin(theta);
                    if (i === 0)
                        ctx.moveTo(x, y);
                    else
                        ctx.lineTo(x, y);
                }
                ctx.stroke();
            }
        }

        FrameAnimation {
            running: root.playing && root.visible
            onTriggered: {
                seek.phase = Date.now() / 400;
                seek.requestPaint();
            }
        }

        // Position/state changes still repaint the seekbar when paused so a
        // scrub or a play->pause snaps the wave immediately.
        Connections {
            target: root
            function onFracChanged() { seek.requestPaint(); }
            function onPlayingChanged() { seek.requestPaint(); }
        }
    }

    // Compact transport button: a 24-unit vector glyph in a hoverable pill.
    // Fill paths mirror the pill's play/pause/next/prev (see pill/GlyphIcon.qml)
    // so the visual language matches. Dimmed when the player disallows the step.
    component TransportBtn: Item {
        id: btn
        property real s: 1
        property string glyph: ""
        property bool active: true
        // lit = a persistent on-state (shuffle enabled), drawn in the accent so
        // the toggle reads as engaged, distinct from the momentary hover halo.
        property bool lit: false
        signal tap()

        implicitWidth: 26 * s
        implicitHeight: 26 * s
        opacity: active ? 1 : 0.35

        readonly property var paths: ({
            "play":  "M8 5l11 7-11 7z",
            "pause": "M8 5h3v14H8z M13 5h3v14h-3z",
            "next":  "M6 5l9 7-9 7z M16 5h2v14h-2z",
            "prev":  "M18 5l-9 7 9 7z M6 5h2v14H6z",
            "shuffle": "M10.59 9.17L5.41 4 4 5.41l5.17 5.17 1.42-1.41zM14.5 4l2.04 2.04L4 18.59 5.41 20 17.96 7.46 20 9.5V4h-5.5zm.33 9.41l-1.41 1.41 3.13 3.13L14.5 20H20v-5.5l-2.04 2.04-3.13-3.13z"
        })

        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: hover.containsMouse && btn.active ? Theme.hair : "transparent"
        }

        // Inner 16*s frame scales the 24-unit glyph down with a bit of padding
        // around it so the hover halo reads as a button, not a raw icon.
        Item {
            anchors.centerIn: parent
            width: 16 * btn.s
            height: 16 * btn.s

            Shape {
                width: 24
                height: 24
                scale: parent.width / 24
                transformOrigin: Item.TopLeft
                antialiasing: true
                preferredRendererType: Shape.CurveRenderer

                ShapePath {
                    strokeColor: "transparent"
                    fillColor: btn.lit ? Theme.vermLit : Theme.bright
                    capStyle: ShapePath.RoundCap
                    joinStyle: ShapePath.RoundJoin
                    PathSvg { path: btn.paths[btn.glyph] || "" }
                }
            }
        }

        MouseArea {
            id: hover
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: btn.active ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: if (btn.active) btn.tap()
        }
    }
}
