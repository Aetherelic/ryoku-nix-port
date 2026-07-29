import QtQuick
import Quickshell
import "barstyles/shared" as Shared
import "barstyles/shared/popouts" as Popouts
import "barstyles/obi/widgets" as Obi

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

    Timer {
        interval: 0
        running: true
        onTriggered: {
            const components = [
                audio, battery, calendar, connectivity, media, resources, weather,
                obiAudio, obiBattery, obiClock, obiConnectivity, obiMedia, obiResources, obiWeather
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
