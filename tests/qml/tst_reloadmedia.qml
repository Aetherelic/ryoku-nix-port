import QtQuick
import QtTest
import "../../ryoku/shell/quickshell/reload-cover" as Reload

Item {
    id: root
    width: 640
    height: 360

    Component {
        id: mediaFactory
        Reload.ReloadMedia {
            width: 640
            height: 360
            active: true
        }
    }

    TestCase {
        name: "ReloadMedia"
        when: windowShown

        function makeMedia(descriptor) {
            const item = createTemporaryObject(mediaFactory, root, { descriptor: descriptor })
            verify(!!item, "Component exists")
            return item
        }
        function verifyOrientationProbe(item, expectedTall) {
            compare(item.orientationProbeSize.width, 64)
            compare(item.orientationProbeSize.height, 64)
            compare(item.imageTall, expectedTall)
            tryCompare(item, "probeReleased", true, 3000)
            const probeLoader = findChild(item, "imageProbeLoader")
            verify(!!probeLoader, "Orientation probe loader exists")
            compare(probeLoader.status, Loader.Null)
            compare(probeLoader.item, null)
        }


        function test_default_uses_bundled_wordmark() {
            const item = makeMedia({ path: "", name: "", kind: "default", bytes: 0 })
            compare(item.showingDefault, true)
            compare(item.customReady, false)
            compare(item.mediaError, false)
        }

        function test_missing_enabled_defaults_to_custom_media() {
            const source = Qt.resolvedUrl("../../ryoku/shell/quickshell/reload-cover/assets/logo.png")
            const item = makeMedia({ path: String(source), name: "logo.png", kind: "image", bytes: 1 })
            tryCompare(item, "customReady", true, 3000)
            compare(item.showingDefault, false)
            const customImage = findChild(item, "customImage")
            verify(!!customImage, "Custom image exists")
            fuzzyCompare(customImage.paintedWidth / customImage.paintedHeight, 928 / 160, 0.02)
            compare(customImage.sourceSize.width, Math.ceil(item.width))
            compare(customImage.sourceSize.height, 0)
            verifyOrientationProbe(item, false)
        }

        function test_disabled_custom_image_keeps_default_and_releases_decoders() {
            const source = Qt.resolvedUrl("../../ryoku/shell/quickshell/reload-cover/assets/logo.png")
            const enabled = { path: String(source), name: "logo.png", kind: "image", bytes: 1, enabled: true }
            const item = makeMedia({ path: enabled.path, name: enabled.name, kind: enabled.kind, bytes: enabled.bytes, enabled: false })
            wait(500)
            compare(item.showingDefault, true)
            compare(item.customReady, false)
            const probeLoader = findChild(item, "imageProbeLoader")
            verify(!!probeLoader, "Orientation probe loader exists")
            compare(probeLoader.status, Loader.Null)
            compare(probeLoader.item, null)
            verify(!findChild(item, "customImage"))

            item.descriptor = enabled
            tryCompare(item, "customReady", true, 3000)
            compare(item.showingDefault, false)
            verify(!!findChild(item, "customImage"), "Custom image exists")
        }

        function test_tall_image_preserves_aspect_with_bounded_decode() {
            const source = Qt.resolvedUrl("fixtures/tall.png")
            const item = makeMedia({ path: String(source), name: "tall.png", kind: "image", bytes: 1 })
            tryCompare(item, "customReady", true, 3000)
            const customImage = findChild(item, "customImage")
            verify(!!customImage, "Custom image exists")
            fuzzyCompare(customImage.paintedWidth / customImage.paintedHeight, 640 / 12800, 0.01)
            compare(customImage.sourceSize.width, 0)
            compare(customImage.sourceSize.height, Math.ceil(item.height))
            verifyOrientationProbe(item, true)
        }

        function test_animated_image_becomes_custom_media() {
            const source = Qt.resolvedUrl("../../ryoku/hub/quickshell/art/tiling-dwindle.gif")
            const item = makeMedia({ path: String(source), name: "tiling-dwindle.gif", kind: "animated", bytes: 1 })
            tryCompare(item, "customReady", true, 3000)
            compare(item.showingDefault, false)
        }

        function test_missing_image_reports_error_and_keeps_default() {
            ignoreWarning(/QML Image: Cannot open: file:\/\/\/missing\/reload-cover\.png/)
            const item = makeMedia({ path: "/missing/reload-cover.png", name: "missing.png", kind: "image", bytes: 1 })
            tryCompare(item, "mediaError", true, 3000)
            compare(item.showingDefault, true)
        }

        function test_failure_phase_forces_default() {
            const source = Qt.resolvedUrl("../../ryoku/shell/quickshell/reload-cover/assets/logo.png")
            const item = makeMedia({ path: String(source), name: "logo.png", kind: "image", bytes: 1 })
            tryCompare(item, "customReady", true, 3000)
            item.forceDefault = true
            compare(item.showingDefault, true)
        }
    }
}
