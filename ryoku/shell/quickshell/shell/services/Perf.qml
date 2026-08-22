pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Perf is the shell's one performance-policy singleton and the single reader of
// ~/.config/ryoku/performance.json (the file Ryoku Settings' Performance page
// writes). It folds four inputs into the effective switches every surface obeys:
//
//   1. the explicit user toggles in performance.json (lowPowerMode is the master),
//   2. the active power profile (PowerProfiles), when powerProfileEffects is on,
//   3. the live battery state (Battery), for invisible savings while discharging,
//   4. Game Mode (Flags.gameMode), which outranks all of them.
//
// Consumers read the derived booleans (blurDisabled, shadowsDisabled, reduceMotion,
// visualizerFrozen, pillFrozen) instead of re-deriving `lowPower || flag`: the
// "lowPowerMode implies ..." and "Power Saver implies ..." rules live here once.
// Motion reads reduceMotion/motionSpeed from here too, so the whole shell shares
// one file watcher rather than a copy per module.
//
// Tiers: only Power Saver forces eye-candy off (it behaves like lowPowerMode).
// Balanced and Performance leave the explicit toggles untouched, so the default
// profile never overrides a user's choice and the desktop stays smooth. Battery
// thrift (slower background polling, and not waking a suspended dGPU) is graceful
// and applies whenever discharging, independent of the profile, because it costs
// the user nothing they can see.
//
// Game Mode is the one tier that ignores the user's explicit toggles, and it is
// meant to: the compositor is already stripped and the CPU is already pinned to
// performance, so leaving the shell's own eye-candy running would spend the
// headroom that was just bought. It is also the only tier where the shell is
// competing with a specific foreground process for the same GPU, which is why it
// goes further than Saver and drops the audio analyser outright rather than
// merely freezing it when idle. Nothing here is persisted: it lasts exactly as
// long as the toggle, and every switch returns to the user's own settings on
// exit.
Singleton {
    id: root

    readonly property bool lowPower: adapter.lowPowerMode
    readonly property real motionSpeed: {
        const v = adapter.motionSpeed;
        return (typeof v === "number" && v > 0 && v <= 8) ? v : 1.0;
    }

    // Power profile -> tier. With powerProfileEffects off, or no power-profiles-daemon
    // (a desktop reports no profiles), the tier is Balanced so nothing is forced.
    readonly property int tierSaver: 0
    readonly property int tierBalanced: 1
    readonly property int tierPerformance: 2
    readonly property int tier: {
        if (!adapter.powerProfileEffects || !PowerProfiles.available)
            return root.tierBalanced;
        switch (PowerProfiles.profile) {
        case "power-saver": return root.tierSaver;
        case "performance": return root.tierPerformance;
        default: return root.tierBalanced;
        }
    }
    readonly property bool saver: root.tier === root.tierSaver

    readonly property bool onBattery: Battery.present && Battery.discharging

    // Game Mode. Read straight off the persisted flag rather than mirrored here,
    // so a relogin mid-session comes back in the same state the toggle left.
    readonly property bool gaming: Flags.gameMode

    // Effective eye-candy switches: explicit toggle, or the lowPowerMode master, or
    // the Power Saver tier, or Game Mode. Performance/Balanced add nothing.
    readonly property bool reduceMotion:     lowPower || adapter.reduceMotion   || saver || gaming
    readonly property bool blurDisabled:     lowPower || adapter.disableBlur    || saver || gaming
    readonly property bool shadowsDisabled:  lowPower || adapter.disableShadows || saver || gaming

    // The two audio-driven surfaces freeze when there is nothing to show, which is
    // what "WhenIdle" always meant and never did: `freezeVisualizerWhenIdle` and
    // `freezePillWhenIdle` were folded in as plain always-off switches, so the only
    // choices were "analyse silence forever" (their default) or "never analyse at
    // all". The first is what shipped, and it cost two cava processes plus a
    // permanently damaged surface keeping the compositor awake.
    //
    // Silence is now the gate, unconditionally: there is no sensible reason to
    // spectrum-analyse an idle sink, so the old opt-in keys no longer take part.
    // The hard tiers still win outright, so Saver, lowPowerMode and Game Mode keep
    // these off even mid-track.
    readonly property bool audioIdle: !Media.playing
    readonly property bool visualizerFrozen: lowPower || saver || gaming || audioIdle
    readonly property bool pillFrozen:       lowPower || saver || gaming || audioIdle

    // Graceful cost knobs. Multiply a base poll interval by pollFactor: a second of
    // staleness in a stat readout is invisible, so sampling slows on battery / Saver.
    // Game Mode goes further: nobody is reading a stat readout mid-match, and each
    // poll is a process spawn competing with the game for the same cores.
    // msaa is the sample count for vector layers: crisp by default, halved under Saver.
    readonly property int pollFactor: gaming ? 4 : (onBattery || saver) ? 2 : 1
    readonly property int msaa: (lowPower || saver || gaming) ? 2 : 8

    FileView {
        path: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/ryoku/performance.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        JsonAdapter {
            id: adapter
            property bool lowPowerMode: false
            property bool reduceMotion: false
            property bool disableBlur: false
            property bool disableShadows: false
            property bool freezeVisualizerWhenIdle: true
            property bool freezePillWhenIdle: false
            property real motionSpeed: 1.0
            property bool powerProfileEffects: true
        }
    }
}
