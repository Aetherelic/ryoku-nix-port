# Bar styles

Ryoku draws its bar one of two ways, and a single key decides which. The default
is **Sumi**, the built-in left rail (paper and ink, the ink spine down the side
of the screen). Sumi is not a folder: the shell draws it itself from the frame
scene in `shell.qml`. Every other style is a self-contained folder under
`ryoku/shell/quickshell/pill/barstyles/<id>/` that ships its own bar, its own
widgets, and its own popouts, and the shell loads it per monitor. **Obi**, a
floating top bar with kanji workspaces, is the worked example this doc reads
from; use it as the template for a new one.

A bar style owns the bar and nothing else. The frame border, the menus, the
service surfaces, and the tokens stay where they are; a style just decides what
sits on the edge of the screen and how it reads its data. So building one is
mostly a layout job over singletons that already exist.

## How selection works

The `barStyle` key in `~/.config/ryoku/shell.json` picks the active style by id.
It is a top-level string, default `"sumi"`:

```json
{
  "barStyle": "obi"
}
```

`Config.qml` surfaces it as `Config.barStyle`, and the file is watched, so a save
retunes the running shell without a reload. The set of valid ids lives in one
registry, `pill/barstyles/registry.js`. Each row is a style:

```js
var STYLES = [
    { id: "sumi", name: "Sumi", desc: "Ink spine: the left rail, paper and ink.", scene: "" },
    { id: "obi", name: "Obi", desc: "Sash: a floating top bar with kanji workspaces.", scene: "barstyles/obi/Scene.qml" }
];
```

`scene` is the QML file `shell.qml` loads per monitor, resolved relative to
`shell.qml`. An empty `scene` means the built-in frame scene (Sumi), which
`shell.qml` paints itself. Any non-empty path is a folder style. **To add a
style, drop its folder under `barstyles/` and add one row here.** `sceneUrl(id)`
returns the row's scene, and `isBuiltin(id)` is true when it is empty.

`shell.qml` reads the registry through one derived flag:

```qml
import "barstyles/registry.js" as BarStyles

readonly property bool sumiActive: BarStyles.sceneUrl(Config.barStyle) === ""
```

`sumiActive` is the gate. While it is true, the built-in frame chrome and the
four rails draw, and each `FrameEdge` reserves its exclusive zone
(`reserve: root.sumiActive ? root.edgeReserve("top") : 0`). While it is false,
the frame scene hides, the edges release their reserves, and a per-monitor
`Loader` mounts the active style's `Scene.qml` instead:

```qml
Variants {
    model: Quickshell.screens
    Loader {
        required property var modelData
        active: !root.sumiActive
        source: BarStyles.sceneUrl(Config.barStyle)
        onLoaded: if (item) item.modelData = modelData
        onModelDataChanged: if (item) item.modelData = modelData
    }
}
```

That is the whole contract with the shell: your `Scene.qml` is loaded once per
screen, and the screen is handed to it through a `modelData` property the Loader
sets. Everything else is yours.

The shipped Sumi profile is left-only. `FrameBars.js` `defaultConfig()` enables
the left rail and leaves the other three off:

```js
top:    { enabled: false, size: 32, reveal: true, ... },
left:   { enabled: true,  size: 48, reveal: true, top: [...], center: ["dock"], bottom: [...] },
bottom: { enabled: false, size: 32, reveal: true, ... },
right:  { enabled: false, size: 48, reveal: true, ... }
```

### One gotcha, three parts

A folder scene is loaded by URL, not compiled into the shell, and that changes
how edits land:

- **Structural edits need a restart.** Adding a file, adding an import, or
  changing the shape of a loaded `Scene` is not picked up by hot-reload the way
  an edit to a resident QML file is. Restart the shell after a structural
  change: `systemctl --user restart ryoku-shell`. Property tweaks inside an
  already-loaded scene reload live; new files and new imports do not.
- **Same-directory types are not auto-imported.** QML does not put sibling files
  in scope just because they share a folder. Keep shared pieces in a subdirectory
  and import it namespaced: `import "components" as C`, then `C.BarPill { ... }`.
  A bare `BarPill { ... }` next to `BarPill.qml` will not resolve.
- **Reach the shared code by relative path.** A widget three levels down imports
  the singletons with `import "../../../Singletons"` and the Ryoku icon
  primitives with `import "../../.." as Pill`. The `Scene.qml` sits one level
  higher, so it uses `import "../../Singletons"`. Get these paths wrong and the
  scene loads to a blank strip with import errors in the shell log.

## The shape of a style

Obi is laid out like this:

