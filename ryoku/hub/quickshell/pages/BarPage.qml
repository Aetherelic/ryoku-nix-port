import QtQuick
import Ryoku.Ui
import Ryoku.Ui.Singletons
import ".."
import "../schema/BarPage.js" as BarSchema

// Atoll bar and preserved sidebar content, rendered through the shared
// SchemaPage. Opening controls stay absent until the sidebars are redesigned.
Item {
    id: pg
    property var hub

    readonly property string pTitle: I18n.tr("Bar")
    readonly property string pEyebrow: I18n.tr("DESKTOP")
    readonly property string pBlurb: I18n.tr("Atoll's floating islands and the preserved content of both sidebars.")

    SchemaPage {
        anchors.fill: parent
        schema: BarSchema.rows
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
