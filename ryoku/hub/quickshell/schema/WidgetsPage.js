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
        "desc": "How the time is drawn: digits, analog hands, flip cards or rings",
        "ctl": "chips",
        "src": "widgets.json",
        "opts": [
            "digital",
            "minimal",
            "analog",
            "flip",
            "rings"
        ]
    },
    {
        "tab": "clock",
        "group": "WIDGET",
        "key": "clockAccent",
        "label": "Accent",
        "desc": "Highlight colour: wallust follows the wallpaper, mono stays greyscale",
        "ctl": "seg",
        "src": "widgets.json",
        "opts": [
            "wallust",
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
        "desc": "Snaps the widget to a screen edge or corner; free uses X/Y or dragging",
        "ctl": "pick",
        "src": "widgets.json",
        "opts": [
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
    }
];
