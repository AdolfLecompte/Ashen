pragma Singleton
import Quickshell
import QtQuick

// Every path the shell reads or writes, resolved from the environment.
// Nothing in Ashen may hardcode a home directory: the shell has to work for
// whoever cloned it, not just for the machine it was written on.
Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME") || "/tmp"

    readonly property string config: home + "/.config/ashen"
    readonly property string cache: home + "/.cache"
    readonly property string state: home + "/.local/state/ashen"

    // matugen writes the live scheme here on every wallpaper change
    readonly property string scheme: cache + "/ashen_scheme.json"
    readonly property string notificationHistory: state + "/notifications.json"
    readonly property string recordings: home + "/Videos"
    // Default wallpaper folder; Settings > Appearance may point elsewhere
    readonly property string wallpapers: home + "/Pictures/Wallpapers"
}
