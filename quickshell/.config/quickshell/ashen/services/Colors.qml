pragma Singleton
import Quickshell
import QtQuick
Singleton {
    id: root
    // ── Fondos ──────────────────────────
    readonly property color abyss:   "#080809"
    readonly property color void_:   "#0f0f11"
    readonly property color crypt:   "#16161a"
    // ── Superficies ─────────────────────
    readonly property color surface:  "#1c1c21"
    readonly property color raised:   "#242428"
    readonly property color elevated: "#2e2e34"
    // ── Texto ───────────────────────────
    readonly property color snow:     "#e8e8ec"
    readonly property color mist:     "#9090a0"
    readonly property color ash:      "#4a4a54"
    // ── Acento ──────────────────────────
    readonly property color ghost:    "#6e6e7a"
    readonly property color shade:    "#4e4e5a"
    // ── Estados ─────────────────────────
    readonly property color error_:   "#c87a7a"
    readonly property color neutral:  "#8a8a96"
    // ── Helpers con alpha ───────────────
    function ghostAlpha(a) { return Qt.rgba(0x6e/255, 0x6e/255, 0x7a/255, a) }
    function surfaceAlpha(a) { return Qt.rgba(0x1c/255, 0x1c/255, 0x21/255, a) }
    function snowAlpha(a) { return Qt.rgba(0xe8/255, 0xe8/255, 0xec/255, a) }
}
