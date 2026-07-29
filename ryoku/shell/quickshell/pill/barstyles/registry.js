// Registry of bar styles. Each style is a self-contained folder under
// pill/barstyles/<id>/ holding its own Scene.qml (the per-monitor bar), its
// widgets, its popouts and its settings. `scene` is the QML shell.qml loads
// per monitor, resolved relative to shell.qml; an empty scene means the
// built-in frame scene (Sumi), which shell.qml draws itself.
//
// Adding a style: drop its folder under barstyles/, then add one row here.
var STYLES = [
    { id: "sumi", name: "Sumi", desc: "Ink spine: the left rail, paper and ink.", scene: "" },
    { id: "obi", name: "Obi", desc: "Sash: a floating top bar with kanji workspaces.", scene: "barstyles/obi/Scene.qml" },
    { id: "nacre", name: "Nacre", desc: "Pearl: three frosted islands joined to the desktop frame.", scene: "barstyles/nacre/Scene.qml" }
];

function list() { return STYLES; }
function ids() { return STYLES.map(function (s) { return s.id; }); }
function entry(id) {
    for (var i = 0; i < STYLES.length; i++)
        if (STYLES[i].id === id) return STYLES[i];
    return STYLES[0];
}
function sceneUrl(id) { return entry(id).scene; }
function isBuiltin(id) { return sceneUrl(id) === ""; }

if (typeof module !== "undefined" && module.exports)
    module.exports = { list, ids, entry, sceneUrl, isBuiltin };
