pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import Ryoku.Ui
import Ryoku.Ui.Singletons
import "Singletons"

// The browse collection: a scrollable wall of thumbnails bound to
// Wallhaven.results. Picking a cell selects it for the preview; the empty and
// loading states carry the torii mark and one sentence, per the skeleton.
Item {
    id: g

    readonly property int gap: Tokens.s2
    readonly property int cols: Math.max(2, Math.floor(width / 200))

    // MoeWalls serves only its low-res preview loops, so the browse view says so.
    readonly property bool showMoeNote: Wallhaven.source === "moewalls"
    readonly property bool showLoadMore:
        Wallhaven.pagedSource && Wallhaven.results.length > 0

    GridView {
        id: grid
        anchors.fill: parent
        anchors.topMargin: g.showMoeNote ? moeNote.height + Tokens.s2 : 0
        anchors.bottomMargin:
            g.showLoadMore ? loadMoreBar.height + Tokens.s2 : 0
        visible: Wallhaven.results.length > 0
        clip: true
        cellWidth: Math.floor(g.width / g.cols)
        cellHeight: Math.round(cellWidth * 0.62)
        model: Wallhaven.results
        cacheBuffer: 1200
        boundsBehavior: Flickable.StopAtBounds
        opacity: Wallhaven.searching ? 0.45 : 1
        Behavior on opacity { NumberAnimation { duration: Tokens.snap } }

        ScrollBar.vertical: ScrollRail {}

        delegate: Item {
            required property var modelData
            width: grid.cellWidth
            height: grid.cellHeight

            WallCell {
                anchors.fill: parent
                anchors.margins: g.gap / 2
                item: parent.modelData
                active: Wallhaven.selected && Wallhaven.selected.id === parent.modelData.id
                onPicked: Wallhaven.select(parent.modelData)
                onOpened: Wallhaven.openWeb(parent.modelData)
                selectable: Wallhaven.source === "local"
                selected: Wallhaven.localSelection.indexOf(parent.modelData.id) >= 0
                onToggledSelect: Wallhaven.toggleLocalSelect(parent.modelData)
            }
        }
    }

    // Remote catalogues are much larger than one page. Keep the compact page
    // controls above for direct navigation, while LOAD MORE grows the current
    // collection in place for normal browsing.
    Item {
        id: loadMoreBar

        visible: g.showLoadMore

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom

        height: visible ? 38 : 0

        Row {
            anchors.centerIn: parent
            spacing: Tokens.s3

            Text {
                anchors.verticalCenter: parent.verticalCenter

                text:
                    Wallhaven.results.length
                    + " LOADED · PAGE "
                    + Wallhaven.page

                color: Tokens.inkFaint
                font.family: Tokens.mono
                font.pixelSize: 9
            }

            Btn {
                anchors.verticalCenter: parent.verticalCenter
                compact: true

                text:
                    Wallhaven.loadingMore
                        ? I18n.tr("LOADING…")
                        : (Wallhaven.hasMore
                            ? I18n.tr("LOAD MORE")
                            : I18n.tr("END"))

                armed:
                    Wallhaven.hasMore
                    && !Wallhaven.searching

                onAct: Wallhaven.loadMore()
            }
        }
    }

    // empty / loading / error state: a vertical specimen poster, the state woven
    // into its title and caption, so a dead grid still has a face (like the hub's
    // dead-slot placards) instead of a lone mark.
    Placard {
        anchors.fill: parent
        visible: Wallhaven.results.length === 0
        opacity: Wallhaven.searching ? 0.75 : 1
        Behavior on opacity { NumberAnimation { duration: Tokens.snap } }
        code: "WALL-02"
        title: Wallhaven.searching ? "検索" : (Wallhaven.error.length > 0 ? "圏外" : "無")
        sub: Wallhaven.searching ? I18n.tr("SEARCHING") : (Wallhaven.error.length > 0 ? I18n.tr("NO SIGNAL") : I18n.tr("NO WALLPAPERS"))
        quote: Wallhaven.searching ? I18n.tr("Fetching the latest wallpapers.")
            : (Wallhaven.error.length > 0 ? Wallhaven.error
            : (Wallhaven.source === "live" ? I18n.tr("No live wallpapers yet - add an MP4 to begin.")
            : I18n.tr("Nothing here yet. Search above, or switch the source.")))
        tate: "壁を探す"
        seal: "壁"
        art: "aurelius.png"
        seed: 3
    }

    // MoeWalls only serves its ~720p preview loops (soft on a large screen), and
    // the exact size varies per clip, so instead of a per-tile number (a hardcoded
    // one made Enhance read as broken) the source carries one honest note, in the
    // house emphasis grammar - a bone plate, black ink, no red - pointing at the
    // Enhance that upscales the pick.
    Rectangle {
        id: moeNote
        visible: g.showMoeNote
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: visible ? moeText.implicitHeight + Tokens.s3 * 2 : 0
        radius: Tokens.radius
        color: Tokens.bone
        Text {
            id: moeText
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: Tokens.s3
            anchors.rightMargin: Tokens.s3
            anchors.verticalCenter: parent.verticalCenter
            wrapMode: Text.WordWrap
            text: I18n.tr("MoeWalls shows ~720p preview loops - soft on a large screen. Pick one and use Enhance (GRADE tab) to upscale it on the GPU.")
            color: Tokens.inkOnBone
            font.family: Tokens.ui
            font.pixelSize: 11
        }
    }
}
