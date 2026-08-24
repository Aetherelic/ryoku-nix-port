import QtQuick
import Ryoku.Ui.Singletons

// The studio's own geometry: the plate, the rail, the form column, the panel's
// rhythm, and the durations its reveal and page swaps run at. Colour, type and
// control size are NOT here -- they come from `Tokens`, the house single door,
// which every route and every chrome piece reads directly. `root` is the qsbar
// Theme, kept because the bar's live colours appear in the studio as DATA: the
// silhouette, the accent swatches, the workspace marker preview.
QtObject {
    id: t
    property var root

    // ── plate ────────────────────────────────────────────────────────────────
    // The plate is exactly the rail plus the form column plus their insets: no
    // dead gutter to the right of a card, and a route that needs less scrolls
    // less, because the height comes from the page too (see ControlCenter).
    readonly property int railW: Tokens.px(216)
    readonly property int contentW: Tokens.px(640) // the form column
    readonly property int plateW: t.railW + t.contentW + t.pad * 2
    readonly property int plateH: Tokens.px(940)   // the cap; the page decides
    readonly property int screenMargin: Tokens.s5
    // a 900px plate needs more curve than a control to read as rounded at all
    readonly property int corner: Tokens.radius * 4

    // ── rhythm ───────────────────────────────────────────────────────────────
    readonly property int pad: Tokens.s5          // body inset
    readonly property int gap: Tokens.s3          // between rows of a group
    readonly property int sectionGap: Tokens.s5   // between titled sections
    readonly property int colGap: Tokens.s4       // between grid columns
    readonly property int headH: Tokens.px(64)
    readonly property int rowH: Tokens.px(40)
    readonly property int tileH: Tokens.px(40)
    readonly property int eyebrowH: Tokens.px(24)
    readonly property int navH: Tokens.px(32)


    // ── motion ───────────────────────────────────────────────────────────────
    readonly property int revealOpen: Tokens.durSlowEffects
    readonly property int revealClose: Tokens.durDefaultEffects
    readonly property int fade: Tokens.durFastEffects
    readonly property int pageOut: Tokens.durFastEffects
    readonly property int pageIn: Tokens.durDefaultSpatial
}
