pragma Singleton

import QtQuick

QtObject {
    property var layouts: ({})

    function attach(screenName, items) {
        if (!screenName)
            return;
        const next = Object.assign({}, layouts);
        next[screenName] = items;
        layouts = next;
    }

    function detach(screenName) {
        if (!screenName || layouts[screenName] === undefined)
            return;
        const next = Object.assign({}, layouts);
        delete next[screenName];
        layouts = next;
    }

    function islands(screenName) {
        return layouts[screenName] || [];
    }
}
