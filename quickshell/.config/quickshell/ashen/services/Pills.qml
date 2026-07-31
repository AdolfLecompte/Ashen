pragma Singleton
import Quickshell
import QtQuick

// What a pill IS, in one place: its name, its compact face, and whether it
// opens something.
//
// This used to be spread across three files that had to agree by hand --
// `Bar.qml` mapped ids to components, `SettingsBarTab` kept the human names,
// and each pill carried its own glyph. Adding a pill meant remembering all
// three, and the utility pill could not show any of them at all.
//
// A pill has two faces. On the bar it is its full self: the clock shows the
// time and the weather, the workspaces show five chips. Dropped into the
// utility pill it wears `glyph` instead -- a plain icon chip like every other
// tool there. That is what lets anything move either way: a two-hundred-pixel
// clock has no business stretching a strip of icons, but a clock icon does.
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
        locks:         { label: "Caps / Num",    glyph: "", opens: "" },
        usb:           { label: "USB",           glyph: "", opens: "usbVisible" },
        recording:     { label: "Recording",     glyph: "", opens: "" },
        tray:          { label: "Tray",          glyph: "", opens: "" },
        system:        { label: "System chips",  glyph: "", opens: "" },
        window:        { label: "Active window", glyph: "\ue8f5", opens: "" },
        power:         { label: "Power",         glyph: "", opens: "powerMenuVisible" },

        // The three tools. They were born on the utility pill, but there is
        // nothing special about them -- they are pills like the rest and may
        // sit on the bar just as well.
        process:       { label: "Process",       glyph: "", opens: "processVisible" },
        settings:      { label: "Settings",      glyph: "", opens: "settingsVisible" },
        clipboard:     { label: "Clipboard",     glyph: "", opens: "clipboardVisible" },
        // The drawer is not movable: it is the way in to everything else, so
        // it is pinned to the end of the utility pill and never listed.
        utilities:     { label: "Utilities",     glyph: "", opens: "utilitiesVisible" },
    })

    // Everything the user may arrange, in the order Settings offers them.
    readonly property var arrangeable: [
        "launcher", "notifications", "workspaces", "media", "clock", "locks",
        "usb", "recording", "tray", "system", "window", "power",
        "process", "settings", "clipboard"
    ]

    function label(id) { const m = meta[id]; return m ? m.label : id }
    function glyph(id) { const m = meta[id]; return m ? m.glyph : "" }
    function opens(id) { const m = meta[id]; return m ? m.opens : "" }
}
