.pragma library

// The atoll bar and the preserved sidebar content. Opening controls stay out of
// the Hub while the sidebars have no entry path.

var rows = [{
        "tab": "Bar",
        "group": "BAR",
        "key": "barEnabled",
        "label": "Enable bar",
        "desc": "Show the atoll islands",
        "ctl": "sw",
        "src": "shell"
    },{
        "tab": "Bar",
        "group": "BAR",
        "key": "barPosition",
        "label": "Position",
        "desc": "Which screen edge the islands float against",
        "ctl": "seg",
        "src": "shell",
        "opts": ["top", "bottom"]
    },{
        "tab": "Bar",
        "group": "BAR",
        "key": "atollVariant",
        "label": "Atoll look",
        "desc": "Faithful to ilyamiro, or Ryoku-native square grainy islands",
        "ctl": "seg",
        "src": "shell",
        "opts": ["ilyamiro", "ryoku"]
    },{
        "tab": "Bar",
        "group": "BAR",
        "key": "barHeight",
        "label": "Island height",
        "desc": "How tall the floating islands are",
        "ctl": "step",
        "src": "shell",
        "lo": 18.0,
        "hi": 48.0,
        "unit": "px"
    },{
        "tab": "Sidebars",
        "group": "LEFT CONTENT",
        "key": "sidebarLeftPanes",
        "label": "Left sidebar panes",
        "desc": "Preserved Features content and ordering",
        "ctl": "multi",
        "src": "shell",
        "opts": ["stash"]
    },{
        "tab": "Sidebars",
        "group": "RIGHT CONTENT",
        "key": "sidebarRightPanes",
        "label": "Right sidebar panes",
        "desc": "Preserved System content and ordering",
        "ctl": "multi",
        "src": "shell",
        "opts": ["notifications", "calendar", "media", "weather", "recording"]
    },{
        "tab": "Sidebars",
        "group": "PANEL",
        "key": "sidebarWidth",
        "label": "Width",
        "desc": "Saved width for the preserved sidebar content",
        "ctl": "step",
        "src": "shell",
        "lo": 240.0,
        "hi": 520.0,
        "unit": "px",
        "adv": true
    }];
