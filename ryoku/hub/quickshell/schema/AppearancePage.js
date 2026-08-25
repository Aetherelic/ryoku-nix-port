.pragma library

// AppearancePage as data. Generated from the page it replaces.
// Descriptions are written by hand; the inventory carries engineering
// notes, which are not user copy.

var rows = [{
        "tab": "Theme",
        "group": "COLOUR SCHEME",
        "key": "theme.theme",
        "label": "Colour scheme",
        "desc": "Follow the wallpaper, keep the Ryoku default, or lock one of the 57 named palettes - the same key the sidebar theme picker reads and writes",
        "ctl": "seg",
        "src": "shell.json theme.theme (daemon settings seam); the daemon resolves themePalette and fans it into the shell and every app",
        "opts": [
            "Follow Wallpaper",
            "Default",
            "named palette"
        ]
    },{
        "tab": "Theme",
        "group": "APP THEMING",
        "key": "theme.json themeApps",
        "label": "Theme apps",
        "desc": "Recolour Files, editors and other GTK / libadwaita apps to the palette, or leave them on their own stock colours",
        "ctl": "sw",
        "src": "~/.config/ryoku/theme.json via `ryoku-hub hypr theme-apps on|off`; the daemon renders or blanks the GTK stylesheets"
    },{
        "tab": "Theme",
        "group": "APP THEMING",
        "key": "theme.json gtkTheme",
        "label": "GTK theme",
        "desc": "Adw follows the palette (the libadwaita-consistent GTK3 theme), Adwaita is the stock GNOME look, and System leaves the choice to you",
        "ctl": "seg",
        "opts": [
            "Adw",
            "Adwaita",
            "System"
        ],
        "src": "~/.config/ryoku/theme.json via `ryoku-hub hypr gtk-theme <adw|adwaita|system>`; the daemon owns the gsettings gtk-theme write"
    },{
        "tab": "Theme",
        "group": "APP THEMING",
        "key": "theme.json gnomeAccent",
        "label": "GNOME accent",
        "desc": "Sync the desktop's accent colour to the nearest named accent so Flatpak and GNOME apps that read the system setting follow the palette too",
        "ctl": "sw",
        "src": "~/.config/ryoku/theme.json via `ryoku-hub hypr gnome-accent on|off`; the daemon owns the gsettings accent-color write"
    },{
        "tab": "Theme",
        "group": "WALLPAPER",
        "key": "(no key - a path in a state file)",
        "label": "Wallpaper",
        "desc": "Images from ~/Pictures/Wallpapers, picking one rethemes the desktop",
        "ctl": "text",
        "src": "ryoku-wallpaper (read); written via `ryoku-shell wallpaper set <path>`"
    },{
        "tab": "Comfort",
        "group": "BACKLIGHT",
        "key": "(no key - hardware)",
        "label": "Brightness",
        "desc": "Hardware backlight, applied at once, floors at 5% to stay visible",
        "ctl": "slid",
        "src": "none - `brightnessctl set <N>%`; read back via `brightnessctl -m` (field 4)",
        "lo": 0.05,
        "hi": 1.0,
        "unit": "%",
        "pct": true
    },{
        "tab": "Comfort",
        "group": "NIGHT LIGHT",
        "key": "(no key - process presence)",
        "label": "Warm the screen",
        "desc": "Cuts blue light for the evening, stays on across sessions",
        "ctl": "sw",
        "src": " `off`; state read via `... status` (\"on <temp>\" | \"off\"), which is really `pgrep -x hyprsunset`"
    },{
        "tab": "Comfort",
        "group": "NIGHT LIGHT",
        "key": "(no key - a bare number in a state file)",
        "label": "Temperature",
        "desc": "Lower Kelvin is warmer, saved only while the light is on",
        "ctl": "step",
        "src": "ryoku-nightlight - written only as a side effect of the script's `start`, i.e. only when the light is turned on",
        "lo": 2500.0,
        "hi": 6500.0,
        "unit": "K"
    },{
        "tab": "Lighting",
        "group": "DEVICE LIGHTING",
        "key": "lighting.enabled",
        "label": "Let Ryoku control lighting",
        "desc": "RGB through OpenRGB and native laptop providers; off means Ryoku never scans for a device and never writes to one",
        "ctl": "sw",
        "src": "~/.config/ryoku/lighting.json via `ryoku-hub lighting enable|disable`"
    },{
        "tab": "Lighting",
        "group": "DEVICE LIGHTING",
        "key": "(no key - hardware)",
        "label": "Connected devices",
        "desc": "Rescan for keyboards, mice and other RGB hardware after plugging something in",
        "ctl": "text",
        "src": "`ryoku-hub lighting scan`; OpenRGB SDK on 127.0.0.1:6742 plus the asusd Aura D-Bus API on supported ASUS laptops"
    },{
        "tab": "Lighting",
        "group": "DEVICE",
        "key": "lighting.devices.managed",
        "label": "Ryoku controls this device",
        "desc": "Hand one keyboard or mouse over at a time; anything left off keeps its own software, onboard profile or hardware switch in charge",
        "ctl": "sw",
        "src": "~/.config/ryoku/lighting.json via `ryoku-hub lighting set <device> {\"managed\":true}`"
    },{
        "tab": "Lighting",
        "group": "DEVICE",
        "key": "lighting.devices.effect",
        "label": "Ryoku effects",
        "desc": "Solid, Breathe, Pulse, Spectrum, Rainbow Wave, Comet and Scanner, painted by Ryoku on the device's per-key mode so they work even where the firmware ignores its own effect list; they need Ryoku running",
        "ctl": "seg",
        "src": "~/.config/ryoku/lighting.json; drawn by `ryoku-hub lighting animate`"
    },{
        "tab": "Lighting",
        "group": "DEVICE",
        "key": "lighting.devices.mode",
        "label": "This device's effects",
        "desc": "Every effect the device itself reports, from its onboard animations to per-key Direct; these keep running with Ryoku closed",
        "ctl": "seg",
        "src": "the device's own mode list, read from its active lighting provider"
    },{
        "tab": "Lighting",
        "group": "DEVICE",
        "key": "lighting.devices.source",
        "label": "Colour",
        "desc": "Follow the wallpaper accent so the keyboard retints with the desktop, or keep a fixed colour of your own",
        "ctl": "seg",
        "opts": [
            "Wallpaper",
            "Fixed"
        ],
        "src": "~/.config/ryoku/lighting.json; the accent comes from ~/.cache/ryoku/hypr-colors.lua"
    },{
        "tab": "Lighting",
        "group": "DEVICE",
        "key": "lighting.devices.brightness",
        "label": "Brightness",
        "desc": "Scaled into the steps the device offers, and left alone until you move it",
        "ctl": "slid",
        "lo": 0.0,
        "hi": 100.0,
        "unit": "%",
        "src": "~/.config/ryoku/lighting.json"
    },{
        "tab": "Lighting",
        "group": "DEVICE",
        "key": "lighting.devices.speed",
        "label": "Speed",
        "desc": "How fast the device runs the effect on its own, for effects that have a speed",
        "ctl": "slid",
        "lo": 0.0,
        "hi": 100.0,
        "unit": "%",
        "src": "~/.config/ryoku/lighting.json"
    },{
        "tab": "Lighting",
        "group": "DEVICE",
        "key": "lighting.devices.direction",
        "label": "Direction",
        "desc": "Which way a wave or comet travels, for devices that offer a direction",
        "ctl": "seg",
        "src": "the device's own mode capabilities, read from its active lighting provider"
    },{
        "tab": "Lighting",
        "group": "DEVICE",
        "key": "(no key - the device's own memory)",
        "label": "Save to device",
        "desc": "Store the look in the device so it holds with Ryoku closed; only for devices that offer it, and it replaces the profile in their active slot",
        "ctl": "text",
        "src": "`ryoku-hub lighting save <device>`, the OpenRGB SDK save-mode request"
    },{
        "tab": "Lighting",
        "group": "DEVICE",
        "key": "(no key - an action)",
        "label": "Hand back",
        "desc": "Stop controlling one device and put it back to the effect it was on before Ryoku touched it, keeping its settings for later",
        "ctl": "text",
        "src": "`ryoku-hub lighting release <device>`"
    }
];
