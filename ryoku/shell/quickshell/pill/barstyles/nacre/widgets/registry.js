var ENTRIES = [
    { id: "brand", label: "Brand", file: "Brand.qml" },
    { id: "media", label: "Media", file: "Media.qml" },
    { id: "activeWindow", label: "Active window", file: "ActiveWindow.qml" },
    { id: "clock", label: "Clock", file: "Clock.qml" },
    { id: "workspaces", label: "Workspaces", file: "Workspaces.qml" },
    { id: "resources", label: "Resources", file: "Resources.qml" },
    { id: "connectivity", label: "Connections", file: "Connectivity.qml" },
    { id: "audio", label: "Audio", file: "Audio.qml" },
    { id: "battery", label: "Battery", file: "Battery.qml" },
    { id: "tray", label: "Tray", file: "Tray.qml" },
    { id: "weather", label: "Weather", file: "Weather.qml" },
    { id: "utils", label: "Recording", file: "Utils.qml" }
];

function list() {
    return ENTRIES;
}

function entry(id) {
    for (let i = 0; i < ENTRIES.length; i++)
        if (ENTRIES[i].id === id)
            return ENTRIES[i];
    return null;
}

function source(id) {
    const item = entry(id);
    return item ? "../widgets/" + item.file : "";
}

if (typeof module !== "undefined" && module.exports)
    module.exports = { list, entry, source };
