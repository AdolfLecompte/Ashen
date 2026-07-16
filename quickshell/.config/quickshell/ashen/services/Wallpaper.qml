pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// The current wallpaper, resolved to something QML can actually paint.
// ashen-wallpaper.sh writes the chosen path to ashen_wallpaper.txt and always
// extracts a still to ashen_wall_frame.png (ensure_frame), so video/gif
// wallpapers -- which QML cannot draw -- fall back to that frame.
Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME") || "/home/adolf"

    // Raw path as written by the wallpaper script ("" = nothing chosen yet)
    property string path: ""
    // Bumped on every change: the frame's path is fixed but its contents are
    // not, so consumers need a cache-busting token (same trick as faceVersion).
    property real version: 0

    readonly property bool isStill: /\.(png|jpe?g|webp)$/i.test(root.path)
    readonly property string stillPath: root.path === ""
        ? "" : (root.isStill ? root.path : root.home + "/.cache/ashen_wall_frame.png")
    // Ready to drop into an Image.source. Pair it with cache: false.
    readonly property string stillUrl: root.stillPath === ""
        ? "" : "file://" + root.stillPath + "?v=" + root.version

    FileView {
        path: root.home + "/.cache/ashen_wallpaper.txt"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            root.path = text().trim()
            root.version = Date.now()
        }
        onLoadFailed: root.path = ""
    }
}
