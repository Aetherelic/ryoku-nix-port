import QtQuick
import Ryoku.Ui
import Ryoku.Ui.Singletons
import ".."
import "../schema/GlobalPage.js" as GlobalSchema

// Global: the cross-cutting preferences that are not tied to one surface -- the
// interface language, the regional formats used for dates and numbers, the
// machine location, and the shell text size. Rendered through the shared
// SchemaPage; the ledger and action bar belong to the shell.
Item {
    id: pg
    property var hub

    readonly property string pTitle: I18n.tr("Global")
    readonly property string pEyebrow: I18n.tr("GLOBAL")
    readonly property string pBlurb: I18n.tr("System-wide preferences: interface language, regional formats, location, and text size.")
    function focusKey(k) { sp.focusKey(k) }

    SchemaPage {
        id: sp
        anchors.fill: parent
        schema: GlobalSchema.rows
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
