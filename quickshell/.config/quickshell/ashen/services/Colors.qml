pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    property color abyss:    "#080809"
    property color void_:    "#0f0f11"
    property color crypt:    "#16161a"
    property color surface:  "#1c1c21"
    property color raised:   "#242428"
    property color elevated: "#2e2e34"
    property color snow:     "#e8e8ec"
    property color mist:     "#9090a0"
    property color ash:      "#4a4a54"
    property color ghost:    "#6e6e7a"
    property color shade:    "#4e4e5a"
    property color error_:   "#c87a7a"
    property color neutral:  "#8a8a96"

    function ghostAlpha(a) { return Qt.rgba(ghost.r, ghost.g, ghost.b, a) }
    function surfaceAlpha(a) { return Qt.rgba(surface.r, surface.g, surface.b, a) }
    function snowAlpha(a) { return Qt.rgba(snow.r, snow.g, snow.b, a) }

    // ── Live reload: the JSON is written by applyScheme() (Theme tab) or matugen
    //    (Dynamic mode). As soon as the file changes, every component using
    //    Services.Colors.* updates itself -- no quickshell restart needed.
    FileView {
        id: schemeFile
        path: "/home/adolf/.cache/ashen_scheme.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                let s = JSON.parse(text())
                if (s.abyss) root.abyss = s.abyss
                if (s.void_) root.void_ = s.void_
                if (s.crypt) root.crypt = s.crypt
                if (s.surface) root.surface = s.surface
                if (s.raised) root.raised = s.raised
                if (s.elevated) root.elevated = s.elevated
                if (s.snow) root.snow = s.snow
                if (s.mist) root.mist = s.mist
                if (s.ash) root.ash = s.ash
                if (s.ghost) root.ghost = s.ghost
                if (s.shade) root.shade = s.shade
                if (s.error_) root.error_ = s.error_
                if (s.neutral) root.neutral = s.neutral
            } catch (e) {
                console.log("[Colors] error parseando ashen_scheme.json:", e)
            }
        }
    }
}
