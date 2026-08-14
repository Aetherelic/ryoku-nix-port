import QtQuick

// Geometry + motion tokens for the Control Center. Colours are NOT here: routes
// read them straight off `root` (the qsbar Theme). One place for the CC's
// spacing and durations so pages never restate magic numbers. Durations mirror
// the values the old ControlPanel and Shibumi's ControlSettings used.
QtObject {
    id: t
    property var root

    // ── card geometry ──
    readonly property int cardW: 900
    readonly property int cardH: 760
    readonly property int screenMargin: 18
    readonly property int pad: 20            // card content inset
    readonly property int gap: 10            // general vertical gap
    readonly property int sectionGap: 16     // between titled sections
    readonly property int colGap: 14         // between the two columns
    readonly property int rowH: 44           // a setting row
    readonly property int tileH: 44          // an action tile

    // ── route graph ports ──
    readonly property real portR: 3.6
    readonly property real portDestR: 4.4

    // ── typography: four roles only, per the reference control language.
    // A size outside this set is a smell, not a decision.
    readonly property int fontEyebrow: 10    // uppercase section label, DemiBold
    readonly property int fontBody: 12       // labels and body copy
    readonly property int fontValue: 12      // values and selection, DemiBold
    readonly property int fontDetail: 10     // secondary detail, dimmed
    readonly property int fontTitle: 24      // the single page-title tier
    readonly property real trackEyebrow: 1
    readonly property real detailOpacity: 0.58

    // ── control geometry ──
    readonly property int controlH: 28       // segmented option, stepper button
    readonly property int chipH: 24          // chip inside a card
    readonly property int railW: 3           // scroll rail thumb at its widest

    // ── motion (ms) ──
    readonly property int revealOpen: 160
    readonly property int revealClose: 120
    readonly property int fade: 120
    readonly property int pageOut: 90
    readonly property int pageIn: 240
    readonly property int graphFade: 300
    readonly property int dragReturn: 230
}
