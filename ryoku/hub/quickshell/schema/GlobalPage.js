.pragma library

// Global: the cross-cutting preferences that are not tied to one surface --
// interface language, regional formats (dates/numbers/currency), the machine
// location (weather + clock), and the shell text size. Every key is a plain
// shell.json value (src "shell"), so the daemon persists and the shell retunes
// live. These were collected here from Desktop (weather) and from nowhere at all
// (language, text size were config-only, with no editor), so each key lives in
// exactly one page -- no overlap.
var rows = [
    {
        "tab": "",
        "group": "LANGUAGE & REGION",
        "key": "language",
        "label": "Language",
        "desc": "Interface language; Auto follows your system locale.",
        "ctl": "chips",
        "src": "shell",
        "opts": ["Auto", "English", "Español", "Français", "Português", "Português (BR)"]
    }, {
        "tab": "",
        "group": "LANGUAGE & REGION",
        "key": "formatLocale",
        "label": "Regional formats",
        "desc": "Dates, numbers and month names use this region while the language above stays as-is. None = follow the system.",
        "ctl": "chips",
        "src": "shell",
        "opts": ["en_US", "en_GB", "pt_BR", "pt_PT", "es_ES", "es_MX", "de_DE", "fr_FR", "it_IT", "nl_NL", "sv_SE", "ja_JP", "zh_CN"]
    }, {
        "tab": "",
        "group": "LOCATION",
        "key": "weatherLocation",
        "label": "Location",
        "desc": "Search a city; empty reads it from your IP. Used for weather and the clock.",
        "ctl": "location",
        "src": "shell"
    }, {
        "tab": "",
        "group": "LOCATION",
        "key": "timezone",
        "label": "Time zone",
        "desc": "The system clock's time zone. Pick it on the world map; applied live with timedatectl.",
        "ctl": "timezone"
    }, {
        "tab": "",
        "group": "LOCATION",
        "key": "weatherUnit",
        "label": "Temperature units",
        "desc": "Auto follows your locale.",
        "ctl": "seg",
        "src": "shell",
        "opts": ["auto", "celsius", "fahrenheit"]
    }, {
        "tab": "",
        "group": "FONT",
        "key": "fontFamily",
        "label": "System font",
        "desc": "One font for the shell, apps and terminal, applied live. Pick a monospace like Maple Mono NF for a clean terminal.",
        "ctl": "pick",
        "src": "shell",
        "opts": []
    }, {
        "tab": "",
        "group": "FONT",
        "key": "fontSize",
        "label": "Font size",
        "desc": "Base text size in points for apps and the terminal.",
        "ctl": "step",
        "src": "shell",
        "lo": 8,
        "hi": 24,
        "unit": " pt"
    }
];
