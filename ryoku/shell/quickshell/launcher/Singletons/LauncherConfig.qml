pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property alias radius:       adapter.radius        // outer card corner, px
    property alias bgBlur:      adapter.bgBlur         // frozen card-local snapshot frost, px (0 = sharp)
    property alias weatherUnit:  adapter.weatherUnit   // auto (locale) | C | F
    property alias heroImage:    adapter.heroImage     // backdrop file, "" = shipped art
    property alias heroStrength: adapter.heroStrength  // backdrop opacity, 0..1
    property alias heroPosX:     adapter.heroPosX      // backdrop focal point, 0..1
    property alias heroPosY:     adapter.heroPosY
    property alias showWeather:  adapter.showWeather   // weather glance on the hero
    property alias showGreeting: adapter.showGreeting  // "Good morning" line
    property alias resultSettleMs: adapter.resultSettleMs // quiet period before a typed deck appears

    FileView {
        id: file
        path: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/ryoku/launcher.json"
        blockLoading: true
        watchChanges: true
        printErrors: false
        atomicWrites: true
        onFileChanged: reload()

        JsonAdapter {
            id: adapter
            property real radius: 16
            property int bgBlur: 2
            property string weatherUnit: "auto"
            property string heroImage: ""
            property real heroStrength: 0.6
            property real heroPosX: 0.5
            property real heroPosY: 0.5
            property bool showWeather: true
            property bool showGreeting: true
            property int resultSettleMs: 360
        }
    }

    Component.onCompleted: if (!file.text()) file.writeAdapter();
}
