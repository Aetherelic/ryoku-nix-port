import QtQuick
import Ryoku.Ui
import Ryoku.Ui.Singletons
import "lib/store.js" as StoreLogic

FocusScope {
    id: detail

    property var item: null
    property bool open: false
    property rect originRect: Qt.rect(0, 0, 0, 0)
    property string busyKey: ""
    property string installStage: ""
    property string installErrorKey: ""
    property string installError: ""
    property bool reducedMotion: false
    property real transitionProgress: open ? 1 : 0

    function focusInitialAction() {
        closeButton.forceActiveFocus(Qt.OtherFocusReason);
    }

    signal closeRequested()
    signal installRequested(var item)
    signal retryRequested(var item)
    signal settingsRequested(var item)

    readonly property var actionItem: item || ({})
    readonly property string actionKey: StoreLogic.itemKey(actionItem)
    readonly property var screenshots: Array.isArray(actionItem.screenshots) ? actionItem.screenshots : []
    readonly property int screenshotCount: screenshots.length
    readonly property var tags: Array.isArray(actionItem.tags) ? actionItem.tags : []
    readonly property color accentColor: actionItem.accent ? Qt.color(actionItem.accent) : Tokens.sun
    readonly property string errorText: installErrorKey === actionKey ? installError : ""
    readonly property string transitionMode: reducedMotion ? "immediate" : "shared"
    readonly property string metadataText: [
        actionItem.author ? "AUTHOR / " + actionItem.author : "",
        actionItem.version ? "VERSION / " + actionItem.version : "",
        actionItem.size ? "SIZE / " + actionItem.size : "",
        actionItem.compatibility ? "COMPATIBILITY / " + valueText(actionItem.compatibility) : "",
        actionItem.contents ? "CONTENTS / " + valueText(actionItem.contents) : ""
    ].filter(Boolean).join("\n")
    readonly property real targetX: Tokens.s6
    readonly property real targetY: Tokens.s6
    readonly property real targetWidth: Math.min(430, width * 0.42)
    readonly property real targetHeight: Math.max(1, height - Tokens.s6 * 2)
    readonly property rect effectiveOrigin: originRect.width > 0 && originRect.height > 0
            ? originRect
            : Qt.rect(targetX, targetY, targetWidth, targetHeight)

    visible: open || transitionProgress > 0
    focus: open
    clip: true

    function valueText(value) {
        return Array.isArray(value) ? value.join(", ") : String(value || "");
    }

    function mix(from, to) {
        return from + (to - from) * transitionProgress;
    }

    function triggerClose() {
        closeRequested();
    }

    function triggerInstall() {
        if (item && busyKey === "" && StoreLogic.primaryAction(actionItem) !== "INSTALLED")
            installRequested(actionItem);
    }

    function triggerRetry() {
        if (item && busyKey === "" && errorText !== "")
            retryRequested(actionItem);
    }

    function triggerSettings() {
        if (item && StoreLogic.secondaryAction(actionItem) !== "")
            settingsRequested(actionItem);
    }

    Behavior on transitionProgress {
        enabled: !detail.reducedMotion
        NumberAnimation { duration: Tokens.swap; easing.type: Tokens.ease }
    }

    Rectangle {
        anchors.fill: parent
        color: detail.actionItem.surface || Tokens.paper
        opacity: detail.transitionProgress
    }

    ProductCover {
        id: cover
        objectName: "ryostore-detail-cover"
        x: detail.mix(detail.effectiveOrigin.x, detail.targetX)
        y: detail.mix(detail.effectiveOrigin.y, detail.targetY)
        width: detail.mix(detail.effectiveOrigin.width, detail.targetWidth)
        height: detail.mix(detail.effectiveOrigin.height, detail.targetHeight)
        item: detail.actionItem
        mode: "plate"
    }

    Column {
        id: dossier
        objectName: "ryostore-detail-dossier"
        x: detail.targetX + detail.targetWidth + Tokens.s6
        y: Tokens.s6
        width: Math.max(1, detail.width - x - Tokens.s6)
        spacing: Tokens.s3
        opacity: detail.transitionProgress

        Text {
            width: parent.width
            text: String(detail.actionItem.categoryName || detail.actionItem.category || "").toUpperCase()
            color: Tokens.inkDim
            font.family: Tokens.mono
            font.pixelSize: Tokens.fMicro
            font.letterSpacing: Tokens.trackMark
            elide: Text.ElideRight
        }

        Text {
            objectName: "ryostore-detail-title"
            width: parent.width
            text: String(detail.actionItem.name || detail.actionItem.id || "")
            color: Tokens.ink
            font.family: Tokens.display
            font.pixelSize: Tokens.fTitle
            font.weight: Font.Medium
            wrapMode: Text.Wrap
            maximumLineCount: 2
            elide: Text.ElideRight
        }

        Text {
            objectName: "ryostore-detail-description"
            width: parent.width
            text: String(detail.actionItem.description || detail.actionItem.summary || "")
            visible: text !== ""
            color: Tokens.inkDim
            font.family: Tokens.ui
            font.pixelSize: Tokens.fBody
            wrapMode: Text.Wrap
            maximumLineCount: 4
            elide: Text.ElideRight
        }

        Flow {
            objectName: "ryostore-detail-tags"
            width: parent.width
            spacing: Tokens.s2
            visible: detail.tags.length > 0

            Repeater {
                model: detail.tags

                delegate: Rectangle {
                    required property string modelData
                    width: tagLabel.implicitWidth + Tokens.s3 * 2
                    height: tagLabel.implicitHeight + Tokens.s2
                    radius: Tokens.radius
                    color: Qt.rgba(detail.accentColor.r, detail.accentColor.g, detail.accentColor.b, 0.12)
                    border.width: Tokens.border
                    border.color: Qt.rgba(detail.accentColor.r, detail.accentColor.g, detail.accentColor.b, 0.4)

                    Text {
                        id: tagLabel
                        anchors.centerIn: parent
                        text: parent.modelData.toUpperCase()
                        color: Tokens.ink
                        font.family: Tokens.mono
                        font.pixelSize: Tokens.fMicro
                        font.letterSpacing: Tokens.trackLabel
                    }
                }
            }
        }

        Text {
            objectName: "ryostore-detail-metadata"
            width: parent.width
            text: detail.metadataText
            visible: text !== ""
            color: Tokens.inkDim
            font.family: Tokens.mono
            font.pixelSize: Tokens.fMicro
            font.letterSpacing: Tokens.trackLabel
            wrapMode: Text.Wrap
        }

        StatusReadout {
            objectName: "ryostore-detail-status"
            item: detail.actionItem
            busyKey: detail.busyKey
            installStage: detail.installStage
            installErrorKey: detail.installErrorKey
            installError: detail.installError
        }

        Text {
            objectName: "ryostore-detail-error"
            width: parent.width
            text: detail.errorText
            visible: text !== ""
            color: Tokens.alert
            font.family: Tokens.ui
            font.pixelSize: Tokens.fSmall
            wrapMode: Text.Wrap
            textFormat: Text.PlainText
        }

        Row {
            spacing: Tokens.s2

            Btn {
                objectName: "ryostore-detail-install"
                text: detail.busyKey === detail.actionKey && detail.installStage !== ""
                        ? detail.installStage
                        : StoreLogic.primaryAction(detail.actionItem)
                primary: true
                armed: detail.item !== null && detail.busyKey === ""
                        && StoreLogic.primaryAction(detail.actionItem) !== "INSTALLED"
                Accessible.role: Accessible.Button
                Accessible.name: text
                onAct: detail.triggerInstall()
                Accessible.onPressAction: detail.triggerInstall()
            }

            Btn {
                objectName: "ryostore-detail-retry"
                text: "RETRY"
                visible: detail.errorText !== ""
                armed: visible && detail.busyKey === ""
                Accessible.role: Accessible.Button
                Accessible.name: text
                onAct: detail.triggerRetry()
                Accessible.onPressAction: detail.triggerRetry()
            }

            Btn {
                objectName: "ryostore-detail-settings"
                text: "OPEN IN SETTINGS"
                visible: StoreLogic.secondaryAction(detail.actionItem) !== ""
                armed: visible
                Accessible.role: Accessible.Button
                Accessible.name: text
                onAct: detail.triggerSettings()
                Accessible.onPressAction: detail.triggerSettings()
            }

            Btn {
                id: closeButton
                objectName: "ryostore-detail-close"
                focus: detail.open
                text: "BACK"
                Accessible.role: Accessible.Button
                Accessible.name: text
                onAct: detail.triggerClose()
                Accessible.onPressAction: detail.triggerClose()
            }
        }

        Flickable {
            objectName: "ryostore-detail-screenshots"
            width: parent.width
            height: detail.screenshotCount > 0 ? 120 : 0
            visible: detail.screenshotCount > 0
            clip: true
            contentWidth: screenshotRow.width
            contentHeight: height
            flickableDirection: Flickable.HorizontalFlick
            boundsBehavior: Flickable.StopAtBounds

            Row {
                id: screenshotRow
                height: parent.height
                spacing: Tokens.s2

                Repeater {
                    model: detail.screenshots

                    delegate: Item {
                        required property var modelData
                        required property int index
                        width: 204
                        height: screenshotRow.height
                        Accessible.role: Accessible.Graphic
                        Accessible.name: "Screenshot " + String(index + 1) + " of " + detail.screenshotCount

                        ProductMedia {
                            anchors.fill: parent
                            source: parent.modelData
                            mode: "cover"
                            active: detail.open
                        }

                        Rectangle {
                            anchors.fill: parent
                            color: "transparent"
                            border.width: Tokens.border
                            border.color: "#28ffffff"
                        }
                    }
                }
            }
        }
    }
}
