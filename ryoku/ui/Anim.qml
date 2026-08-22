import QtQuick
import "Singletons"

// A Material 3 motion primitive. Pick a `type` and it carries the matching
// duration and easing curve from Tokens, so a transition reads as one shared
// vocabulary instead of a scattered magic number, and the global motion scale
// and reduce-motion switch reach it through Tokens.dur(). Ported from
// caelestia-dots/shell (components/Anim.qml) and adapted onto Ryoku's Tokens.
//
// Use inside a Behavior (Behavior on x { Anim { type: Anim.Emphasized } }) or as
// a standalone NumberAnimation with target/property/from/to set.
NumberAnimation {
    id: anim

    // Material motion roles: Standard and Emphasized in the four size steps, then
    // the expressive spatial (movement) and effects (fade/scale) pairs.
    enum Role {
        StandardSmall,
        Standard,
        StandardLarge,
        StandardExtraLarge,
        EmphasizedSmall,
        Emphasized,
        EmphasizedLarge,
        EmphasizedExtraLarge,
        FastSpatial,
        DefaultSpatial,
        SlowSpatial,
        FastEffects,
        DefaultEffects,
        SlowEffects
    }

    property int type: Anim.Standard

    // Duration and curve per role, drawn live from Tokens so the global motion
    // scale and reduce-motion switch retime every Anim without touching a caller.
    readonly property var _durations: [
        Tokens.durSmall, Tokens.durNormal, Tokens.durLarge, Tokens.durXl,
        Tokens.durSmall, Tokens.durNormal, Tokens.durLarge, Tokens.durXl,
        Tokens.durFastSpatial, Tokens.durDefaultSpatial, Tokens.durSlowSpatial,
        Tokens.durFastEffects, Tokens.durDefaultEffects, Tokens.durSlowEffects
    ]
    readonly property var _curves: [
        Tokens.curveStandard, Tokens.curveStandard, Tokens.curveStandard, Tokens.curveStandard,
        Tokens.curveEmphasized, Tokens.curveEmphasized, Tokens.curveEmphasized, Tokens.curveEmphasized,
        Tokens.curveFastSpatial, Tokens.curveDefaultSpatial, Tokens.curveSlowSpatial,
        Tokens.curveFastEffects, Tokens.curveDefaultEffects, Tokens.curveSlowEffects
    ]

    duration: _durations[type] !== undefined ? _durations[type] : Tokens.durNormal
    easing.type: Easing.BezierSpline
    easing.bezierCurve: _curves[type] !== undefined ? _curves[type] : Tokens.curveStandard
}
