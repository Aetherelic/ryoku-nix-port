// Resolve which audio node is selected in a way that survives a Pipewire graph
// refresh. Pipewire hands out fresh node objects on every change, so match on
// the stable node.name; when the remembered device is gone, fall back to the
// live default rather than dropping the selection.

function stable(nodes, prevName, fallback) {
    var list = Array.isArray(nodes) ? nodes : [];
    if (prevName) {
        for (var i = 0; i < list.length; i++)
            if (list[i] && list[i].name === prevName) return list[i];
    }
    if (fallback) {
        for (var j = 0; j < list.length; j++)
            if (list[j] && list[j].name === fallback.name) return list[j];
        return fallback;
    }
    return list.length ? list[0] : null;
}

if (typeof module !== "undefined" && module.exports) module.exports = { stable };
