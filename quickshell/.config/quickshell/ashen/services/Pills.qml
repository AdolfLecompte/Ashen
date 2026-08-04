pragma Singleton
import Quickshell
import QtQuick

// What a pill IS, in one place: name, compact face, and what it opens. Used to
// be spread across Bar.qml, SettingsBarTab and each pill's own glyph.
//
// `glyph` is the compact face the utility pill's tools wear; a bar pill draws
// its full self and only needs the label.
Singleton {
    id: root

    // key: what it is called in Prefs.barLayout and in the drag-and-drop UI.
    //   label — the human name, shown in Settings > Bar
    //   glyph — its compact face, for the utility pill
    //   opens — AppState flag its chip toggles there; "" means the compact
    //           face is not interactive (it is a readout, not a button)
    readonly property var meta: ({
        launcher:      { label: "Launcher",      glyph: "", opens: "launcherVisible" },
        notifications: { label: "Notifications", glyph: "", opens: "notificationsVisible" },
        workspaces:    { label: "Workspaces",    glyph: "", opens: "" },
        media:         { label: "Media",         glyph: "", opens: "mediaVisible" },
        clock:         { label: "Clock & Weather", glyph: "", opens: "calendarVisible" },
        usb:           { label: "USB",           glyph: "", opens: "usbVisible" },
        recording:     { label: "Recording",     glyph: "", opens: "" },
        tray:          { label: "Tray",          glyph: "", opens: "" },
        system:        { label: "System chips",  glyph: "", opens: "" },
        window:        { label: "Active window", glyph: "\ue8f5", opens: "" },
        power:         { label: "Power",         glyph: "", opens: "powerMenuVisible" },

        // The tools. They live on the utility pill, always, in this order --
        // they are not bar pills and cannot be moved onto it.
        process:       { label: "Process",       glyph: "\ueaa2", opens: "processVisible" },
        settings:      { label: "Settings",      glyph: "\ue8b8", opens: "settingsVisible" },
        clipboard:     { label: "Clipboard",     glyph: "\ue14f", opens: "clipboardVisible" },
        // The drawer is pinned to the end of the utility pill and never listed.
        utilities:     { label: "Utilities",     glyph: "\ue5cc", opens: "utilitiesVisible" },
    })

    // Everything the user may arrange on the bar, in the order Settings
    // offers them. The tools are not here: they are fixed to the utility pill.
    readonly property var arrangeable: [
        "launcher", "notifications", "workspaces", "media", "clock",
        "usb", "recording", "tray", "system", "window", "power"
    ]

    // The utility pill's chips, in the order they sit in it.
    readonly property var tools: ["process", "settings", "clipboard"]
    function isTool(id) { return root.tools.indexOf(id) !== -1 }

    function label(id) { const m = meta[id]; return m ? m.label : id }
    function glyph(id) { const m = meta[id]; return m ? m.glyph : "" }
    function opens(id) { const m = meta[id]; return m ? m.opens : "" }
}
