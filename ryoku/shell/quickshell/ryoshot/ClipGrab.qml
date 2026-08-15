import QtQuick

// An offscreen window onto part of another item, grabbed to a PNG. Used for the
// export crop, the OCR crop, the redaction palette sample and the eyedropper,
// so all four read exactly the pixels the editor is showing.
Item {
    id: clip

    property Item source: null
    property var rect: null
    property bool ready: true
    property int retries: 25

    clip: true
    visible: false
    width: rect ? Math.max(1, Math.round(rect.w)) : 0
    height: rect ? Math.max(1, Math.round(rect.h)) : 0

    ShaderEffectSource {
        sourceItem: clip.source
        width: clip.source ? clip.source.width : 0
        height: clip.source ? clip.source.height : 0
        x: clip.rect ? -clip.rect.x : 0
        y: clip.rect ? -clip.rect.y : 0
        live: true
        recursive: false
    }

    /**
     * Saves the current crop to path and reports success. A grab can fail while
     * the surface is still settling (a second monitor freezes a few frames
     * late), so a transient miss is retried rather than failing the capture.
     */
    function grab(path, cb, targetSize) { clip.attempt(path, cb, targetSize || null, 0); }

    function attempt(path, cb, targetSize, n) {
        if (!clip.rect) { if (cb) cb(false); return; }
        if (!clip.ready && n < clip.retries) { clip.schedule(path, cb, targetSize, n + 1); return; }
        var handle = function (result) {
            var ok = false;
            try { ok = result ? result.saveToFile(path) : false; }
            catch (e) { console.log("ryoshot: saveToFile failed: " + e); }
            if (ok) { if (cb) cb(true); return; }
            if (n < clip.retries) { clip.schedule(path, cb, targetSize, n + 1); return; }
            if (cb) cb(false);
        };
        var scheduled = targetSize ? clip.grabToImage(handle, targetSize) : clip.grabToImage(handle);
        if (!scheduled) {
            if (n < clip.retries) clip.schedule(path, cb, targetSize, n + 1);
            else if (cb) cb(false);
        }
    }

    function schedule(path, cb, targetSize, n) {
        retry.fn = function () { clip.attempt(path, cb, targetSize, n); };
        retry.restart();
    }

    Timer {
        id: retry
        interval: 60
        property var fn: null
        onTriggered: { var f = retry.fn; retry.fn = null; if (f) f(); }
    }
}
