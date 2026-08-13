import QtQuick
import Quickshell.Io

// External IPC surface for the single qsbar. Dispatches to the one VariantRoot
// (barRoot); a call that arrives before the bar is ready is queued and flushed
// once it becomes ready, so early theme/launcher pushes are never lost.
Item {
    id: router

    required property var barRoot

    property var pendingThemePayload: undefined
    property var pendingLauncherPayload: undefined
    property bool pendingThemeReload: false
    property string pendingPickerMode: ""
    property bool pendingSystemRefresh: false

    width: 0
    height: 0

    function canDispatch() {
        return barRoot !== null && barRoot.ready
    }

    function invoke(method, first, second) {
        if (!canDispatch()) return false
        var fn = barRoot[method]
        if (!fn) return false

        if (second !== undefined) fn(first, second)
        else if (first !== undefined) fn(first)
        else fn()
        return true
    }

    function applyTheme(payload) {
        if (!invoke("applyTheme", payload)) pendingThemePayload = payload
    }

    function applyLauncher(payload) {
        if (!invoke("applyLauncher", payload)) pendingLauncherPayload = payload
    }

    function reloadTheme() {
        if (!invoke("reloadTheme")) pendingThemeReload = true
    }

    function openPicker(mode) {
        if (!invoke("openPicker", mode)) pendingPickerMode = mode
    }

    function systemRefresh() {
        if (!invoke("systemUpdateRefresh")) pendingSystemRefresh = true
    }

    function flush() {
        if (!canDispatch()) return

        if (pendingThemePayload !== undefined) {
            invoke("applyTheme", pendingThemePayload)
            pendingThemePayload = undefined
        }
        if (pendingLauncherPayload !== undefined) {
            invoke("applyLauncher", pendingLauncherPayload)
            pendingLauncherPayload = undefined
        }
        if (pendingThemeReload) {
            invoke("reloadTheme")
            pendingThemeReload = false
        }
        if (pendingSystemRefresh) {
            invoke("systemUpdateRefresh")
            pendingSystemRefresh = false
        }
        if (pendingPickerMode !== "") {
            invoke("openPicker", pendingPickerMode)
            pendingPickerMode = ""
        }
    }

    IpcHandler {
        target: "lifecycle"
        function ready(): bool { return router.canDispatch() }
    }

    IpcHandler {
        target: "layout"
        function lock(): void { router.invoke("layoutLock") }
        function unlock(): void { router.invoke("layoutUnlock") }
    }

    IpcHandler {
        target: "ryoku.system-update"
        function refresh(): void { router.systemRefresh() }
    }

    IpcHandler {
        target: "reactor"
        function test(kind: string, arg: string): void { router.invoke("runReactor", kind, arg) }
        function monsweep(): void { router.invoke("runReactor", "monsweep", "") }
        function clear(): void { router.invoke("runReactor", "clear", "") }
    }

    IpcHandler {
        target: "theme"
        function apply(payload: string): void { router.applyTheme(payload) }
        function applyLauncher(payload: string): void { router.applyLauncher(payload) }
        function reload(): void { router.reloadTheme() }
    }

    IpcHandler {
        target: "picker"
        function theme(): void { router.openPicker("theme") }
        function wallpaper(): void { router.openPicker("wallpaper") }
        function screenshots(): void { router.openPicker("screenshots") }
        function videos(): void { router.openPicker("videos") }
    }

    Connections {
        target: router.barRoot
        function onReadyChanged() {
            if (router.barRoot && router.barRoot.ready) router.flush()
        }
    }
}
