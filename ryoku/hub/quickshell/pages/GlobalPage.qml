import QtQuick
import Quickshell.Io
import Ryoku.Ui
import Ryoku.Ui.Singletons
import ".."
import "../schema/GlobalPage.js" as GlobalSchema

// Global: the cross-cutting preferences that are not tied to one surface -- the
// interface language, the regional formats used for dates and numbers, the
// machine location, and the system font. Rendered through the shared SchemaPage;
// the ledger and action bar belong to the shell.
Item {
    id: pg
    property var hub

    readonly property string pTitle: I18n.tr("Global")
    readonly property string pEyebrow: I18n.tr("GLOBAL")
    readonly property string pBlurb: I18n.tr("System-wide preferences: interface language, regional formats, location, and the system font.")
    function focusKey(k) { sp.focusKey(k) }

    // Installed font families, read live so the System font drawer offers exactly
    // what this machine can render. Injected into the fontFamily row's options,
    // so the shared "pick" control shows the searchable font list.
    property var fontList: []
    readonly property var schema: {
        var out = [];
        for (var i = 0; i < GlobalSchema.rows.length; i++) {
            var r = GlobalSchema.rows[i];
            if (r.key === "fontFamily") {
                var c = {};
                for (var k in r)
                    c[k] = r[k];
                c.opts = pg.fontList;
                out.push(c);
            } else {
                out.push(r);
            }
        }
        return out;
    }

    Process {
        id: fonts
        command: ["bash", "-c", "fc-list : family | cut -d, -f1 | sort -u"]
        stdout: StdioCollector {
            id: fontsOut
            onStreamFinished: {
                var t = ("" + fontsOut.text).trim();
                pg.fontList = t.length > 0 ? t.split("\n").filter(function (x) { return x.length > 0; }) : [];
            }
        }
    }
    Component.onCompleted: fonts.running = true

    SchemaPage {
        id: sp
        anchors.fill: parent
        schema: pg.schema
        draft: pg.hub ? pg.hub.draft : null
        defaults: pg.hub ? pg.hub.committed : ({})
        advanced: pg.hub ? pg.hub.advanced : false
        title: pg.pTitle
        eyebrow: pg.pEyebrow
        blurb: pg.pBlurb
        query: pg.hub ? pg.hub.query : ""
        onEdited: (k, v) => { if (pg.hub) pg.hub.edit(k, v); }
        onPickRequested: (r) => { if (pg.hub) pg.hub.openPick(r); }
    }
}
