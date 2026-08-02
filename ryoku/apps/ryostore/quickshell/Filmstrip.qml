import QtQuick
import Ryoku.Ui.Singletons
import "lib/store.js" as StoreLogic

FocusScope {
    id: strip

    property var items: []
    property string selectedKey: ""
    property bool reducedMotion: false
    property string pendingKey: selectedKey
    property bool wheelDirty: false
    property bool restoringOffset: false

    signal previewRequested(var item)
    signal selectionRequested(var item)

    readonly property real contentOffset: flick.contentX
    readonly property real cardWidth: Math.max(210, Math.min(330, width * 0.29))
    readonly property real step: cardWidth + Tokens.s3
    readonly property bool focusVisible: activeFocus
    readonly property bool kineticEnabled: !reducedMotion

    activeFocusOnTab: true

    function restoreOffset(offset) {
        const maximum = Math.max(0, flick.contentWidth - flick.width);
        restoringOffset = true;
        flick.contentX = Math.max(0, Math.min(maximum, Number(offset) || 0));
        restoringOffset = false;
    }

    function positionFor(key) {
        for (var i = 0; i < items.length; i++)
            if (StoreLogic.itemKey(items[i]) === key)
                return i;
        return -1;
    }

    function setPending(index) {
        if (items.length === 0) {
            pendingKey = "";
            flick.contentX = 0;
            return;
        }
        var bounded = Math.max(0, Math.min(items.length - 1, index));
        pendingKey = StoreLogic.itemKey(items[bounded]);
        var maximum = Math.max(0, flick.contentWidth - flick.width);
        flick.contentX = Math.max(0, Math.min(maximum, bounded * step));
    }

    function move(delta) {
        const current = Math.max(0, positionFor(pendingKey || selectedKey));
        setPending(Math.max(0, Math.min(items.length - 1, current + delta)));
    }

    function moveBoundary(last) {
        if (items.length > 0)
            setPending(last ? items.length - 1 : 0);
    }

    function previewAt(index) {
        if (index >= 0 && index < items.length)
            previewRequested(items[index]);
    }

    function commitPending() {
        const index = positionFor(pendingKey);
        if (index >= 0)
            selectionRequested(items[index]);
    }

    function settleMovement() {
        if (items.length === 0)
            return;
        const maximum = Math.max(0, flick.contentWidth - flick.width);
        const atEnd = maximum > 0 && flick.contentX >= maximum - 0.5;
        const index = atEnd ? items.length - 1
                            : Math.round(flick.contentX / Math.max(1, step));
        setPending(index);
        commitPending();
    }

    function queueWheel(delta) {
        if (delta === 0)
            return;
        move(delta < 0 ? 1 : -1);
        wheelDirty = true;
    }

    function settleWheel() {
        if (!wheelDirty || horizontalWheel.active || verticalWheel.active)
            return;
        wheelDirty = false;
        commitPending();
    }

    onSelectedKeyChanged: {
        var index = positionFor(selectedKey);
        if (index >= 0)
            setPending(index);
    }
    onItemsChanged: {
        var index = positionFor(selectedKey);
        setPending(index >= 0 ? index : 0);
    }

    Keys.onLeftPressed: event => {
        move(-1);
        commitPending();
        event.accepted = true;
    }
    Keys.onRightPressed: event => {
        move(1);
        commitPending();
        event.accepted = true;
    }
    Keys.onPressed: event => {
        if (event.key === Qt.Key_Home)
            moveBoundary(false);
        else if (event.key === Qt.Key_End)
            moveBoundary(true);
        else
            return;
        commitPending();
        event.accepted = true;
    }

    Flickable {
        id: flick
        objectName: "ryostore-filmstrip-flick"
        anchors.fill: parent
        clip: true
        contentWidth: products.width
        contentHeight: height
        flickableDirection: Flickable.HorizontalFlick
        boundsBehavior: Flickable.StopAtBounds
        onFlickStarted: {
            if (strip.reducedMotion)
                cancelFlick();
        }

        Behavior on contentX {
            enabled: !strip.reducedMotion && !strip.restoringOffset && !flick.dragging && !flick.flicking
            NumberAnimation { duration: Tokens.move; easing.type: Tokens.ease }
        }

        onMovementEnded: strip.settleMovement()

        Row {
            id: products
            width: Math.max(0, strip.items.length * strip.cardWidth
                            + Math.max(0, strip.items.length - 1) * spacing)
            height: parent.height
            spacing: Tokens.s3

            Repeater {
                model: strip.items

                delegate: Item {
                    id: product
                    required property var modelData
                    required property int index
                    width: strip.cardWidth
                    height: products.height
                    scale: StoreLogic.itemKey(modelData) === strip.pendingKey ? 1 : 0.92

                    Behavior on scale {
                        enabled: !strip.reducedMotion
                        NumberAnimation { duration: Tokens.snap; easing.type: Tokens.easeSnap }
                    }

                    ProductCover {
                        anchors.fill: parent
                        item: product.modelData
                        selected: StoreLogic.itemKey(product.modelData) === strip.pendingKey
                    }

                    Rectangle {
                        objectName: StoreLogic.itemKey(product.modelData) === strip.pendingKey
                                ? "ryostore-filmstrip-focus"
                                : ""
                        anchors.fill: parent
                        color: "transparent"
                        border.width: Tokens.border * 2
                        border.color: Tokens.bone
                        visible: strip.activeFocus
                                && StoreLogic.itemKey(product.modelData) === strip.pendingKey
                    }

                    HoverHandler {
                        id: hover
                        cursorShape: Qt.PointingHandCursor
                        onHoveredChanged: strip.previewRequested(hover.hovered ? product.modelData : null)
                    }

                    TapHandler {
                        onTapped: {
                            strip.setPending(product.index);
                            strip.commitPending();
                        }
                    }
                }
            }
        }
    }

    WheelHandler {
        id: horizontalWheel
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        orientation: Qt.Horizontal
        blocking: false
        onWheel: event => {
            const delta = event.angleDelta.x !== 0 ? event.angleDelta.x : event.pixelDelta.x;
            if (delta === 0)
                return;
            strip.queueWheel(delta);
            event.accepted = true;
        }
        onActiveChanged: {
            if (!active)
                strip.settleWheel();
        }
    }

    WheelHandler {
        id: verticalWheel
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        orientation: Qt.Vertical
        blocking: false
        onWheel: event => {
            const delta = event.angleDelta.y !== 0 ? event.angleDelta.y : event.pixelDelta.y;
            if (delta === 0)
                return;
            strip.queueWheel(delta);
            event.accepted = true;
        }
        onActiveChanged: {
            if (!active)
                strip.settleWheel();
        }
    }
}
