pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// User choices that have to survive a shell restart. Everything runtime-only
// (panel visibility, current tab...) belongs in AppState instead.
Singleton {
    id: root

    // Clock
    property bool clockSeconds: true
    property bool clock24h: false
    // Weather: the API only ever returns celsius, so this is display-only
    // ("C" | "F" | "K") and every consumer goes through Weather.tempString().
    property string tempUnit: "C"

    // Active keyboard layout, by code ("latam"). switchxkblayout is runtime-only
    // and Hyprland has no "default index" setting -- only the order of kb_layout
    // decides what login starts on. Storing the pick here means the list order
    // can stay put (the cards must not jump around under the cursor) and the
    // shell re-applies the choice on startup instead.
    property string keyboardLayout: ""

    // Every clock in the shell (bar, calendar, lock) formats through these, so
    // the three can't drift apart.
    readonly property string hourToken: clock24h ? "HH" : "hh"
    readonly property string ampmToken: clock24h ? "" : " AP"
    readonly property string timeFormat: hourToken + ":mm" + (clockSeconds ? ":ss" : "") + ampmToken

    readonly property string configDir: (Quickshell.env("HOME") || "/home/adolf") + "/.config/ashen"

    FileView {
        id: prefsFile
        path: root.configDir + "/prefs.json"
        // Deliberately NOT watchChanges: this file has no writer but us, and
        // reload()-ing our own writeAdapter() re-reads the file mid-flight and
        // reverts whatever was set a moment earlier -- flip two settings quickly
        // and the first one silently snaps back.
        // Any write to the adapter lands on disk immediately
        onAdapterUpdated: writeAdapter()
        // First run: no file yet, so seed it with the defaults above
        onLoadFailed: function(error) { writeAdapter() }

        JsonAdapter {
            id: adapter
            property alias clockSeconds: root.clockSeconds
            property alias clock24h: root.clock24h
            property alias tempUnit: root.tempUnit
            property alias keyboardLayout: root.keyboardLayout
        }
    }
}
