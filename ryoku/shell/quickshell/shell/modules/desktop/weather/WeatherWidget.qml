pragma ComponentBehavior: Bound
import QtQuick
import "../../../services/lib/weather.js" as Wx
import "../../../components"
import "../Singletons"
import shell.services as Svc
import Ryoku.Ui.Singletons

// Weather on the bare wallpaper: a condition glyph, the temperature at display
// weight and the city, in `compact`; `full` adds the condition word, a
// humidity/wind/feels chip row and a three-day strip off Weather.daily. It sits
// on no card (the slot's bg is none), so legibility is ink chosen against the
// wallpaper tone under the slot, never a panel. The daemon owns the fetch; this
// only reads the shared Weather singleton, and gates the derived daily slice on
// `active` so a hidden widget costs nothing.
Item {
    id: root

    // pushed by WidgetSlot: the wallpaper L* under this slot, so ink is picked
    // against the picture rather than a surface that is not there.
    property real underL: Scheme.wallLstar
    property real s: 1
    property bool active: true
    property string design: "compact"   // compact | full

    // Theme is the desktop module's one door to the ink helpers, the way every
    // clock face reaches them.
    readonly property color ink:    Theme.inkOn(root.underL)
    readonly property color inkDim: Theme.inkDimOn(root.underL)
    readonly property color accent: Theme.accentOn(root.underL)

    readonly property bool full: root.design === "full"
    readonly property bool ready: Svc.Weather.available

    // clear at night reads as the moon, everything else keeps its day glyph.
    readonly property string headGlyph: {
        const g = Svc.Weather.glyph;
        return (!Svc.Weather.isDay && g === "sun") ? "moon" : g;
    }

    // The daemon formats the wind for display and names its own unit, but its
    // suffix reads as a sentence ("7 mph winds"); under a chip already labelled
    // WIND the trailing word is noise, so only the unit itself is kept.
    readonly property string windText: {
        const c = Svc.Weather.current;
        if (!c)
            return "";
        const v = (c.wind !== undefined) ? String(c.wind) : String(Svc.Weather.wind);
        const u = (c.windUnits !== undefined) ? String(c.windUnits).replace("winds", "").trim() : "";
        return u.length > 0 ? v + " " + u : v;
    }

    // the three-day strip: the first three of Weather.daily, and nothing while
    // hidden or in compact so a covered widget binds no forecast work.
    readonly property var days3: (root.active && root.full && root.ready)
        ? Svc.Weather.daily.slice(0, 3) : []

    // honest wording for the unavailable state: the daemon's own error line, or a
    // plain loading note while the first frame is in flight.
    readonly property string statusText: {
        if (Svc.Weather.status === "loading")
            return I18n.tr("Loading weather…");
        if (Svc.Weather.errorText.length > 0)
            return Svc.Weather.errorText;
        return I18n.tr("Weather unavailable");
    }

    implicitWidth:  root.ready ? main.implicitWidth  : fallback.implicitWidth
    implicitHeight: root.ready ? main.implicitHeight : fallback.implicitHeight

    // one labelled metric for the full chip row.
    component Metric: Column {
        id: metric
        property string label: ""
        property string value: ""
        spacing: 1 * root.s
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: metric.label
            color: root.inkDim
            font.family: Theme.font
            font.pixelSize: 11 * root.s
            font.weight: Font.Medium
            font.letterSpacing: 1 * root.s
            font.capitalization: Font.AllUppercase
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: metric.value
            color: root.ink
            font.family: Theme.font
            font.pixelSize: 18 * root.s
            font.weight: Font.DemiBold
        }
    }

    Column {
        id: main
        visible: root.ready
        spacing: 6 * root.s

        GlyphIcon {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 76 * root.s
            height: width
            name: root.headGlyph
            color: root.accent
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Svc.Weather.temp
            color: root.ink
            font.family: Theme.display
            font.pixelSize: 66 * root.s
            font.weight: Font.DemiBold
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Svc.Weather.city
            color: root.inkDim
            font.family: Theme.font
            font.pixelSize: 20 * root.s
            font.weight: Font.Medium
        }

        Column {
            id: extras
            anchors.horizontalCenter: parent.horizontalCenter
            visible: root.full
            spacing: 14 * root.s

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Svc.Weather.condition
                color: root.ink
                font.family: Theme.font
                font.pixelSize: 24 * root.s
                font.weight: Font.Medium
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 22 * root.s
                Metric { label: I18n.tr("Humidity"); value: Svc.Weather.humidity + "%" }
                Metric { label: I18n.tr("Wind"); value: root.windText }
                Metric { label: I18n.tr("Feels"); value: Svc.Weather.feels + "\u00b0" }
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 20 * root.s
                Repeater {
                    model: root.days3
                    delegate: Column {
                        id: day
                        required property var modelData
                        spacing: 4 * root.s
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: day.modelData.day
                            color: root.inkDim
                            font.family: Theme.font
                            font.pixelSize: 13 * root.s
                            font.weight: Font.Medium
                        }
                        GlyphIcon {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 26 * root.s
                            height: width
                            name: Wx.glyphFor(day.modelData.code)
                            color: root.ink
                        }
                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: 5 * root.s
                            Text {
                                text: day.modelData.hi + "\u00b0"
                                color: root.ink
                                font.family: Theme.font
                                font.pixelSize: 14 * root.s
                                font.weight: Font.DemiBold
                            }
                            Text {
                                text: day.modelData.lo + "\u00b0"
                                color: root.inkDim
                                font.family: Theme.font
                                font.pixelSize: 14 * root.s
                                font.weight: Font.Medium
                            }
                        }
                    }
                }
            }
        }
    }

    // unavailable: a neutral glyph and the service's own status line, tap to
    // re-kick the daemon's poll. Nothing here implies a reading exists.
    Column {
        id: fallback
        visible: !root.ready
        spacing: 8 * root.s

        GlyphIcon {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 40 * root.s
            height: width
            name: "cloud"
            color: root.inkDim
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.min(implicitWidth, 220 * root.s)
            text: root.statusText
            color: root.inkDim
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            font.family: Theme.font
            font.pixelSize: 15 * root.s
            font.weight: Font.Medium
        }
        TapHandler { onTapped: Svc.Weather.retry() }
    }
}
