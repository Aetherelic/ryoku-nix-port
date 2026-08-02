import QtQuick
import Ryoku.Ui
import Ryoku.Ui.Singletons
import "lib/store.js" as StoreLogic

Item {
    id: stage

    property var item: null
    property var previewItem: null
    property string busyKey: ""
    property string installStage: ""
    property string installErrorKey: ""
    property string installError: ""
    property string positionText: ""
    property bool offline: false
    property bool reducedMotion: false
    property real artworkReveal: 1

    signal installRequested(var item)
    signal detailsRequested(var item)
    signal settingsRequested(var item)

    readonly property var displayItem: previewItem || item || ({})
    readonly property var actionItem: item || ({})
    readonly property int motionDuration: reducedMotion ? 0 : Tokens.swap
    readonly property string actionKey: StoreLogic.itemKey(actionItem)
    readonly property string primaryLabel: busyKey === actionKey && installStage !== ""
            ? installStage
            : StoreLogic.primaryAction(actionItem)
    readonly property string secondaryLabel: StoreLogic.secondaryAction(actionItem)
    readonly property bool hasActionItem: item !== null && item !== undefined
    readonly property var coverItem: ({
        id: displayItem.id,
        name: displayItem.name || displayItem.id,
        art: displayItem.art || "",
        category: actionItem.category,
        categoryName: actionItem.categoryName,
        accent: actionItem.accent,
        surface: actionItem.surface,
        installed: actionItem.installed,
        active: actionItem.active,
        enabled: actionItem.enabled,
        installedCount: actionItem.installedCount,
        totalCount: actionItem.totalCount,
        updateAvailable: actionItem.updateAvailable
    })

    clip: true

    function triggerInstall() {
        if (hasActionItem && StoreLogic.primaryAction(actionItem) !== "INSTALLED" && busyKey === "")
            installRequested(actionItem);
    }

    function triggerDetails() {
        if (hasActionItem)
            detailsRequested(actionItem);
    }

    function triggerSettings() {
        if (hasActionItem && secondaryLabel !== "")
            settingsRequested(actionItem);
    }

    function revealArtwork() {
        if (reducedMotion) {
            artworkReveal = 1;
            return;
        }
        artworkReveal = 0;
        Qt.callLater(function() { stage.artworkReveal = 1; });
    }

    onDisplayItemChanged: revealArtwork()
    onReducedMotionChanged: {
        if (reducedMotion)
            artworkReveal = 1;
    }

    ProductCover {
        id: artwork
        objectName: "ryostore-stage-artwork"
        anchors.fill: parent
        item: stage.coverItem
        stage: true
        opacity: 0.45 + stage.artworkReveal * 0.55
        scale: 0.985 + stage.artworkReveal * 0.015

        Behavior on opacity {
            enabled: !stage.reducedMotion
            NumberAnimation { duration: stage.motionDuration; easing.type: Tokens.ease }
        }
        Behavior on scale {
            enabled: !stage.reducedMotion
            NumberAnimation { duration: stage.motionDuration; easing.type: Tokens.ease }
        }
    }

    Rectangle {
        objectName: "ryostore-stage-scrim"
        anchors { top: parent.top; bottom: parent.bottom; left: parent.left }
        width: Math.min(stage.width * 0.58, 600)
        color: Tokens.paper
        opacity: 0.9
    }

    Text {
        objectName: "ryostore-stage-position"
        anchors { top: parent.top; right: parent.right; margins: Tokens.s5 }
        text: stage.positionText
        visible: text !== ""
        color: Tokens.ink
        font.family: Tokens.mono
        font.pixelSize: Tokens.fMicro
        font.letterSpacing: Tokens.trackLabel
    }

    Column {
        id: story
        anchors { left: parent.left; bottom: parent.bottom; margins: Tokens.s6 }
        width: Math.min(stage.width * 0.48, 520)
        spacing: Tokens.s3
        visible: stage.hasActionItem

        Text {
            width: parent.width
            text: String(stage.actionItem && (stage.actionItem.categoryName || stage.actionItem.category) || "").toUpperCase()
            color: Tokens.inkDim
            font.family: Tokens.mono
            font.pixelSize: Tokens.fMicro
            font.letterSpacing: Tokens.trackMark
            elide: Text.ElideRight
        }

        Text {
            objectName: "ryostore-stage-title"
            width: parent.width
            text: String(stage.displayItem && (stage.displayItem.name || stage.displayItem.id) || "")
            color: Tokens.ink
            font.family: Tokens.display
            font.pixelSize: Tokens.fHero
            font.weight: Font.Medium
            wrapMode: Text.Wrap
            maximumLineCount: 2
            elide: Text.ElideRight
        }

        Text {
            width: parent.width
            text: String(stage.actionItem && (stage.actionItem.summary || stage.actionItem.description) || "")
            visible: text !== ""
            color: Tokens.inkDim
            font.family: Tokens.ui
            font.pixelSize: Tokens.fBody
            wrapMode: Text.Wrap
            maximumLineCount: 4
            elide: Text.ElideRight
        }

        StatusReadout {
            objectName: "ryostore-stage-status"
            item: stage.actionItem
            busyKey: stage.busyKey
            installStage: stage.installStage
            installErrorKey: stage.installErrorKey
            installError: stage.installError
            offline: stage.offline
        }

        Row {
            spacing: Tokens.s2

            Btn {
                objectName: "ryostore-stage-primary"
                text: stage.primaryLabel
                primary: true
                armed: stage.hasActionItem
                        && StoreLogic.primaryAction(stage.actionItem) !== "INSTALLED"
                        && stage.busyKey === ""
                Accessible.role: Accessible.Button
                Accessible.name: text
                onAct: stage.triggerInstall()
                Accessible.onPressAction: stage.triggerInstall()
            }

            Btn {
                objectName: "ryostore-stage-details"
                text: "VIEW DETAILS"
                armed: stage.hasActionItem
                Accessible.role: Accessible.Button
                Accessible.name: text
                onAct: stage.triggerDetails()
                Accessible.onPressAction: stage.triggerDetails()
            }

            Btn {
                objectName: "ryostore-stage-settings"
                text: stage.secondaryLabel
                visible: text !== ""
                armed: visible && stage.hasActionItem
                Accessible.role: Accessible.Button
                Accessible.name: text
                onAct: stage.triggerSettings()
                Accessible.onPressAction: stage.triggerSettings()
            }
        }
    }
}
