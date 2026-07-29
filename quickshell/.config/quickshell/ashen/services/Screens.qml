pragma Singleton
import Quickshell
import Quickshell.Hyprland
import QtQuick

// Which screen the overlay panels belong on. Panels are single instances, so
// without this they all map onto Quickshell.screens[0] and a second monitor
// never sees them: they follow the focused Hyprland monitor instead.
Singleton {
    id: root

    readonly property string activeName: Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : ""

    readonly property var active: {
        const screens = Quickshell.screens
        if (!screens || screens.length === 0) return null
        for (const s of screens) {
            if (s.name === root.activeName) return s
        }
        return screens[0]
    }
}
