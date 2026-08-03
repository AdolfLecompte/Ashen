pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// Every path the shell reads or writes, resolved from the environment.
// Nothing in Ashen may hardcode a home directory: the shell has to work for
// whoever cloned it, not just for the machine it was written on.
Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME") || "/tmp"

    // Where the helper scripts live. Running from a clone they sit in the
    // checkout; installed as a package they are on PATH, so the bare name is
    // the right thing to exec. Resolved once, because it cannot change while
    // the shell is up.
    property string scriptDir: home + "/ashen/scripts"
    function script(name) {
        return root.scriptDir === "" ? name : root.scriptDir + "/" + name
    }
    Process {
        running: true
        command: ["sh", "-c", '[ -d "$1" ] && echo repo || echo pkg',
                  "sh", root.home + "/ashen/scripts"]
        stdout: StdioCollector {
            onStreamFinished: if (text.trim() === "pkg") root.scriptDir = ""
        }
    }

    readonly property string config: home + "/.config/ashen"
    readonly property string cache: home + "/.cache"
    readonly property string state: home + "/.local/state/ashen"

    // matugen writes the live scheme here on every wallpaper change
    readonly property string scheme: cache + "/ashen_scheme.json"
    readonly property string notificationHistory: state + "/notifications.json"
    readonly property string recordings: home + "/Videos"
    // Default wallpaper folder; Settings > Appearance may point elsewhere
    readonly property string wallpapers: home + "/Pictures/Wallpapers"
    // Default quick-notes folder; Settings > System may point elsewhere
    readonly property string notes: home + "/Notes"
}