```
barstyles/obi/
  Scene.qml            the per-monitor bar window
  components/
    BarPill.qml        the rounded surface group a zone sits in
    Popout.qml         the hover card every widget reuses
  widgets/
    Workspaces.qml     ActiveWindow.qml  Clock.qml  Media.qml
    Resources.qml      Battery.qml       Weather.qml
    Tray.qml           Utils.qml
```

There is no separate `popouts/` directory. Each widget owns its own popout as a
`Component` inside its file and wires it with `components/Popout.qml`, so a
style's cards live entirely inside the style's folder.

`Scene.qml` is a `PanelWindow`, one instance per monitor. It takes the screen
through `modelData`, anchors itself to an edge, reserves its band with an
exclusive zone, and masks input to just the interactive pills so the rest of the
strip is click-through. A minimal scene:

```qml
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../Singletons"
import "components" as C
import "widgets" as W

PanelWindow {
    id: win

    property var modelData      // the screen, set by shell.qml's Loader
    screen: modelData

    color: "transparent"
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: 46
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.namespace: "ryoku-obi"

    anchors { top: true; left: true; right: true }
    implicitHeight: 52

    // Only the pill takes clicks; the rest of the bar passes them through.
    mask: Region { Region { item: pill } }

    C.BarPill {
        id: pill
        anchors.centerIn: parent
        W.Clock {}
    }
}
```

`BarPill` is a small helper: a rounded `Theme.surface` rectangle that hugs a
centred `Row` of whatever widgets you drop in, and hides itself when empty. A
widget, in turn, is any `Item` that reports an implicit size; the pill lays them
out left to right. The smallest useful widget is a bound `Text`:

```qml
import QtQuick
import "../../../Singletons"

Text {
    text: "Desktop"
    color: Theme.onSurfaceVariant
    font.family: Theme.fontPrimary
    font.pixelSize: Theme.fontSm
    elide: Text.ElideRight
    width: Math.min(implicitWidth, 260)
}
```

Everything past this point is about what a widget binds to.

## Fetching data

This is the real work. The shell already gathers every live fact through
singletons under `pill/Singletons/`; a widget reads them and draws. Import the
whole directory once (`import "../../../Singletons"`) and each singleton is in
scope by name. What follows is the exact surface each one exposes, drawn from the
Obi widgets.

### Workspaces and Hyprland

Workspaces come from two places. The `Workspaces` singleton gives you one
reliable number, `Workspaces.activeId`, the focused workspace id (seeded from
`hyprctl` and kept correct against Ryoku's Hyprland fork, where reading
`Hyprland.focusedWorkspace` too early yields bogus ids). The live list and the
switch come from `Quickshell.Hyprland` directly:

```qml
import Quickshell.Hyprland
import "../../../Singletons"

readonly property int activeId: Workspaces.activeId

// live workspaces: each w has .id, .name, and .lastIpcObject
readonly property var wss: Hyprland.workspaces ? Hyprland.workspaces.values : []

// occupancy: scan toplevels for one sitting on this workspace
function occupied(id) {
    const tls = Hyprland.toplevels ? Hyprland.toplevels.values : [];
    for (let i = 0; i < tls.length; i++) {
        const o = tls[i] && tls[i].lastIpcObject || {};
        if (o.workspace && o.workspace.id === id) return true;
    }
    return false;
}

// switch to one, and cycle with the wheel
function focus(id) { Hyprland.dispatch('hl.dsp.focus({ workspace = "' + id + '" })'); }
// onWheel: Hyprland.dispatch(up ? "workspace r-1" : "workspace r+1")
```

The focused window is `Hyprland.activeToplevel`, and its title lives at
`activeToplevel.lastIpcObject.title` (guard it; it is empty on a bare
workspace). Obi's `ActiveWindow.qml` is nothing more than that string, elided.

### Media

The `Media` singleton is the one now-playing pick every surface shares. It
prefers a sounding MPRIS player and ignores the live wallpaper's video.

```qml
visible: Media.present            // a real track is loaded
Text { text: Media.line }         // "title · artist", ready to bind

// Media.player is the raw MPRIS player, or null. Guard every read.
Image { source: Media.player ? (Media.player.trackArtUrl || "") : "" }
Text  { text: Media.player ? (Media.player.trackTitle || "") : "" }
Text  { text: Media.player ? Theme.joinArtists(Media.player.trackArtists, Media.player.trackArtist) : "" }
```

Transport and seek read and drive the same player:

