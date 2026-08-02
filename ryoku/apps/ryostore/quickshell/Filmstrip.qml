import QtQuick
import Ryoku.Ui.Singletons
import "lib/store.js" as StoreLogic

FocusScope {
    id: strip

    property var items: []
    property string selectedKey: ""
    property bool reducedMotion: false
    property string pendingKey: selectedKey

    signal previewRequested(var item)
    signal selectionRequested(var item)

    readonly property real contentOffset: flick.contentX
    readonly property real cardWidth: Math.max(210, Math.min(330, width * 0.29))
    readonly property real step: cardWidth + Tokens.s3

    activeFocusOnTab: true

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
        anchors.fill: parent
        clip: true
        contentWidth: products.width
        contentHeight: height
        flickableDirection: Flickable.HorizontalFlick
        boundsBehavior: Flickable.StopAtBounds

        Behavior on contentX {
            enabled: !strip.reducedMotion && !flick.dragging && !flick.flicking
            NumberAnimation { duration: Tokens.move; easing.type: Tokens.ease }
        }

        onMovementEnded: {
            strip.setPending(Math.round(contentX / Math.max(1, strip.step)));
            strip.commitPending();
        }

        Row {
            id: products
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
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => {
            var delta = event.angleDelta.y !== 0 ? event.angleDelta.y : event.pixelDelta.y;
            if (delta === 0)
                return;
            strip.move(delta < 0 ? 1 : -1);
            strip.commitPending();
            event.accepted = true;
        }
    }
}
