pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "../.." as Pill
import "../../Singletons"

// Left icon tab rail for the quick-settings panel. 44px wide, full height.
// Three tabs: Home, Notifications (+ badge), Weather.
// Bottom: Settings (Hub) and Colour picker moved from the old footer.
//
// ACTIVE TAB: solid Theme.primary disc + Theme.onPrimary icon + sumi edge.
// INACTIVE: onSurfaceVariant icon, no disc. HOVER: wash. PRESS: scale dip.
// QsTip: side: true => bubble opens RIGHT (inside panel body, never clips).
//
// NO rail background strip — the rail sits directly on the panel surface;
// only the right-edge sumi hairline separates it from the content pane.
// Raise z:10 in MenuQuickSettings so the QsTip bubble (z:1000 inside rail)
// renders above all tab sheets.
Item {
    id: root

    property int activeTab: 0
    signal tabActivated(int index)
    signal requestClose()

    readonly property int notifCount: Notifs.history.length

    implicitWidth: 44

    // Right-edge hairline only — no fill rect, no seam
    Rectangle {
        anchors.top: parent.top; anchors.bottom: parent.bottom; anchors.right: parent.right
        width: 1
        color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.20)
    }

    // ---- top three tabs -----------------------------------------------------
    Column {
        anchors.top: parent.top; anchors.topMargin: 10
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 6

        RailTab {
            tabIdx: 0; icon: "space_dashboard"; tipText: qsTr("Home")
            active: root.activeTab === 0
            onActivated: root.tabActivated(0)
        }
        RailTab {
            tabIdx: 1; icon: "notifications"; tipText: qsTr("Notifications")
            active: root.activeTab === 1
            badge: root.notifCount
            onActivated: root.tabActivated(1)
        }
        RailTab {
            tabIdx: 2; icon: "partly_cloudy_day"; tipText: qsTr("Weather")
            active: root.activeTab === 2
            onActivated: root.tabActivated(2)
        }
    }

    // ---- bottom utility buttons ---------------------------------------------
    Column {
        anchors.bottom: parent.bottom; anchors.bottomMargin: 10
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 6

        RailIconBtn {
            icon: "settings"; tipText: qsTr("Ryoku Hub")
            onClicked: { Quickshell.execDetached(["ryoku-shell", "hub", "open"]); root.requestClose(); }
        }
        RailIconBtn {
            icon: "colorize"; tipText: qsTr("Pick a color")
            onClicked: { Quickshell.execDetached(["ryoku-cmd-color-picker"]); root.requestClose(); }
        }
    }

    // ---- inline components --------------------------------------------------

    // Icon tab: solid primary disc when active, transparent when not.
    // Disc = filled circle in Theme.primary. Icon = Theme.onPrimary when active.
    component RailTab: Item {
        id: rt
        property int tabIdx: 0
        property string icon: ""
        property string tipText: ""
        property bool active: false
        property int badge: 0
        signal activated()

        width: 36; height: 36

        // Hover wash underneath disc so the hover shows even when disc is hidden
        Rectangle {
            id: hoverWash
            anchors.fill: parent; radius: width / 2
            color: rtTap.containsMouse && !rt.active
                ? Qt.rgba(Theme.onSurface.r, Theme.onSurface.g, Theme.onSurface.b, 0.09)
                : "transparent"
            Behavior on color { ColorAnimation { duration: Motion.fast } }
        }

        // Active disc: solid primary fill, no transparency.
        // Using Qt.alpha(Theme.primary, ...) avoids stale sub-property bindings.
        Rectangle {
            id: disc
            anchors.fill: parent; radius: width / 2
            visible: rt.active
            color: Theme.primary
            border.width: 0

            Behavior on color { ColorAnimation { duration: Motion.fast } }

            // Sumi edge — lit top line on the active disc surface
            Rectangle {
                anchors.top: parent.top
                anchors.left: parent.left; anchors.right: parent.right
                anchors.leftMargin: parent.radius; anchors.rightMargin: parent.radius
                height: 1
                color: Qt.rgba(Theme.onPrimary.r, Theme.onPrimary.g, Theme.onPrimary.b, 0.35)
            }
        }

        // Icon: onPrimary on active disc, onSurfaceVariant otherwise.
        Pill.MaterialIcon {
            anchors.centerIn: parent; font.pixelSize: 20
            text: rt.icon
            fill: rt.active ? 1 : 0
            color: rt.active
                ? Theme.inkOn(Theme.primary, Theme.onPrimary)
                : Theme.inkOn(Theme.effectiveSurface, Theme.onSurfaceVariant, 3.0)
            Behavior on color { ColorAnimation { duration: Motion.fast } }
        }

        // Press dip
        scale: rtTap.pressed ? 0.88 : 1.0
        Behavior on scale { NumberAnimation { duration: Motion.fast; easing.type: Easing.OutBack; easing.overshoot: 2.0 } }

        // Unread badge (notifications tab; hidden at zero)
        Rectangle {
            visible: rt.badge > 0
            anchors.top: parent.top; anchors.right: parent.right
            anchors.topMargin: -2; anchors.rightMargin: -2
            width: Math.max(16, badgeTxt.implicitWidth + 6); height: 16; radius: 8
            color: Theme.primary
            Text {
                id: badgeTxt; anchors.centerIn: parent
                text: rt.badge > 99 ? "99+" : String(rt.badge)
                color: Theme.inkOn(Theme.primary, Theme.onPrimary)
                font.family: Theme.fontPrimary; font.pixelSize: 9; font.weight: Font.Bold
            }
        }

        MouseArea {
            id: rtTap; anchors.fill: parent
            hoverEnabled: true; cursorShape: Qt.PointingHandCursor
            onClicked: rt.activated()
        }

        // side: true => bubble opens to the RIGHT (stays inside panel body)
        QsTip { text: rt.tipText; side: true; hovered: rtTap.containsMouse && !rtTap.pressed }
    }

    // Utility icon button (Hub, colour picker) — same side tip.
    component RailIconBtn: Item {
        id: rib
        property string icon: ""
        property string tipText: ""
        signal clicked()

        width: 34; height: 34

        Rectangle {
            anchors.fill: parent; radius: width / 2
            color: ribTap.containsMouse
                ? Qt.rgba(Theme.onSurface.r, Theme.onSurface.g, Theme.onSurface.b, 0.09)
                : "transparent"
            Behavior on color { ColorAnimation { duration: Motion.fast } }
        }
        Pill.MaterialIcon {
            anchors.centerIn: parent; font.pixelSize: 17; text: rib.icon
            color: Theme.inkOn(Theme.effectiveSurface, Theme.onSurfaceVariant, 3.0)
        }
        scale: ribTap.pressed ? 0.88 : 1.0
        Behavior on scale { NumberAnimation { duration: Motion.fast; easing.type: Easing.OutBack; easing.overshoot: 2.0 } }
        MouseArea {
            id: ribTap; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
            onClicked: rib.clicked()
        }
        QsTip { text: rib.tipText; side: true; hovered: ribTap.containsMouse && !ribTap.pressed }
    }
}