- `Media.playing` is the convenience for `Media.player.isPlaying`.
- `Media.player.position` and `Media.player.length` are seconds; the fraction is
  `position / length`. The position does not tick on its own; pulse
  `Media.player.positionChanged()` on a `Timer` while the card is open to keep a
  seek line live.
- `Media.player.previous()`, `Media.player.next()`, and `Media.toggle()` drive
  it, each gated by `Media.player.canGoPrevious`, `canGoNext`, and
  `canTogglePlaying`.

### Sysinfo

`Sysinfo` carries CPU, memory, and a best-effort package temperature. It is
owner-refcounted: it polls (on a 1.5s tick) only while a visible owner claims
it, so an unseen widget costs nothing. **Claim it on show and release it on
destruction**, or every reading stays at zero:

```qml
Component.onCompleted: Sysinfo.setActive(root, true)
Component.onDestruction: Sysinfo.setActive(root, false)
```

Then read: `Sysinfo.cpu` and `Sysinfo.mem` are `0..1` loads; `Sysinfo.memUsedGiB`
and `Sysinfo.memTotalGiB` are GiB; `Sysinfo.tempC` is degrees, present only when
`Sysinfo.hasTemp` is true (a machine with no readable CPU sensor reports none).

```qml
value: Sysinfo.cpu                                   // ring/bar fill 0..1
text:  Sysinfo.memUsedGiB.toFixed(1) + " / " + Sysinfo.memTotalGiB.toFixed(1) + " GiB"
ResBar { visible: Sysinfo.hasTemp; value: Math.round(Sysinfo.tempC) + "°C" }
```

### Battery

`Battery` reads UPower. On a desktop with no cell it reports
`Battery.present === false`, so gate the whole widget on it. `Battery.pct` is the
integer percent and `Battery.frac` the `0..1` fraction. State comes as
`Battery.charging`, `Battery.full`, `Battery.low`, and a ready string
`Battery.stateLabel`. Time-to-full or time-to-empty is `Battery.timeStr` and is
valid only while `Battery.hasTime` is true. Health is
`Battery.health` percent, shown only when `Battery.healthSupported`.

```qml
visible: Battery.present
Text { text: Battery.pct + "%"; color: Battery.low ? Theme.error : Theme.onSurface }
Text {
    text: Battery.stateLabel + (Battery.hasTime
        ? " · " + Battery.timeStr + (Battery.charging ? " to full" : " left") : "")
}
Text { visible: Battery.healthSupported; text: "Health " + Battery.health + "%" }
```

The power-profile picker in Obi's battery card is a second singleton,
`PowerProfiles`: `PowerProfiles.available` gates it, `PowerProfiles.profiles` is
the list, `PowerProfiles.profile` is the current one, and
`PowerProfiles.setProfile(name)` switches it.

### Weather

`Weather` is a view of the daemon's `weather` topic; QML makes no HTTP call. Gate
on `Weather.available`. The compact readout uses `Weather.temp` (a ready display
string like `18°`) and `Weather.condition`; the fuller card uses
`Weather.humidity`, `Weather.wind`, `Weather.feels`, and `Weather.location`.

`Weather.current` is the current-conditions object (`code` is the WMO code,
`isDay` the day/night flag, plus `feelsLike`, `humidity`, `windValue`,
`windUnits`). `Weather.daily` is the forecast array, each entry carrying `day`,
`code`, `high`, and `low`.

The daemon ships a base glyph name as `Weather.glyph`, but the bar maps the WMO
code to the shell's own `weather-*` symbolic icon set itself, so day and night
variants and the finer conditions read right. Keep that mapping in the widget:

```qml
function iconFor(code, day) {
    const d = day ? "day" : "night";
    if (code === 0) return "weather-clear-" + d;
    if (code === 1 || code === 2) return "weather-partly-cloudy-" + d;
    if (code === 3) return "weather-overcast";
    if (code >= 51 && code <= 57) return "weather-drizzle";
    if (code >= 95) return "weather-thunderstorm";
    return "weather-cloudy";
}
// Pill.SymbolIcon { name: root.cur ? iconFor(cur.code, cur.isDay) : "weather-unknown" }
```

### Audio

`Audio` classifies the Pipewire graph and exposes the default devices as
`Audio.sink` (output) and `Audio.source` (input); either can be null, so guard
both. Volume and mute live on the node's `audio` block and are writable:

```qml
readonly property real vol: Audio.sink && Audio.sink.audio ? Audio.sink.audio.volume : 0   // 0..1
readonly property bool micMuted: !!(Audio.source && Audio.source.audio && Audio.source.audio.muted)

// set them by assignment
onMoved: v => { if (Audio.sink && Audio.sink.audio) Audio.sink.audio.volume = v; }
onTapped: { if (Audio.sink) Audio.sink.audio.muted = !Audio.sink.audio.muted; }
```

