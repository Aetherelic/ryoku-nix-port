.pragma library

// Bar Studio's searchable settings. Bar Studio renders its own cards from
// BarStudioPage.qml, so these rows exist only to feed the Hub's global search
// (Hub.qml searchIndex): typing "dock", "magnify" or "media chip" from anywhere
// lands on this page. Keep the labels and hints in step with the live cards.
var rows = [{
        "tab": "Dock",
        "group": "DOCK",
        "key": "enabled",
        "label": "Dock",
        "desc": "Show an app dock as its own shell surface, for every bar style",
        "ctl": "sw",
        "src": "shell.json"
    },{
        "tab": "Dock",
        "group": "DOCK",
        "key": "edge",
        "label": "Edge",
        "desc": "Which screen edge the dock sits on; Auto picks the edge opposite the bar",
        "ctl": "seg",
        "src": "shell.json",
        "opts": ["auto","top","bottom","left","right"]
    },{
        "tab": "Dock",
        "group": "DOCK",
        "key": "autohide",
        "label": "Auto-hide",
        "desc": "Hide the dock to a peek strip and reveal it on hover; off keeps it shown and reserves its space",
        "ctl": "sw",
        "src": "shell.json"
    },{
        "tab": "Dock",
        "group": "DOCK",
        "key": "frost",
        "label": "Frost",
        "desc": "Make the dock island translucent",
        "ctl": "sw",
        "src": "shell.json"
    },{
        "tab": "Dock",
        "group": "DOCK",
        "key": "shadow",
        "label": "Depth",
        "desc": "Soft shadow behind the dock island",
        "ctl": "sw",
        "src": "shell.json"
    },{
        "tab": "Dock",
        "group": "DOCK",
        "key": "magnify",
        "label": "Magnify",
        "desc": "Grow icons under the cursor; off in Power Saver",
        "ctl": "sw",
        "src": "shell.json"
    },{
        "tab": "Dock",
        "group": "DOCK",
        "key": "labels",
        "label": "Hover labels",
        "desc": "Show the app name above an icon on hover",
        "ctl": "sw",
        "src": "shell.json"
    },{
        "tab": "Dock",
        "group": "DOCK",
        "key": "media",
        "label": "Media chip",
        "desc": "Show a now-playing chip at the end of the dock",
        "ctl": "sw",
        "src": "shell.json"
    }
];
