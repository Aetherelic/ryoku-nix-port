function copy(value) {
    return JSON.parse(JSON.stringify(value));
}

function zones(edge) {
    return edge === "top" || edge === "bottom" ? ["start", "center", "end"] : ["top", "center", "bottom"];
}

function pathList(menu, path) {
    let list = menu.widgets;
    if (!Array.isArray(path)) return null;
    for (let i = 0; i < path.length; i += 2) {
        const index = path[i];
        if (path[i + 1] !== "widgets" || !Number.isInteger(index) || !list[index] || !Array.isArray(list[index].widgets)) return null;
        list = list[index].widgets;
    }
    return list;
}

function menuRecord(config, id, catalog) {
    return config.menus && config.menus[id] && catalog.menu(id) ? config.menus[id] : null;
}

function addZoneItem(config, edge, zone, id, catalog) {
    const next = copy(config);
    if (!next.rails || !next.rails[edge] || !zones(edge).includes(zone)) return next;
    const entry = catalog.entry(id);
    const axis = edge === "top" || edge === "bottom" ? "horizontal" : "vertical";
    const list = next.rails[edge][zone];
    if (!entry || !entry.axes.includes(axis) || !Array.isArray(list) || list.includes(id)) return next;
    list.push(id);
    return next;
}

function moveZoneItem(config, fromEdge, fromZone, index, toEdge, toZone, targetIndex, catalog) {
    const next = copy(config);
    if (!next.rails || !next.rails[fromEdge] || !next.rails[toEdge] || !zones(fromEdge).includes(fromZone) || !zones(toEdge).includes(toZone)) return next;
    const source = next.rails[fromEdge][fromZone];
    const target = next.rails[toEdge][toZone];
    if (!Array.isArray(source) || !Array.isArray(target) || !Number.isInteger(index) || index < 0 || index >= source.length) return next;
    const id = source[index];
    const entry = catalog.entry(id);
    const axis = toEdge === "top" || toEdge === "bottom" ? "horizontal" : "vertical";
    if (!entry || !entry.axes.includes(axis) || (source !== target && target.includes(id))) return next;
    source.splice(index, 1);
    const bounded = Math.max(0, Math.min(Number.isInteger(targetIndex) ? targetIndex : target.length, target.length));
    target.splice(bounded, 0, id);
    return next;
}

function removeZoneItem(config, edge, zone, index) {
    const next = copy(config);
    if (!next.rails || !next.rails[edge] || !zones(edge).includes(zone)) return next;
    const list = next.rails[edge][zone];
    if (Array.isArray(list) && Number.isInteger(index) && index >= 0 && index < list.length) list.splice(index, 1);
    return next;
}

function createMenu(config, id, catalog) {
    const next = copy(config);
    const record = catalog.menu(id);
    if (!record || !next.menus) return next;
    next.menus[id] = copy({ anchor: record.anchor, minWidth: record.minWidth, expansion: record.expansion, widgets: record.widgets });
    return next;
}

function setMenuAnchor(config, id, anchor, catalog) {
    const next = copy(config);
    const menu = menuRecord(next, id, catalog);
    if (menu && catalog.anchors().includes(anchor)) menu.anchor = anchor;
    return next;
}

function setMenu(config, id, value, catalog) {
    const next = copy(config);
    const menu = menuRecord(next, id, catalog);
    if (!menu || !value || typeof value !== "object") return next;
    if (catalog.anchors().includes(value.anchor)) menu.anchor = value.anchor;
    if (Number.isFinite(value.minWidth)) menu.minWidth = Math.max(1, Math.round(value.minWidth));
    if (value.expansion === "always" || value.expansion === "never") menu.expansion = value.expansion;
    return next;
}

function addMenuWidget(config, id, path, widgetId, catalog) {
    const next = copy(config);
    const menu = menuRecord(next, id, catalog);
    const widget = catalog.widget(widgetId);
    const list = menu ? pathList(menu, path) : null;
    if (!widget || !list) return next;
    list.push(widget.nested ? { id: widgetId, widgets: [] } : widgetId);
    return next;
}

function moveMenuWidget(config, id, fromPath, index, toPath, targetIndex, catalog) {
    const next = copy(config);
    const menu = menuRecord(next, id, catalog);
    const source = menu ? pathList(menu, fromPath) : null;
    const target = menu ? pathList(menu, toPath) : null;
    if (!source || !target || !Number.isInteger(index) || index < 0 || index >= source.length) return next;
    const item = source[index];
    const widget = catalog.widget(typeof item === "string" ? item : item && item.id);
    if (!widget || (source !== target && target.some(value => JSON.stringify(value) === JSON.stringify(item)))) return next;
    source.splice(index, 1);
    const bounded = Math.max(0, Math.min(Number.isInteger(targetIndex) ? targetIndex : target.length, target.length));
    target.splice(bounded, 0, item);
    return next;
}

function removeMenuWidget(config, id, path, index, catalog) {
    const next = copy(config);
    const menu = menuRecord(next, id, catalog);
    const list = menu ? pathList(menu, path) : null;
    if (list && Number.isInteger(index) && index >= 0 && index < list.length) list.splice(index, 1);
    return next;
}

function setRail(config, edge, changes) {
    const next = copy(config);
    const rail = next.rails && next.rails[edge];
    if (!rail || !changes || typeof changes !== "object") return next;
    if (typeof changes.enabled === "boolean") rail.enabled = changes.enabled;
    if (typeof changes.reveal === "boolean") rail.reveal = changes.reveal;
    if (Number.isFinite(changes.size)) rail.size = Math.round(changes.size);
    return next;
}

function setStyle(config, style) {
    const next = copy(config);
    if (style === "ok-frame" || style === "ryoku-frame") next.style = style;
    return next;
}

function setSurface(config, id, value, catalog) {
    const next = copy(config);
    const fallback = catalog.surface(id);
    if (!fallback || !next.surfaces || !value || typeof value !== "object") return next;
    const surface = next.surfaces[id];
    if (!surface) return next;
    if (catalog.anchors().includes(value.anchor)) surface.anchor = value.anchor;
    if (Number.isFinite(value.minWidth)) surface.minWidth = Math.max(1, Math.round(value.minWidth));
    if (Array.isArray(value.panes)) surface.panes = value.panes.filter(pane => fallback.panes.includes(pane));
    return next;
}

if (typeof module !== "undefined" && module.exports) module.exports = { addZoneItem, moveZoneItem, removeZoneItem, createMenu, setMenu, setMenuAnchor, addMenuWidget, moveMenuWidget, removeMenuWidget, setRail, setStyle, setSurface };