Switch the default device with `Audio.setOutput(n)` and `Audio.setInput(n)`. The
singleton also lists `Audio.outputs`, `Audio.inputs`, and per-app
`Audio.streams` for a full mixer, and resolves Bluetooth codec and profile, but a
bar widget usually wants only the two defaults.

### Network

`Network` is a view of the daemon's `network` topic. The derived status a bar
reads: `Network.kind` is `"ethernet"`, `"wifi"`, or `""`; `Network.level` is the
`0..1` Wi-Fi strength; `Network.wifiRadio` is the radio on/off; `Network.activeSsid`
and `Network.wifiConnectivity` describe the current link. A VPN indicator is
`Network.vpnActive` with `Network.vpnName`. Intents ride back as method calls:
`Network.refresh()` (scan), `Network.setWifiEnabled(on)`,
`Network.connectWifi(ssid, password)`, `Network.disconnectWifi()`,
`Network.forgetWifi(ssid)`.

### Tray

`Tray` is a view of the daemon's `tray` topic. `Tray.items` is the live SNI row;
each item carries a `service`, a resolved `iconPath` (a file) or `iconName` (a
theme name), so pick an image source from those. Left click activates,
right click asks for the item's menu, both anchored to a global point:

```qml
visible: Tray.items.length > 0
Repeater {
    model: Tray.items
    delegate: Item {
        required property var modelData
        // source: iconPath ? ("file://" + iconPath) : Quickshell.iconPath(iconName, ...)
        MouseArea {
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: event => {
                const g = mapToGlobal(0, height);
                if (event.button === Qt.LeftButton)
                    Tray.activate(modelData.service, Math.round(g.x), Math.round(g.y));
                else
                    Tray.contextMenu(modelData.service, Math.round(g.x), Math.round(g.y));
            }
        }
    }
}
```

### The audio visualizer (cava)

Two singletons feed the frequency bars, both driven by `cava` behind the scenes.
`AudioBars` is the playback spectrum: `AudioBars.levels` is an array of
`AudioBars.bars` values (40), each `0..1`, refreshed at `AudioBars.fps` (30), and
`AudioBars.energy` is the mean across the bands. Like `Sysinfo`, it is
owner-refcounted, so cava runs only while a visible surface claims it:

```qml
Component.onCompleted: AudioBars.setActive(root, true)
Component.onDestruction: AudioBars.setActive(root, false)

Repeater {
    model: AudioBars.bars
    delegate: Rectangle {
        required property int index
        height: 4 + AudioBars.levels[index] * 40   // 0..1 per band
    }
}
```

`VoiceBars` mirrors it for the microphone: `VoiceBars.levels` over
`VoiceBars.bars` (16), gated by a plain boolean you set (`VoiceBars.active = true`,
not a refcount), with a small noise `floor` so room tone does not ripple the
resting line. Both settle flat when frames stop arriving, so an idle visualizer
falls to its rest slivers rather than freezing on the last peak.

### Tokens and icons

Never hardcode a colour, a font, a size, or a duration. `Theme` carries the
shell palette and metrics: colours (`Theme.surface`, `Theme.onSurface`,
`Theme.onSurfaceVariant`, `Theme.primary`, `Theme.onPrimary`, `Theme.outline`,
`Theme.error`), fonts (`Theme.fontPrimary`, `Theme.mono`, `Theme.fontJp`,
`Theme.display`), sizes (`Theme.fontSm`/`fontMd`/`fontLg`/`fontXl`/`fontXxl`,
`Theme.iconSm`/`iconMd`/`iconLg`, `Theme.radiusWidget`, `Theme.radiusWindow`,
`Theme.borderWidth`), and `Theme.windowOpacity` for surface translucency. It also
holds small helpers like `Theme.joinArtists(artists, single)`.

`Motion` carries the timing tokens: `Motion.fast` (140ms), `Motion.standard`
(300ms), `Motion.morph` (420ms) and the rest, plus `Motion.easeStandard`. Gate
any `Behavior` on `!Motion.reduce`, which collapses animation to an instant cut
on a weak GPU or when the user asks for less motion:

```qml
Behavior on color {
    enabled: !Motion.reduce
    ColorAnimation { duration: Motion.fast; easing.type: Motion.easeStandard }
}
```

There are two glyph primitives, reached through the Ryoku root
(`import "../../.." as Pill`):

