pragma Singleton
import QtQuick
import Quickshell

// Bundles NibrasShell's display faces into the shell process so any widget's
// font.family -- and Theme.font, the user-picked widget font -- can name one
// without the family being installed system-wide. Each FontLoader registers its
// file with the font database; `.name` is the family the engine actually
// resolved (authoritative -- never a guessed string), so `families` is exactly
// what the Hub's picker offers and what a widget sets as its font.family.
Singleton {
    // the resolved family names, in bundle order. Used to seed the widget-font
    // picker so the desktop can render any bundled face.
    readonly property var families: [
        reckoner.name, reckonerBold.name, jfFlat.name, abberancy.name,
        daydream.name, sabana.name, unrealised.name, vipRawy.name,
        xenophobia.name, vexaLight.name, overhead.name
    ]

    FontLoader { id: reckoner;     source: Qt.resolvedUrl("../../../assets/fonts/reckoner.ttf") }
    FontLoader { id: reckonerBold; source: Qt.resolvedUrl("../../../assets/fonts/reckoner-bold.ttf") }
    FontLoader { id: jfFlat;       source: Qt.resolvedUrl("../../../assets/fonts/jf-flat-regular.otf") }
    FontLoader { id: abberancy;    source: Qt.resolvedUrl("../../../assets/fonts/abberancy.ttf") }
    FontLoader { id: daydream;     source: Qt.resolvedUrl("../../../assets/fonts/daydream-demo.otf") }
    FontLoader { id: sabana;       source: Qt.resolvedUrl("../../../assets/fonts/sabana-regular.ttf") }
    FontLoader { id: unrealised;   source: Qt.resolvedUrl("../../../assets/fonts/unrealised.ttf") }
    FontLoader { id: vipRawy;      source: Qt.resolvedUrl("../../../assets/fonts/vip-rawy-regular.otf") }
    FontLoader { id: xenophobia;   source: Qt.resolvedUrl("../../../assets/fonts/xenophobia-nominal.ttf") }
    FontLoader { id: vexaLight;    source: Qt.resolvedUrl("../../../assets/fonts/vexa-light.ttf") }
    FontLoader { id: overhead;     source: Qt.resolvedUrl("../../../assets/fonts/overhead.ttf") }
}
