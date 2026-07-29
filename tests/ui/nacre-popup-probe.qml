import QtQuick
import Quickshell
import "barstyles/shared" as Shared
import "barstyles/shared/popouts" as Popouts
import "barstyles/obi/widgets" as Obi
import "barstyles/nacre" as Nacre
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
    Component { id: nacreScene; Nacre.Scene { modelData: Quickshell.screens[0] } }
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

    Timer {
        interval: 0
        running: true
        onTriggered: {
            const components = [
                audio, battery, calendar, connectivity, media, resources, weather,
                obiAudio, obiBattery, obiClock, obiConnectivity, obiMedia, obiResources, obiWeather,
                nacreScene, nacreActiveWindow, nacreAudio, nacreBattery, nacreBrand, nacreClock,
                nacreConnectivity, nacreMedia, nacreResources, nacreTray, nacreUtils, nacreWeather,
                nacreWorkspaces
            ];
            for (const component of components) {
                const item = component.createObject(root);
                if (!item)
                    throw new Error("NACRE-POPUP-PROBE-FAIL");
                item.destroy();
            }
            console.log("NACRE-POPUP-PROBE-PASS");
            Qt.quit();
        }
    }
}