- **`Pill.MaterialIcon`** is a Material Symbols Rounded ligature. The glyph name
  is the text, and `fill` (0 or 1) picks the outline or filled variant. Use it
  for UI verbs: `Pill.MaterialIcon { text: "music_note"; font.pixelSize: Theme.iconSm }`.
- **`Pill.SymbolIcon`** is one flattened symbolic SVG from the shell's own icon
  set (`framebars/icons/`, freedesktop names without the `-symbolic` suffix),
  tinted to a single colour. Use it for the status glyphs the frame renders
  (battery levels, weather, network, mic):
  `Pill.SymbolIcon { name: "weather-clear-day"; size: 18; color: Theme.onSurface }`.

## The popout pattern

A status widget grows a hover card. Obi's `components/Popout.qml` is that card,
and its contract is three properties:

- `target`: the widget `Item` the card anchors under.
- `targetHovered`: a boolean, bound to a `HoverHandler` on the widget, that says
  the pointer is over the target.
- `content`: a `Component` drawn inside the card.

The popout opens while the pointer is over the target or the card, and eases shut
a moment after both are left. It is its own Overlay `PanelWindow`, click-through
outside the card, and it centres itself under the target while clamping to the
screen. Wire it exactly as `Clock.qml` does:

```qml
import "../components" as C

Item {
    id: root
    // ... the compact readout ...
    HoverHandler { id: hh }

    C.Popout {
        target: root
        targetHovered: hh.hovered
        content: popContent
    }

    Component {
        id: popContent
        Item {
            implicitWidth: col.implicitWidth + 40
            implicitHeight: col.implicitHeight + 36
            Column { id: col; anchors.centerIn: parent; /* the card body */ }
        }
    }
}
```

The card sizes itself from the `content` component's implicit size, so give the
body an `implicitWidth`/`implicitHeight`. Keep any live work (a seek `Timer`, a
poll) inside the `content`, so it runs only while the card is open.

## Per-style settings

A style keeps its own settings in a namespaced key in `shell.json`, read through
`Config` and edited from Bar Studio, so a user tweak survives updates and never
lives in a shipped file. Obi's key is a widget-visibility map:

```qml
// Singletons/Config.qml: a top-level alias, plus a var in the JsonAdapter
property alias obi: adapter.obi
// inside JsonAdapter { ... }
property var obi: ({})
```

The Scene reads it with a small helper and gates each widget. An absent key
reads as shown, so the bar is full by default and only an explicit `false` hides
one:

```qml
function shows(id) { return !Config.obi || Config.obi[id] !== false; }
...
W.Media { visible: win.shows("media") && Media.present }
```

Bar Studio writes it live. Add the key to the Hub's `defs` and `liveKeys`
(`hub/quickshell/Hub.qml`) so it snapshots and applies as you toggle, then add a
section to `BarStudioPage.qml` that reads `fval("obi", {})` and writes
`fedit("obi", nextMap)`. To give a new style its own settings, pick a fresh key
(its id is the obvious choice), add the alias and the adapter var to `Config`,
read it in your Scene, and mirror the Hub wiring. A style with no settings omits
all of this.

## Frame menus

The wallpaper picker (Super+W), quick settings (Super+Esc), and the capture card
(Super+S) are shell surfaces, not bar widgets, so they are the same in every
style. They normally anchor to the Sumi rail edges and read against the frame
band. A folder style has no rails and hides the band, so `shell.qml` sets
`topBar` on the per-monitor `FrameMenuManager`: side and bottom anchors fold up
to the matching top edge or corner (the capture card lands top-left), the menus
drop a small inset below the bar, and each menu paints its own card since the
frame is not there to draw it. Nothing per-style is needed; a top-bar folder
style gets this for free.

## Checklist to ship a style

1. **Folder.** Create `barstyles/<id>/` with a `Scene.qml` (a per-monitor
   `PanelWindow` that takes `property var modelData` for its screen), a
   `components/` subdir for shared pieces, and a `widgets/` subdir. Import the
   subdirs namespaced and reach the singletons and icons by relative path
   (`../../../Singletons`, `../../..`).
2. **Registry row.** Add one row to `barstyles/registry.js`:
   `{ id: "<id>", name: "<Name>", desc: "<one line>", scene: "barstyles/<id>/Scene.qml" }`.
3. **Select it.** Set `"barStyle": "<id>"` in `~/.config/ryoku/shell.json`.
4. **Restart.** Run `systemctl --user restart ryoku-shell`. Structural edits (new
   files, new imports, a reshaped scene) need the restart; property tweaks inside
   an already-loaded scene reload live.
