pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Ryoku.Ui
import Ryoku.Ui.Singletons

// SESSION route (終). Lock, sleep, restart, power off. A page that can power the
// machine off carries no other business, so it lives alone: one card, one band of
// four verbs. A label above a button that repeats the same word is a wasted row,
// so the verbs stand on their own. The three that end the session arm on a first
// click and confirm on a second (the button reads Confirm while armed); Lock is
// reversible, so it fires on the first. Each call is exactly what the retired
// QuickPage used.
Item {
    id: page
    property var root
    property var cc
    readonly property var tk: cc.tokens
    readonly property real colW: Math.min(page.width, tk.contentW)
    implicitHeight: col.implicitHeight

    // Which destructive action is armed, "" for none. A second click on the
    // armed action fires it; arming another (or the timer) disarms the rest, so
    // a mis-aimed pointer never powers off the machine.
    property string armed: ""
    onArmedChanged: if (page.armed !== "") disarm.restart(); else disarm.stop()
    Timer { id: disarm; interval: 2600; onTriggered: page.armed = "" }

    Column {
        id: col
        width: page.colW
        spacing: page.tk.sectionGap

        Entrance {
            width: page.colW
            index: 0
            SettingCard {
                width: page.colW
                title: I18n.tr("SESSION")
                kana: "\u7d42"

                SettingRow {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    block: true
                    label: I18n.tr("End the session")
                    desc: I18n.tr("Log out, sleep, restart and power off ask twice.")
                    Row {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Tokens.s2

                        Btn {
                            text: I18n.tr("LOCK")
                            onAct: {
                                Quickshell.execDetached(["ryoku-shell", "lock"]);
                                if (page.cc)
                                    page.cc.close();
                            }
                        }
                        Btn {
                            text: page.armed === "logout" ? I18n.tr("CONFIRM") : I18n.tr("LOG OUT")
                            primary: page.armed === "logout"
                            onAct: {
                                if (page.armed !== "logout") {
                                    page.armed = "logout";
                                    return;
                                }
                                page.armed = "";
                                Hyprland.dispatch("hl.dsp.exit()");
                                if (page.cc)
                                    page.cc.close();
                            }
                        }
                        Btn {
                            text: page.armed === "suspend" ? I18n.tr("CONFIRM") : I18n.tr("SUSPEND")
                            primary: page.armed === "suspend"
                            onAct: {
                                if (page.armed !== "suspend") {
                                    page.armed = "suspend";
                                    return;
                                }
                                page.armed = "";
                                Quickshell.execDetached(["systemctl", "suspend"]);
                                if (page.cc)
                                    page.cc.close();
                            }
                        }
                        Btn {
                            text: page.armed === "reboot" ? I18n.tr("CONFIRM") : I18n.tr("REBOOT")
                            primary: page.armed === "reboot"
                            onAct: {
                                if (page.armed !== "reboot") {
                                    page.armed = "reboot";
                                    return;
                                }
                                page.armed = "";
                                Quickshell.execDetached(["systemctl", "reboot"]);
                                if (page.cc)
                                    page.cc.close();
                            }
                        }
                        Btn {
                            text: page.armed === "poweroff" ? I18n.tr("CONFIRM") : I18n.tr("SHUT DOWN")
                            primary: page.armed === "poweroff"
                            onAct: {
                                if (page.armed !== "poweroff") {
                                    page.armed = "poweroff";
                                    return;
                                }
                                page.armed = "";
                                Quickshell.execDetached(["systemctl", "poweroff"]);
                                if (page.cc)
                                    page.cc.close();
                            }
                        }
                    }
                }
            }
        }
    }
}
