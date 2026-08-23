.pragma library

// WidgetsPage as data. Generated from the page it replaces.
// Descriptions are written by hand; the inventory carries engineering
// notes, which are not user copy.

var rows = [
    {
        "tab": "clock",
        "group": "WIDGET",
        "key": "clockEnabled",
        "label": "Enabled",
        "desc": "Shows the clock on your wallpaper; settings are kept while off",
        "ctl": "sw",
        "src": "widgets.json"
    },
    {
        "tab": "clock",
        "group": "WIDGET",
        "key": "clockDesign",
        "label": "Face",
        "desc": "How the time is drawn: digits, analog hands, flip cards, rings, a big hour, a metal readout or a good-night card",
        "ctl": "chips",
        "src": "widgets.json",
        "opts": [
            "digital",
            "minimal",
            "analog",
            "flip",
            "rings",
            "bighour",
            "metal",
            "goodnight"
        ]
    },
    {
        "tab": "clock",
        "group": "WIDGET",
        "key": "clockAccent",
        "label": "Accent",
        "desc": "Highlight colour: palette follows the wallpaper, mono stays greyscale",
        "ctl": "seg",
        "src": "widgets.json",
        "opts": [
            "palette",
            "brand",
            "mono"
        ]
    },
    {
        "tab": "clock",
        "group": "FORMAT",
        "key": "clock24h",
        "label": "24-hour clock",
        "desc": "Shows 14:30 rather than 2:30 pm on the face",
        "ctl": "sw",
        "src": "widgets.json"
    },
    {
        "tab": "clock",
        "group": "FORMAT",
        "key": "clockSeconds",
        "label": "Show seconds",
        "desc": "Adds seconds to the readout, the face updates every second",
        "ctl": "sw",
        "src": "widgets.json"
    },
    {
        "tab": "clock",
        "group": "DATE",
        "key": "dateShow",
        "label": "Show date",
        "desc": "Adds today's date beside or under the time, styled by Date style",
        "ctl": "sw",
        "src": "widgets.json"
    },
    {
        "tab": "clock",
        "group": "DATE",
        "key": "dateDesign",
        "label": "Date style",
        "desc": "How the date sits with the time: inline, as a badge, or stacked below",
        "ctl": "seg",
        "src": "widgets.json",
        "opts": [
            "inline",
            "badge",
            "stacked"
        ]
    },
    {
        "tab": "clock",
        "group": "SIZE & SHAPE",
        "key": "clockScale",
        "label": "Size",
        "desc": "Multiplies the widget's base size, 1.00 is the designed size",
        "ctl": "step",
        "src": "widgets.json",
        "lo": 0.5,
        "hi": 2.5
    },
    {
        "tab": "clock",
        "group": "SIZE & SHAPE",
        "key": "clockBg",
        "label": "Background",
        "desc": "Panel drawn behind the widget; pick none to sit right on the wallpaper",
        "ctl": "seg",
        "src": "widgets.json",
        "opts": [
            "none",
            "card",
            "glass"
        ]
    },
    {
        "tab": "clock",
        "group": "SIZE & SHAPE",
        "key": "clockRadius",
        "label": "Corner radius",
        "desc": "Rounds the panel corners; only applies with a card or glass background",
        "ctl": "step",
        "src": "widgets.json",
        "lo": 0.0,
        "hi": 60.0,
        "unit": "px"
    },
    {
        "tab": "clock",
        "group": "SIZE & SHAPE",
        "key": "clockOpacity",
        "label": "Opacity",
        "desc": "Fades the whole widget; 20% is the floor so it never fully disappears",
        "ctl": "slid",
        "src": "widgets.json",
        "lo": 0.2,
        "hi": 1.0,
        "unit": "%",
        "pct": true
    },
    {
        "tab": "clock",
        "group": "PLACEMENT",
        "key": "clockAnchor",
        "label": "Anchor",
        "desc": "Auto lands the widget on the wallpaper's calmest region and follows it; a zone snaps to an edge or corner; free uses X/Y or dragging",
        "ctl": "pick",
        "src": "widgets.json",
        "opts": [
            "auto",
            "top-left",
            "top",
            "top-right",
            "left",
            "center",
            "right",
            "bottom-left",
            "bottom",
            "bottom-right",
            "free"
        ]
    },
    {
        "tab": "clock",
        "group": "PLACEMENT",
        "key": "clockX",
        "label": "X",
        "desc": "Pixels from the left edge; only used when Anchor is set to free",
        "ctl": "step",
        "src": "widgets.json",
        "lo": 0.0,
        "hi": 5000.0,
        "unit": "px"
    },
    {
        "tab": "clock",
        "group": "PLACEMENT",
        "key": "clockY",
        "label": "Y",
        "desc": "Pixels from the top edge; only used when Anchor is set to free",
        "ctl": "step",
        "src": "widgets.json",
        "lo": 0.0,
        "hi": 5000.0,
        "unit": "px"
    },
    {
        "tab": "clock",
        "group": "PLACEMENT",
        "key": "clockLocked",
        "label": "Lock on desktop",
        "desc": "Stops drags on the wallpaper so the widget cannot be moved by accident",
        "ctl": "sw",
        "src": "widgets.json"
    },
    {
        "tab": "calendar",
        "group": "WIDGET",
        "key": "calendarEnabled",
        "label": "Enabled",
        "desc": "Shows the calendar on the wallpaper; settings are kept while off",
        "ctl": "sw",
        "src": "widgets.json"
    },
    {
        "tab": "calendar",
        "group": "WIDGET",
        "key": "calendarStyle",
        "label": "Style",
        "desc": "Wallpaper Glass follows the wallpaper tint; Ryoku Paper is opaque paper and ink",
        "ctl": "seg",
        "src": "widgets.json",
        "opts": ["glass", "paper"]
    },
    {
        "tab": "calendar",
        "group": "CALENDAR",
        "key": "calendarWeeks",
        "label": "Minimum weeks",
        "desc": "Prefers four to eight rows; compact views grow when needed so no dates are omitted",
        "ctl": "step",
        "src": "widgets.json",
        "lo": 4,
        "hi": 8
    },
    {
        "tab": "calendar",
        "group": "CALENDAR",
        "key": "calendarWeekNumbers",
        "label": "ISO week numbers",
        "desc": "Adds the week-of-year column to the left of the calendar",
        "ctl": "sw",
        "src": "widgets.json"
    },
    {
        "tab": "calendar",
        "group": "HOLIDAYS",
        "key": "calendarHolidayRegion",
        "label": "Holiday region",
        "desc": "Blank follows the system locale; use a country or subdivision code such as US or US-CA",
        "ctl": "text",
        "src": "widgets.json"
    },
    {
        "tab": "calendar",
        "group": "SIZE & SHAPE",
        "key": "calendarScale",
        "label": "Size",
        "desc": "Multiplies the calendar's designed size",
        "ctl": "step",
        "src": "widgets.json",
        "lo": 0.5,
        "hi": 2.0
    },
    {
        "tab": "calendar",
        "group": "SIZE & SHAPE",
        "key": "calendarOpacity",
        "label": "Opacity",
        "desc": "Fades the calendar while keeping it readable",
        "ctl": "slid",
        "src": "widgets.json",
        "lo": 0.2,
        "hi": 1.0,
        "unit": "%",
        "pct": true
    },
    {
        "tab": "calendar",
        "group": "PLACEMENT",
        "key": "calendarAnchor",
        "label": "Anchor",
        "desc": "Auto lands the calendar on the wallpaper's calmest region and follows it; a zone snaps to an edge or corner; free uses X/Y or dragging",
        "ctl": "pick",
        "src": "widgets.json",
        "opts": ["auto", "top-left", "top", "top-right", "left", "center", "right", "bottom-left", "bottom", "bottom-right", "free"]
    },
    {
        "tab": "calendar",
        "group": "PLACEMENT",
        "key": "calendarX",
        "label": "X",
        "desc": "Pixels from the left edge when Anchor is free",
        "ctl": "step",
        "src": "widgets.json",
        "lo": 0,
        "hi": 5000,
        "unit": "px"
    },
    {
        "tab": "calendar",
        "group": "PLACEMENT",
        "key": "calendarY",
        "label": "Y",
        "desc": "Pixels from the top edge when Anchor is free",
        "ctl": "step",
        "src": "widgets.json",
        "lo": 0,
        "hi": 5000,
        "unit": "px"
    },
    {
        "tab": "calendar",
        "group": "PLACEMENT",
        "key": "calendarLocked",
        "label": "Lock on desktop",
        "desc": "Stops accidental moves and resizes",
        "ctl": "sw",
        "src": "widgets.json"
    },
    {
        "tab": "music",
        "group": "WIDGET",
        "key": "musicEnabled",
        "label": "Enabled",
        "desc": "Shows the now-playing sheet on your wallpaper; settings are kept while off",
        "ctl": "sw",
        "src": "widgets.json"
    },
    {
        "tab": "music",
        "group": "WIDGET",
        "key": "musicStyle",
        "label": "Style",
        "desc": "Cover wears the album's own colour; Glass is a frosted wallpaper pane",
        "ctl": "seg",
        "src": "widgets.json",
        "opts": ["cover", "glass"]
    },
    {
        "tab": "music",
        "group": "WIDGET",
        "key": "musicLyrics",
        "label": "Lyrics",
        "desc": "Shows the synced lyric sheet beside the album when a match is found",
        "ctl": "sw",
        "src": "widgets.json"
    },
    {
        "tab": "music",
        "group": "WIDGET",
        "key": "musicViz",
        "label": "Visualiser",
        "desc": "The look when a track has no lyrics: Bars is the original spectrum, Wave a smoothed band",
        "ctl": "seg",
        "src": "widgets.json",
        "opts": ["bars", "wave"]
    },
    {
        "tab": "music",
        "group": "WIDGET",
        "key": "musicApp",
        "label": "Music app",
        "desc": "The app the corner button opens; blank uses ryotunes (YouTube Music)",
        "ctl": "app",
        "src": "widgets.json"
    },
    {
        "tab": "music",
        "group": "SIZE & SHAPE",
        "key": "musicScale",
        "label": "Size",
        "desc": "Multiplies the sheet's designed size",
        "ctl": "step",
        "src": "widgets.json",
        "lo": 0.5,
        "hi": 2.0
    },
    {
        "tab": "music",
        "group": "SIZE & SHAPE",
        "key": "musicOpacity",
        "label": "Opacity",
        "desc": "Fades the sheet while keeping it readable",
        "ctl": "slid",
        "src": "widgets.json",
        "lo": 0.2,
        "hi": 1.0,
        "unit": "%",
        "pct": true
    },
    {
        "tab": "music",
        "group": "PLACEMENT",
        "key": "musicAnchor",
        "label": "Anchor",
        "desc": "Auto lands the sheet on the wallpaper's calmest region and follows it; a zone snaps to an edge or corner; free uses X/Y or dragging",
        "ctl": "pick",
        "src": "widgets.json",
        "opts": ["auto", "top-left", "top", "top-right", "left", "center", "right", "bottom-left", "bottom", "bottom-right", "free"]
    },
    {
        "tab": "music",
        "group": "PLACEMENT",
        "key": "musicX",
        "label": "X",
        "desc": "Pixels from the left edge when Anchor is free",
        "ctl": "step",
        "src": "widgets.json",
        "lo": 0,
        "hi": 5000,
        "unit": "px"
    },
    {
        "tab": "music",
        "group": "PLACEMENT",
        "key": "musicY",
        "label": "Y",
        "desc": "Pixels from the top edge when Anchor is free",
        "ctl": "step",
        "src": "widgets.json",
        "lo": 0,
        "hi": 5000,
        "unit": "px"
    },
    {
        "tab": "music",
        "group": "PLACEMENT",
        "key": "musicLocked",
        "label": "Lock on desktop",
        "desc": "Stops accidental moves and resizes",
        "ctl": "sw",
        "src": "widgets.json"
    },
    {
        "tab": "aio", "group": "WIDGET", "key": "aioEnabled", "label": "Enabled",
        "desc": "Shows the all-in-one weather + clock card on your wallpaper; settings are kept while off",
        "ctl": "sw", "src": "widgets.json"
    },
    {
        "tab": "aio", "group": "WIDGET", "key": "aioStyle", "label": "Layout",
        "desc": "Wide is the landscape card; Tall is the portrait day-number panel",
        "ctl": "seg", "src": "widgets.json", "opts": ["wide", "tall"]
    },
    {
        "tab": "aio", "group": "SIZE & SHAPE", "key": "aioScale", "label": "Size",
        "desc": "Multiplies the card's designed size",
        "ctl": "step", "src": "widgets.json", "lo": 0.5, "hi": 2.0
    },
    {
        "tab": "aio", "group": "SIZE & SHAPE", "key": "aioOpacity", "label": "Opacity",
        "desc": "Fades the card while keeping it readable",
        "ctl": "slid", "src": "widgets.json", "lo": 0.2, "hi": 1.0, "unit": "%", "pct": true
    },
    {
        "tab": "aio", "group": "PLACEMENT", "key": "aioAnchor", "label": "Anchor",
        "desc": "Auto lands the card on the wallpaper's calmest region and follows it; a zone snaps to an edge or corner; free uses X/Y or dragging",
        "ctl": "pick", "src": "widgets.json",
        "opts": ["auto", "top-left", "top", "top-right", "left", "center", "right", "bottom-left", "bottom", "bottom-right", "free"]
    },
    {
        "tab": "aio", "group": "PLACEMENT", "key": "aioX", "label": "X",
        "desc": "Pixels from the left edge when Anchor is free",
        "ctl": "step", "src": "widgets.json", "lo": 0, "hi": 5000, "unit": "px"
    },
    {
        "tab": "aio", "group": "PLACEMENT", "key": "aioY", "label": "Y",
        "desc": "Pixels from the top edge when Anchor is free",
        "ctl": "step", "src": "widgets.json", "lo": 0, "hi": 5000, "unit": "px"
    },
    {
        "tab": "aio", "group": "PLACEMENT", "key": "aioLocked", "label": "Lock on desktop",
        "desc": "Stops accidental moves and resizes",
        "ctl": "sw", "src": "widgets.json"
    },
    {
        "tab": "stats", "group": "WIDGET", "key": "statsEnabled", "label": "Enabled",
        "desc": "Shows the system-stats panel on your wallpaper; settings are kept while off",
        "ctl": "sw", "src": "widgets.json"
    },
    {
        "tab": "stats", "group": "SIZE & SHAPE", "key": "statsScale", "label": "Size",
        "desc": "Multiplies the panel's designed size",
        "ctl": "step", "src": "widgets.json", "lo": 0.5, "hi": 2.0
    },
    {
        "tab": "stats", "group": "SIZE & SHAPE", "key": "statsOpacity", "label": "Opacity",
        "desc": "Fades the panel while keeping it readable",
        "ctl": "slid", "src": "widgets.json", "lo": 0.2, "hi": 1.0, "unit": "%", "pct": true
    },
    {
        "tab": "stats", "group": "PLACEMENT", "key": "statsAnchor", "label": "Anchor",
        "desc": "Auto lands the panel on the wallpaper's calmest region and follows it; a zone snaps to an edge or corner; free uses X/Y or dragging",
        "ctl": "pick", "src": "widgets.json",
        "opts": ["auto", "top-left", "top", "top-right", "left", "center", "right", "bottom-left", "bottom", "bottom-right", "free"]
    },
    {
        "tab": "stats", "group": "PLACEMENT", "key": "statsX", "label": "X",
        "desc": "Pixels from the left edge when Anchor is free",
        "ctl": "step", "src": "widgets.json", "lo": 0, "hi": 5000, "unit": "px"
    },
    {
        "tab": "stats", "group": "PLACEMENT", "key": "statsY", "label": "Y",
        "desc": "Pixels from the top edge when Anchor is free",
        "ctl": "step", "src": "widgets.json", "lo": 0, "hi": 5000, "unit": "px"
    },
    {
        "tab": "stats", "group": "PLACEMENT", "key": "statsLocked", "label": "Lock on desktop",
        "desc": "Stops accidental moves and resizes",
        "ctl": "sw", "src": "widgets.json"
    },
    {
        "tab": "weather", "group": "WIDGET", "key": "weatherEnabled", "label": "Enabled",
        "desc": "Shows the weather on your wallpaper; settings are kept while off",
        "ctl": "sw", "src": "widgets.json"
    },
    {
        "tab": "weather", "group": "WIDGET", "key": "weatherDesign", "label": "Layout",
        "desc": "Compact shows the glyph, temperature and city; Full adds the condition, a humidity/wind/feels row and a three-day strip",
        "ctl": "seg", "src": "widgets.json", "opts": ["compact", "full"]
    },
    {
        "tab": "weather", "group": "SIZE & SHAPE", "key": "weatherScale", "label": "Size",
        "desc": "Multiplies the widget's designed size",
        "ctl": "step", "src": "widgets.json", "lo": 0.5, "hi": 2.5
    },
    {
        "tab": "weather", "group": "SIZE & SHAPE", "key": "weatherOpacity", "label": "Opacity",
        "desc": "Fades the widget while keeping it readable",
        "ctl": "slid", "src": "widgets.json", "lo": 0.2, "hi": 1.0, "unit": "%", "pct": true
    },
    {
        "tab": "weather", "group": "PLACEMENT", "key": "weatherAnchor", "label": "Anchor",
        "desc": "Auto lands the widget on the wallpaper's calmest region and follows it; a zone snaps to an edge or corner; free uses X/Y or dragging",
        "ctl": "pick", "src": "widgets.json",
        "opts": ["auto", "top-left", "top", "top-right", "left", "center", "right", "bottom-left", "bottom", "bottom-right", "free"]
    },
    {
        "tab": "weather", "group": "PLACEMENT", "key": "weatherX", "label": "X",
        "desc": "Pixels from the left edge when Anchor is free",
        "ctl": "step", "src": "widgets.json", "lo": 0, "hi": 5000, "unit": "px"
    },
    {
        "tab": "weather", "group": "PLACEMENT", "key": "weatherY", "label": "Y",
        "desc": "Pixels from the top edge when Anchor is free",
        "ctl": "step", "src": "widgets.json", "lo": 0, "hi": 5000, "unit": "px"
    },
    {
        "tab": "weather", "group": "PLACEMENT", "key": "weatherLocked", "label": "Lock on desktop",
        "desc": "Stops accidental moves and resizes",
        "ctl": "sw", "src": "widgets.json"
    },
    {
        "tab": "notes", "group": "WIDGET", "key": "notesEnabled", "label": "Enabled",
        "desc": "Shows the scratch pad on your wallpaper; the note itself is kept while off",
        "ctl": "sw", "src": "widgets.json"
    },
    {
        "tab": "notes", "group": "SIZE & SHAPE", "key": "notesWidth", "label": "Width",
        "desc": "Width of the pad in pixels before Size scales it",
        "ctl": "step", "src": "widgets.json", "lo": 160, "hi": 900, "unit": "px"
    },
    {
        "tab": "notes", "group": "SIZE & SHAPE", "key": "notesHeight", "label": "Height",
        "desc": "Height of the pad in pixels before Size scales it",
        "ctl": "step", "src": "widgets.json", "lo": 120, "hi": 900, "unit": "px"
    },
    {
        "tab": "notes", "group": "SIZE & SHAPE", "key": "notesScale", "label": "Size",
        "desc": "Multiplies the pad's width, height and text",
        "ctl": "step", "src": "widgets.json", "lo": 0.5, "hi": 2.5
    },
    {
        "tab": "notes", "group": "SIZE & SHAPE", "key": "notesOpacity", "label": "Opacity",
        "desc": "Fades the pad while keeping it readable",
        "ctl": "slid", "src": "widgets.json", "lo": 0.2, "hi": 1.0, "unit": "%", "pct": true
    },
    {
        "tab": "notes", "group": "PLACEMENT", "key": "notesAnchor", "label": "Anchor",
        "desc": "Auto lands the pad on the wallpaper's calmest region and follows it; a zone snaps to an edge or corner; free uses X/Y or dragging",
        "ctl": "pick", "src": "widgets.json",
        "opts": ["auto", "top-left", "top", "top-right", "left", "center", "right", "bottom-left", "bottom", "bottom-right", "free"]
    },
    {
        "tab": "notes", "group": "PLACEMENT", "key": "notesX", "label": "X",
        "desc": "Pixels from the left edge when Anchor is free",
        "ctl": "step", "src": "widgets.json", "lo": 0, "hi": 5000, "unit": "px"
    },
    {
        "tab": "notes", "group": "PLACEMENT", "key": "notesY", "label": "Y",
        "desc": "Pixels from the top edge when Anchor is free",
        "ctl": "step", "src": "widgets.json", "lo": 0, "hi": 5000, "unit": "px"
    },
    {
        "tab": "notes", "group": "PLACEMENT", "key": "notesLocked", "label": "Lock on desktop",
        "desc": "Stops accidental moves and resizes",
        "ctl": "sw", "src": "widgets.json"
    }
];
