import QtQuick
import Ryoku.Ui
import Ryoku.Ui.Singletons as Ui
import "Singletons"

GridView {
    id: root

    property real s: 1
    property var results: []
    property string selectedResultKey: ""

    signal resultSelected(string resultKey, int rank)

    readonly property var rows: {
        var output = [];
        for (var index = 0; index < results.length; index++) {
            var entry = results[index];
            if (!entry || entry.resultKey === selectedResultKey)
                continue;
            output.push({ entry: entry, rank: index + 1 });
        }
        return output;
    }
    readonly property int ledgerRowCount: Math.ceil(rows.length / 2)
    readonly property real desiredHeight: Math.min(4, ledgerRowCount) * 44 * s

    model: rows.length
    cellWidth: width / 2
    cellHeight: 44 * s
    clip: true
    reuseItems: true
    boundsBehavior: Flickable.StopAtBounds
    flickDeceleration: 2600

    function revealRank(rank) {
        if (rows.length === 0)
            return;
        var filtered = rows.length - 1;
        for (var index = 0; index < rows.length; index++) {
            if (rows[index].rank - 1 >= rank) {
                filtered = index;
                break;
            }
        }
        positionViewAtIndex(Math.max(0, filtered), GridView.Contain);
    }

    delegate: Item {
        id: cell

        required property int index
        readonly property var rowData: root.rows[index]
        readonly property var entry: rowData ? rowData.entry : null
        readonly property bool hasIcon: entry && String(entry.icon || "").length > 0

        objectName: "result-" + (entry ? String(entry.resultKey || "") : "")
        width: root.cellWidth
        height: root.cellHeight

        Accessible.role: Accessible.ListItem
        Accessible.name: entry ? String(entry.title || "") : ""
        Accessible.description: entry
            ? "Rank " + String(rowData.rank) + ", "
                + String(entry.type || entry.providerId || "")
            : ""
        Accessible.ignored: entry === null
        Accessible.focusable: false
        Accessible.selectable: entry !== null
        Accessible.selected: entry !== null
            && entry.resultKey === root.selectedResultKey
        Accessible.onPressAction: cell.selectResult()

        function selectResult() {
            if (entry)
                root.resultSelected(entry.resultKey, rowData.rank - 1);
        }

        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: 2 * root.s
            color: cell.entry
                ? Theme.providerRail(cell.entry.providerId, cell.entry.type)
                : Theme.providerOther
        }

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 1
            color: Theme.hair
        }

        Rectangle {
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            width: cell.index % 2 === 0 ? 1 : 0
            color: Theme.hair
        }

        Text {
            id: rank
            anchors.left: parent.left
            anchors.leftMargin: 9 * root.s
            anchors.verticalCenter: parent.verticalCenter
            width: 24 * root.s
            text: cell.rowData ? String(cell.rowData.rank).padStart(2, "0") : ""
            color: Theme.faint
            font.family: Theme.mono
            font.pixelSize: 8 * root.s
            font.features: ({ "tnum": 1 })
        }

        Image {
            id: icon
            anchors.left: rank.right
            anchors.verticalCenter: parent.verticalCenter
            width: cell.hasIcon ? 21 * root.s : 0
            height: 21 * root.s
            sourceSize.width: Math.round(42 * root.s)
            sourceSize.height: Math.round(42 * root.s)
            fillMode: Image.PreserveAspectFit
            asynchronous: true
            smooth: true
            visible: cell.hasIcon
            source: cell.hasIcon ? cell.entry.icon : ""
        }

        Column {
            anchors.left: icon.right
            anchors.leftMargin: cell.hasIcon ? 9 * root.s : 0
            anchors.right: parent.right
            anchors.rightMargin: 10 * root.s
            anchors.verticalCenter: parent.verticalCenter
            spacing: 0

            Text {
                width: parent.width
                text: cell.entry ? String(cell.entry.title || "") : ""
                color: cell.entry && cell.entry.disabled ? Theme.faint : Theme.cream
                font.family: Theme.font
                font.pixelSize: 11 * root.s
                font.weight: Font.Medium
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                text: cell.entry
                    ? String(cell.entry.type || cell.entry.providerId || "").toUpperCase()
                    : ""
                color: Theme.faint
                font.family: Theme.mono
                font.pixelSize: 7.5 * root.s
                font.letterSpacing: 0.7 * root.s
                elide: Text.ElideRight
            }
        }

        Rectangle {
            anchors.fill: parent
            color: pointer.containsMouse ? Theme.sheen : "transparent"
        }

        MouseArea {
            id: pointer
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor

            onClicked: cell.selectResult()
        }
    }
}
