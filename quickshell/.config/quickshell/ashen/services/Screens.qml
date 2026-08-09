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

    // The screens that deserve a bar. A mirrored output still shows up in
    // Quickshell.screens, but Hyprland renders the source monitor's framebuffer
    // onto it -- a bar built there is drawn, exclusion-zoned and never seen.
    // An output Hyprland has not told us about yet keeps its bar: the wildcard
    // in monitors.lua means a new one is extended, not mirrored.
    readonly property var barScreens: {
        const screens = Quickshell.screens
        if (!screens) return []
        const mirrored = {}
        for (const m of Hyprland.monitors.values) {
            const o = m.lastIpcObject
            if (o && o.mirrorOf && o.mirrorOf !== "none") mirrored[o.name] = true
        }
        return screens.filter(s => !mirrored[s.name])
    }
}
