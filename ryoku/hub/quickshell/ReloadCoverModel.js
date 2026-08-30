function empty() {
    return { path: "", name: "", kind: "default", bytes: 0, enabled: true };
}

function normalize(value) {
    if (!value || typeof value !== "object")
        return empty();
    var path = typeof value.path === "string" ? value.path : "";
    var kind = typeof value.kind === "string" ? value.kind : "default";
    if (path.length === 0 || ["image", "animated", "video"].indexOf(kind) < 0)
        return empty();
    var name = typeof value.name === "string" && value.name.length > 0
        ? value.name
        : path.split("/").pop();
    var bytes = Math.max(0, Math.floor(Number(value.bytes) || 0));
    return { path: path, name: name, kind: kind, bytes: bytes, enabled: value.enabled !== false };
}

function path(value) {
    return normalize(value).path;
}

function formatBytes(value) {
    var bytes = Math.max(0, Number(value) || 0);
    if (bytes === 0)
        return "";
    if (bytes < 1000000)
        return Math.round(bytes / 1000) + " KB";
    return (Math.round(bytes / 100000) / 10).toFixed(1) + " MB";
}

function filters() {
    var suffixes = ["png", "jpg", "jpeg", "webp", "gif", "bmp", "svg", "mp4", "webm", "mkv", "mov"];
    var out = [];
    for (var i = 0; i < suffixes.length; i++) {
        out.push("*." + suffixes[i]);
        out.push("*." + suffixes[i].toUpperCase());
    }
    return out;
}


function rendererSource(shellDir, configHome, home) {
    var dev = typeof shellDir === "string" ? shellDir : "";
    if (dev !== "")
        return "file://" + dev + "/quickshell/reload-cover/ReloadMedia.qml";
    var config = typeof configHome === "string" && configHome !== ""
        ? configHome
        : (typeof home === "string" ? home : "") + "/.config";
    return "file://" + config + "/quickshell/reload-cover/ReloadMedia.qml";
}
if (typeof module !== "undefined" && module.exports)
    module.exports = { empty, normalize, path, formatBytes, filters, rendererSource };
