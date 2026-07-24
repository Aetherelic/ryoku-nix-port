import QtQuick
import Ryoku.Ui
import Ryoku.Ui.Singletons as Ui
import "Singletons"

Item {
    id: root

    property real s: 1
    property bool open: false
    property bool animationsEnabled: true
    property bool snapping: false
    property bool frostActive: false
    property real maxHeight: 640
    property var results: []
    property var selectedResult: null
    property string selectedResultKey: ""
    property bool shelfOpen: false
    property var secondaryActions: []
    property var packedLayout: []
    property string focusedActionId: ""
    property bool helpMode: false
    property bool askMode: false
    property bool answerMode: false
    property bool actionBrowse: false
    property bool searching: false
    property string emptyText: "NO MATCHES"
    property string errorText: ""
    property string askQuestion: ""
    property var answer: ({ available: false })

    signal leadActivated()
    signal resultSelected(string resultKey, int rank)
    signal actionFocusRequested(string actionId)
    signal actionExecuteRequested(string actionId)
    signal askFinished()

    readonly property real pad: 10 * s
    readonly property bool hasResults: selectedResult !== null && results.length > 0
    readonly property real progressHeight: searching && hasResults ? 18 * s : 0
    readonly property real prefixHeight: actionBrowse || answerMode
        ? prefixStack.implicitHeight + 8 * s : 0
    readonly property real resultBodyHeight: hasResults
        ? progressHeight + 70 * s + actionShelf.targetHeight
            + ledger.desiredHeight
        : 52 * s
    readonly property real standardDesiredHeight: pad * 2 + prefixHeight + resultBodyHeight
    readonly property real rawDesiredHeight: helpMode
        ? pad * 2 + helpPanel.implicitHeight
        : (askMode ? pad * 2 + askPanel.implicitHeight : standardDesiredHeight)
    readonly property real desiredHeight: open
        ? Math.min(Math.max(0, maxHeight), rawDesiredHeight) : 0
    readonly property string activeCategory: tabs.activeCategory
    readonly property bool askBusy: askPanel.busy
    readonly property bool askResumeMode: askPanel.resumeMode
    readonly property bool askAnswerCurrent: askPanel.answerCurrent
    readonly property bool askPermissionPending: askPanel.permPending
    readonly property int askChipCount: askPanel.chips.length
    readonly property string actionVisibleRange: actionShelf.visibleRange
    readonly property real actionShelfHeight: actionShelf.height

    implicitHeight: desiredHeight
    height: desiredHeight
    opacity: open ? 1 : 0
    visible: height > 0.1 || opacity > 0.01
    clip: true

    Behavior on height {
        enabled: root.animationsEnabled && !root.snapping
        NumberAnimation {
            id: heightMotion
            duration: Motion.drawer
            easing.type: Easing.OutCubic
        }
    }
    Behavior on opacity {
        enabled: root.animationsEnabled && !root.snapping
        NumberAnimation {
            id: opacityMotion
            duration: Motion.drawer
            easing.type: Easing.OutCubic
        }
    }

    function snapAnimations() {
        snapping = true;
        height = Qt.binding(function () { return root.desiredHeight; });
        opacity = Qt.binding(function () { return root.open ? 1 : 0; });
        actionShelf.snapAnimations();
        snapping = false;
    }

    onAnimationsEnabledChanged: {
        if (!animationsEnabled)
            snapAnimations();
    }

    function resetCategory() {
        tabs.activeIndex = 0;
    }

    function cycleCategory(delta) {
        tabs.cycle(delta);
    }

    function resetAsk() {
        askPanel.reset();
    }

    function runAsk() {
        askPanel.run();
    }

    function moveAsk(delta) {
        askPanel.move(delta);
    }

    function activateAsk() {
        askPanel.activate();
    }

    function cancelAsk() {
        askPanel.cancel();
    }

    function revealRank(rank) {
        ledger.revealRank(rank);
    }

    Rectangle {
        anchors.fill: parent
        color: root.frostActive
            ? Qt.rgba(Theme.drawer.r, Theme.drawer.g, Theme.drawer.b, 0.94)
            : Theme.drawer
    }

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: 1
        color: Theme.frame
        z: 20
    }

    Item {
        id: content
        anchors.fill: parent
        anchors.margins: root.pad

        Column {
            id: prefixStack
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            spacing: 8 * root.s

            CategoryTabs {
                id: tabs
                width: prefixStack.width
                height: visible ? implicitHeight : 0
                visible: root.actionBrowse && !root.helpMode && !root.askMode
                s: root.s
            }

            AnswerPanel {
                width: prefixStack.width
                height: visible ? implicitHeight : 0
                visible: root.answerMode && !root.helpMode && !root.askMode
                s: root.s
                answer: root.answer
            }
        }

        Flickable {
            id: helpViewport
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            visible: root.helpMode
            clip: true
            contentWidth: width
            contentHeight: helpPanel.implicitHeight
            boundsBehavior: Flickable.StopAtBounds
            interactive: contentHeight > height

            HelpPanel {
                id: helpPanel
                width: helpViewport.width
                s: root.s
            }
        }

        Flickable {
            id: askViewport
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            visible: root.askMode
            clip: true
            contentWidth: width
            contentHeight: askPanel.implicitHeight
            boundsBehavior: Flickable.StopAtBounds
            interactive: contentHeight > height

            AskPanel {
                id: askPanel
                width: askViewport.width
                s: root.s
                question: root.askQuestion
                onFinished: root.askFinished()
            }
        }

        Item {
            id: standardBody
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: prefixStack.bottom
            anchors.topMargin: prefixStack.height > 0 ? 8 * root.s : 0
            anchors.bottom: parent.bottom
            visible: !root.helpMode && !root.askMode

            Item {
                id: progress
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                height: root.progressHeight
                visible: height > 0

                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 5 * root.s

                    Spinner {
                        anchors.verticalCenter: parent.verticalCenter
                        size: 10 * root.s
                        thickness: Math.max(1, root.s)
                        color: Theme.providerOther
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "UPDATING"
                        color: Theme.faint
                        font.family: Theme.mono
                        font.pixelSize: 7.5 * root.s
                        font.weight: Font.DemiBold
                        font.letterSpacing: 0.8 * root.s
                    }
                }
            }

            LeadResult {
                id: lead
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: progress.bottom
                height: root.hasResults ? 70 * root.s : 0
                visible: root.hasResults
                s: root.s
                entry: root.selectedResult
                errorText: root.errorText
                onActivated: root.leadActivated()
            }

            ActionShelf {
                id: actionShelf
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: lead.bottom
                s: root.s
                open: root.shelfOpen && root.hasResults
                animationsEnabled: root.animationsEnabled
                actions: root.secondaryActions
                packedLayout: root.packedLayout
                focusedActionId: root.focusedActionId
                onFocusRequested: actionId => root.actionFocusRequested(actionId)
                onExecuteRequested: actionId => root.actionExecuteRequested(actionId)
            }

            ResultLedger {
                id: ledger
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: actionShelf.bottom
                height: root.hasResults
                    ? Math.max(0, Math.min(desiredHeight,
                        standardBody.height - progress.height
                            - lead.height - actionShelf.height))
                    : 0
                visible: root.hasResults && height > 0
                s: root.s
                results: root.results
                selectedResultKey: root.selectedResultKey
                onResultSelected: (resultKey, rank) => root.resultSelected(resultKey, rank)
            }

            Row {
                anchors.centerIn: parent
                spacing: 8 * root.s
                visible: !root.hasResults

                Spinner {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.searching
                    size: 14 * root.s
                    color: Theme.providerOther
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.searching ? "SEARCHING" : root.emptyText
                    color: Theme.faint
                    font.family: Theme.mono
                    font.pixelSize: 9 * root.s
                    font.weight: Font.DemiBold
                    font.letterSpacing: 1.1 * root.s
                }
            }
        }
    }
}
