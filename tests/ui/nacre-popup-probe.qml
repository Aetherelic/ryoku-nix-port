import QtQuick
import Quickshell
import "barstyles/shared" as Shared
import "barstyles/shared/popouts" as Popouts
import "barstyles/obi/widgets" as Obi
import "barstyles/nacre/components" as NacreComponents
import "barstyles/nacre/widgets" as NacreWidgets

ShellRoot {
    id: root

    Shared.Popout {}

    Component { id: audio; Popouts.AudioPopout {} }
    Component { id: battery; Popouts.BatteryPopout {} }
    Component { id: calendar; Popouts.CalendarPopout {} }
    Component { id: connectivity; Popouts.ConnectivityPopout {} }
    Component { id: media; Popouts.MediaPopout {} }
    Component { id: resources; Popouts.ResourcesPopout {} }
    Component { id: weather; Popouts.WeatherPopout {} }
    Component { id: obiAudio; Obi.Audio {} }
    Component { id: obiBattery; Obi.Battery {} }
    Component { id: obiClock; Obi.Clock {} }
    Component { id: obiConnectivity; Obi.Connectivity {} }
    Component { id: obiMedia; Obi.Media {} }
    Component { id: obiResources; Obi.Resources {} }
    Component { id: obiWeather; Obi.Weather {} }
    Component {
        id: nacreScene
        Loader {
            source: "barstyles/nacre/Scene.qml"
            onLoaded: item.modelData = Quickshell.screens[0]
        }
    }
    Component { id: nacreActiveWindow; NacreWidgets.ActiveWindow {} }
    Component { id: nacreAudio; NacreWidgets.Audio {} }
    Component { id: nacreBattery; NacreWidgets.Battery {} }
    Component { id: nacreBrand; NacreWidgets.Brand {} }
    Component { id: nacreClock; NacreWidgets.Clock {} }
    Component { id: nacreConnectivity; NacreWidgets.Connectivity {} }
    Component { id: nacreMedia; NacreWidgets.Media {} }
    Component { id: nacreResources; NacreWidgets.Resources {} }
    Component { id: nacreTray; NacreWidgets.Tray {} }
    Component { id: nacreUtils; NacreWidgets.Utils {} }
    Component { id: nacreWeather; NacreWidgets.Weather {} }
    Component { id: nacreWorkspaces; NacreWidgets.Workspaces {} }
    Component {
        id: nacreIsland
        NacreComponents.Island {}
    }
    Component {
        id: nacreConnectivityUrl
        Loader { source: "barstyles/nacre/widgets/Connectivity.qml" }
    }
    Component {
        id: connectivityPopupUrl
        Loader { source: "barstyles/shared/popouts/ConnectivityPopout.qml" }
    }

    Timer {
        interval: 0
        running: true
        onTriggered: {
            const components = [
                audio, battery, calendar, connectivity, media, resources, weather,
                obiAudio, obiBattery, obiClock, obiConnectivity, obiMedia, obiResources, obiWeather,
                nacreActiveWindow, nacreAudio, nacreBattery, nacreBrand, nacreClock,
                nacreConnectivity, nacreMedia, nacreResources, nacreTray, nacreUtils, nacreWeather,
                nacreWorkspaces
            ];
            for (const component of components) {
                const item = component.createObject(root);
                if (!item)
                    throw new Error("NACRE-POPUP-PROBE-FAIL");
                item.destroy();
            }
            const scene = nacreScene.createObject(root);
            if (!scene || scene.status !== Loader.Ready)
                throw new Error("NACRE-SCENE-PROBE-FAIL");
            scene.destroy();
            const connectivityUrl = nacreConnectivityUrl.createObject(root);
            if (!connectivityUrl || connectivityUrl.status !== Loader.Ready)
                throw new Error("NACRE-CONNECTIVITY-PROBE-FAIL");
            connectivityUrl.destroy();
            const connectivityPopup = connectivityPopupUrl.createObject(root);
            if (!connectivityPopup || connectivityPopup.status !== Loader.Ready)
                throw new Error("CONNECTIVITY-POPUP-PROBE-FAIL");
            connectivityPopup.destroy();
            const emptyIsland = nacreIsland.createObject(root, { widgetIds: [] });
            if (!emptyIsland || emptyIsland.visible || emptyIsland.width !== 0 || emptyIsland.height !== 0)
                throw new Error("NACRE-EMPTY-ISLAND-PROBE-FAIL");
            const populatedIsland = nacreIsland.createObject(root, { widgetIds: ["brand"] });
            if (!populatedIsland || !populatedIsland.visible || !populatedIsland.hasWidgets
                    || populatedIsland.naturalWidth <= 0 || populatedIsland.height <= 0)
                throw new Error("NACRE-POPULATED-ISLAND-PROBE-FAIL");
            populatedIsland.widgetIds = [];
            populatedIsland.destroy();
            emptyIsland.destroy();
            console.log("NACRE-POPUP-PROBE-PASS");
            Qt.quit();
        }
    }
}
