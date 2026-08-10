// QS Bar (Quickshell Rise) entry, adapted to Ryoku's barstyle contract.
//
// HANCORE's shell.qml is a ShellRoot that owns StateService + VariantHost +
// IpcRouter and lets the active VariantRoot draw one bar per output. Ryoku loads
// a barstyle Scene once per monitor via Frame's Loader, so this Scene replicates
// that ShellRoot body verbatim but as a plain Item, instantiated a single time
// on the primary output. The VariantRoot inside still fans a bar across every
// screen itself, exactly as upstream, so multi-monitor behaviour is unchanged.
//
// Everything below the integration seam is HANCORE's own system, 1:1.

import Quickshell
import QtQuick
import "../../../../services/lib/screens.js" as Screens
import "core"
// Quickshell's virtual filesystem scanner follows declared directory imports,
// not arbitrary Loader URLs; the alias registers the complete V2 bundle while
// keeping every V2 type uninstantiated until VariantHost selects it.
import "variants/V2" as V2Bundle

Item {
    id: sceneRoot

    // The screen, set by Frame's per-monitor Loader.
    property var modelData: null

    width: 0
    height: 0

    // Host the single shell system on exactly one Scene: the primary output, the
    // first entry of the shared deduped screen list (services/lib/screens.js).
    // Matching by name (not object identity) keeps exactly one Scene primary even
    // when a duplicate output announce briefly swaps the ShellScreen object, so
    // the bar system is never hosted twice.
    readonly property bool isPrimary: {
        var list = Screens.uniqueByName(Quickshell.screens)
        return list.length > 0 && !!sceneRoot.modelData
            && list[0].name === sceneRoot.modelData.name
    }

    Loader {
        active: sceneRoot.isPrimary
        sourceComponent: Component {
            Item {
                StateService {
                    id: variantState
                }

                VariantHost {
                    id: variantHost
                    stateService: variantState
                    v1Source: Qt.resolvedUrl("VariantRoot.qml")
                    v2Source: Qt.resolvedUrl("variants/V2/VariantRoot.qml")
                }

                IpcRouter {
                    variantHost: variantHost
                }
            }
        }
    }
}
