pragma ComponentBehavior: Bound

import QtQuick
import "Singletons"

// One notification card, shared by the history panel and the popup surface
// (contract 07 sec 2.3). A bordered surface tile with a header (app name, time,
// close), a bold summary, an optional body, and one primary button per action.
// No app icon and no image are drawn, matching the reference widget exactly.
// The card fills the width its host gives it and is sized entirely from tokens.
Rectangle {
    id: card

    required property var notif
    // Fired after an action runs; the panel closes the menu on it, the popup
    // ignores it (contract 07 sec 4.3).
    signal actionInvoked()

    // Only real actions get a button: the freedesktop "default" action (invoked
    // by clicking the notification, not a button) and any action with no label
    // are dropped, so a bare default no longer draws an empty pill.
    readonly property var visibleActions: {
        const all = card.notif.actions || [];
        const out = [];
        for (let i = 0; i < all.length; i++)
            if (all[i] && all[i].identifier !== "default" && (all[i].text || "").length > 0)
                out.push(all[i]);
        return out;
    }

    // Countdown frame (popups only): a border that traces the card and drains
    // over the popup's lifespan, so a glance shows how long is left. The history
    // panel and persistent popups pass 0 and draw no frame.
    property int lifespanMs: 0
    readonly property bool countingDown: card.lifespanMs > 0
    property real remaining: 1
    NumberAnimation on remaining {
        running: card.countingDown
        from: 1
        to: 0
        duration: Math.max(1, card.lifespanMs)
        easing.type: Easing.Linear
    }

    radius: Theme.radiusWidget
    border.width: Theme.borderWidth
    border.color: Theme.outline
    color: Theme.surface
    implicitHeight: body.implicitHeight + Theme.paddingMd * 2

    Column {
        id: body
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Theme.paddingMd
        spacing: Theme.paddingMd

        // Header: app name (fills), arrival time, close button.
        Item {
            width: parent.width
            height: Math.max(appName.implicitHeight, timeLabel.implicitHeight, closeBtn.height)

            Text {
                id: appName
                anchors.left: parent.left
                anchors.right: timeLabel.left
                anchors.rightMargin: Theme.paddingSm
                anchors.verticalCenter: parent.verticalCenter
                text: card.notif.appName || ""
                color: Theme.onSurfaceVariant
                font.family: Theme.fontPrimary
                font.pixelSize: Theme.fontSm
                font.weight: Font.Medium
                elide: Text.ElideRight
            }

            Text {
                id: timeLabel
                anchors.right: closeBtn.left
                anchors.rightMargin: Theme.paddingSm
                anchors.verticalCenter: parent.verticalCenter
                text: Notifs.timeLabel(card.notif)
                color: Theme.onSurfaceVariant
                font.family: Theme.fontPrimary
                font.pixelSize: Theme.fontSm
            }

            Rectangle {
                id: closeBtn
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: Theme.iconSm + Theme.paddingSm * 2
                height: width
                radius: Theme.radiusWidget
                color: closeHov.hovered
                    ? Qt.tint(Theme.surface, Qt.rgba(Theme.onSurface.r, Theme.onSurface.g, Theme.onSurface.b, 0.08))
                    : "transparent"

                MaterialIcon {
                    anchors.centerIn: parent
                    text: "close"
                    font.pixelSize: Theme.iconSm
                    color: closeHov.hovered ? Theme.onSurface : Theme.onSurfaceVariant
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Notifs.dismiss(card.notif)
                    HoverHandler { id: closeHov }
                }
            }
        }

        // Summary: bold, wraps.
        Text {
            width: parent.width
            text: card.notif.summary || ""
            color: Theme.onSurface
            font.family: Theme.fontPrimary
            font.pixelSize: Theme.fontMd
            font.weight: Font.Bold
            wrapMode: Text.WrapAtWordBoundaryOrAnywhere
        }

        // Body: only when present.
        Text {
            width: parent.width
            visible: (card.notif.body || "").length > 0
            text: card.notif.body || ""
            color: Theme.onSurfaceVariant
            font.family: Theme.fontPrimary
            font.pixelSize: Theme.fontSm
            wrapMode: Text.WrapAtWordBoundaryOrAnywhere
        }

        // Actions: one primary button per action, full width (contract 07 sec 2.3).
        Column {
            width: parent.width
            spacing: Theme.paddingSm
            visible: card.visibleActions.length > 0

            Repeater {
                model: card.visibleActions

                delegate: Rectangle {
                    id: actionBtn
                    required property var modelData

                    width: parent.width
                    height: actionLabel.implicitHeight + Theme.paddingSm * 2
                    radius: Theme.radiusWidget
                    color: actionHov.hovered ? Theme.vermLit : Theme.primary

                    Behavior on color { ColorAnimation { duration: Motion.rowFade; easing.type: Motion.easeType; easing.bezierCurve: Motion.easeCurve } }

                    Text {
                        id: actionLabel
                        anchors.centerIn: parent
                        width: parent.width - Theme.paddingMd * 2
                        horizontalAlignment: Text.AlignHCenter
                        text: actionBtn.modelData.text
                        color: Theme.onPrimary
                        font.family: Theme.fontPrimary
                        font.pixelSize: Theme.fontSm
                        font.weight: Font.Bold
                        elide: Text.ElideRight
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            actionBtn.modelData.invoke();
                            card.actionInvoked();
                        }
                        HoverHandler { id: actionHov }
                    }
                }
            }
        }
    }

    // The draining countdown, stroked over the card's own border: the accent
    // traces the whole rounded rect at full life and recedes clockwise from the
    // top as the lifespan runs out, uncovering the plain outline underneath.
    Canvas {
        id: timerFrame
        anchors.fill: parent
        visible: card.countingDown
        renderStrategy: Canvas.Cooperative
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            if (!card.countingDown)
                return;
            const sw = Theme.borderWidth + 1;
            const o = sw / 2;
            const w = width - sw;
            const h = height - sw;
            const rad = Math.max(0, Math.min(card.radius, w / 2, h / 2));
            const perim = 2 * (w - 2 * rad) + 2 * (h - 2 * rad) + 2 * Math.PI * rad;
            const drawn = Math.max(0, Math.min(perim, card.remaining * perim));
            ctx.beginPath();
            ctx.moveTo(o + w / 2, o);
            ctx.lineTo(o + w - rad, o);
            ctx.arcTo(o + w, o, o + w, o + rad, rad);
            ctx.lineTo(o + w, o + h - rad);
            ctx.arcTo(o + w, o + h, o + w - rad, o + h, rad);
            ctx.lineTo(o + rad, o + h);
            ctx.arcTo(o, o + h, o, o + h - rad, rad);
            ctx.lineTo(o, o + rad);
            ctx.arcTo(o, o, o + rad, o, rad);
            ctx.lineTo(o + w / 2, o);
            ctx.lineWidth = sw;
            ctx.strokeStyle = Theme.flameGlow;
            ctx.lineCap = "butt";
            ctx.setLineDash([drawn, perim + 1]);
            ctx.stroke();
        }
        Connections {
            target: card
            function onRemainingChanged() { timerFrame.requestPaint(); }
        }
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onVisibleChanged: requestPaint()
    }
}
