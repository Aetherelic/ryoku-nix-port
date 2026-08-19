.pragma library

// Pure helpers for the world-map timezone picker: zone1970.tab parsing, the
// equirectangular projection shared with world-land.js, the live day/night
// solar terminator, and nearest-zone lookup. No QML types, so it is testable.

// zone1970.tab is TAB-separated: country codes, ISO-6709 coordinate, TZ name,
// then an optional comment. Comment lines start with '#'.
function parseZoneTab(text) {
    var out = [];
    var lines = ("" + text).split("\n");
    for (var i = 0; i < lines.length; i++) {
        var ln = lines[i];
        if (!ln || ln.charAt(0) === "#")
            continue;
        var f = ln.split("\t");
        if (f.length < 3)
            continue;
        var c = iso6709(f[1]);
        if (!c)
            continue;
        out.push({ tz: f[2], lat: c.lat, lon: c.lon, cc: f[0], note: f.length > 3 ? f[3] : "" });
    }
    out.sort(function (a, b) { return a.tz < b.tz ? -1 : (a.tz > b.tz ? 1 : 0); });
    return out;
}

// ISO 6709 packed form: sign DD[MM[SS]] for latitude then sign DDD[MM[SS]] for
// longitude, e.g. "+404251-0740023" or the shorter "+4043-07359".
function iso6709(s) {
    if (!s) return null;
    var m = /^([+-]\d+)([+-]\d+)$/.exec(("" + s).trim());
    if (!m) return null;
    return { lat: dms(m[1], true), lon: dms(m[2], false) };
}
function dms(tok, isLat) {
    var sign = tok.charAt(0) === "-" ? -1 : 1;
    var d = tok.slice(1);
    var degLen = isLat ? 2 : 3;
    var deg = parseInt(d.slice(0, degLen), 10) || 0;
    var rest = d.slice(degLen);
    var min = rest.length >= 2 ? (parseInt(rest.slice(0, 2), 10) || 0) : 0;
    var sec = rest.length >= 4 ? (parseInt(rest.slice(2, 4), 10) || 0) : 0;
    return sign * (deg + min / 60 + sec / 3600);
}

// Equirectangular projection into a w x h rectangle (matches world-land.js).
function px(lon, w) { return (lon + 180) / 360 * w; }
function py(lat, h) { return (90 - lat) / 180 * h; }
function lonAt(x, w) { return x / w * 360 - 180; }
function latAt(y, h) { return 90 - y / h * 180; }

// The subsolar point (where the sun is overhead now) for a Date, in UTC. A
// low-order approximation: good to a fraction of a degree, plenty for shading.
function subsolar(date) {
    var yStart = Date.UTC(date.getUTCFullYear(), 0, 0);
    var dayMs = Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate()) - yStart;
    var day = dayMs / 86400000;
    var decl = -23.44 * Math.cos((2 * Math.PI / 365) * (day + 10));
    var utcH = date.getUTCHours() + date.getUTCMinutes() / 60 + date.getUTCSeconds() / 3600;
    var lon = -15 * (utcH - 12);
    while (lon > 180) lon -= 360;
    while (lon < -180) lon += 360;
    return { lat: decl, lon: lon };
}

// Is (lat,lon) sunlit given the subsolar point? (solar zenith cosine > 0)
function isDay(lat, lon, sub) {
    var la = lat * Math.PI / 180, lo = lon * Math.PI / 180;
    var sla = sub.lat * Math.PI / 180, slo = sub.lon * Math.PI / 180;
    var cosz = Math.sin(la) * Math.sin(sla) + Math.cos(la) * Math.cos(sla) * Math.cos(lo - slo);
    return cosz > 0;
}

// The terminator latitude at a longitude: tan(phi) = -cos(H)/tan(decl), with
// H the hour angle. Returns null near the equinoxes where the boundary is two
// meridians rather than a single latitude per column.
function terminatorLat(lon, sub) {
    if (Math.abs(sub.lat) < 0.5) return null;
    var decl = sub.lat * Math.PI / 180;
    var H = (lon - sub.lon) * Math.PI / 180;
    var phi = Math.atan(-Math.cos(H) / Math.tan(decl));
    return phi * 180 / Math.PI;
}

// Nearest zone to a click, by rough on-globe distance (longitude weighted by
// cos(lat) so high-latitude clicks are not skewed by meridian convergence).
function nearest(zones, lat, lon) {
    var best = null, bestD = 1e18;
    var cl = Math.cos(lat * Math.PI / 180);
    for (var i = 0; i < zones.length; i++) {
        var z = zones[i];
        var dlat = z.lat - lat;
        var dlon = z.lon - lon;
        if (dlon > 180) dlon -= 360; else if (dlon < -180) dlon += 360;
        var dx = dlon * cl;
        var d = dlat * dlat + dx * dx;
        if (d < bestD) { bestD = d; best = z; }
    }
    return best;
}

// Substring search over zone name, region note, and country code.
function search(zones, q) {
    var s = ("" + q).trim().toLowerCase();
    if (s.length < 1) return [];
    var out = [];
    for (var i = 0; i < zones.length; i++) {
        var z = zones[i];
        var hay = (z.tz + " " + z.note + " " + z.cc).toLowerCase();
        if (hay.indexOf(s) >= 0) out.push(z);
        if (out.length >= 20) break;
    }
    return out;
}

// A zone name prettied for display: "America/New_York" -> "New York".
function pretty(tz) {
    if (!tz) return "";
    var p = ("" + tz).split("/");
    return p[p.length - 1].replace(/_/g, " ");
}
