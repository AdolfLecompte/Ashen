// ══════════════════════════════════════════════════════════════════════════
//   Ashen — a Hyprland + Quickshell rice.   by Adolf — github.com/AdolfLecompte
//   Root of the shell: wires every module (bar, lock, launcher, …) together.
// ══════════════════════════════════════════════════════════════════════════
import Quickshell
import Quickshell.Io
import QtQuick

import "root:/modules/bar"
// The panels that hang off it. They used to live in modules/bar/ alongside
// Bar.qml itself, so "the bar" meant both the strip and the fifteen windows
// that grow out of it.
import "root:/modules/panels"
import "root:/modules/lock"
import "root:/modules/launcher"
import "root:/modules/wallpaper"
import "root:/modules/settings"
import "root:/modules/clipboard"
import "root:/modules/utilities"
import "root:/modules/widgets" as Widgets
import "root:/services" as Services

ShellRoot {
    // ── IPC ───────────────────────────────────────────────────────────────
    // Handlers live here, not inside the panels: a lazily loaded panel does not
    // exist while it is closed and its handler would vanish with it. All they do
    // is flip state; panels react in their own onShownChanged.
    IpcHandler {
        target: "volume"
        function toggle() { Services.AppState.toggleOverlay("volumeVisible") }
    }
    IpcHandler {
        target: "brightness"
        function toggle() { Services.AppState.toggleOverlay("brightnessVisible") }
    }
    IpcHandler {
        target: "battery"
        function toggle() { Services.AppState.toggleOverlay("batteryVisible") }
    }

    IpcHandler {
        target: "launcher"
        function toggle() { Services.AppState.toggleOverlay("launcherVisible") }
    }

    // Monitors. `apply` is the one worth a keybind: plugging a screen in leaves
    // Hyprland with its own idea of the layout, and this puts ours back.
    IpcHandler {
        target: "displays"
        function apply() { Services.Displays.applyAll() }
        // The same apply the tab does: it comes back on its own in 10s unless
        // `keep` says the screen survived it. What a keybind should call.
        function tryApply() { Services.Displays.applyWithRevert() }
        function keep() { Services.Displays.confirm() }
        function undo() { Services.Displays.revert() }
        function refresh() { Services.Displays.refresh() }
        function place(monitor: string, cell: int) { Services.Displays.moveToCell(monitor, cell) }
        function mirror(monitor: string, target: string) {
            Services.Displays.setEntry(monitor, { mirror: target })
        }
        function assign(monitor: string, workspace: int, on: bool) {
            Services.Displays.assignWorkspace(monitor, workspace, on)
        }
        // 0 / 1 / 2 / 3 = normal, 90, 180, 270. Worth a keybind on a machine
        // whose screen folds over.
        function rotate(monitor: string, transform: int) {
            Services.Displays.setEntry(monitor, { transform: transform })
        }
        function scale(monitor: string, factor: string) {
            Services.Displays.setEntry(monitor, { scale: parseFloat(factor) })
        }
        function list(): string {
            let out = []
            for (const m of Services.Displays.monitors) {
                const k = Services.Displays.keyOf(m)
                const e = Services.Displays.entry(k)
                out.push(m.name + " key=" + k + " cell=" + e.cell + " scale=" + e.scale
                         + " transform=" + e.transform + " mirror=" + (e.mirror || "-")
                         + " pos=" + Services.Displays.positionFor(k))
            }
            return out.join("\n")
        }
    }
    IpcHandler {
        target: "settings"
        function toggle() {
            Services.AppState.settingsSourceEdge = Services.Sizes.utilEdge
            Services.AppState.toggleOverlay("settingsVisible")
        }
        // Jump straight to a section:
        // system|bar|display|sound|network|input|notifications|theme|about
        function tab(name: string) {
            // Wi-Fi and Bluetooth used to be tabs of their own; keep the old
            // names working now that they share the Network tab.
            const id = (name === "wifi" || name === "bluetooth") ? "network" : name
            Services.AppState.settingsTab = id
            Services.AppState.settingsSourceEdge = Services.Sizes.utilEdge
            Services.AppState.settingsVisible = true
        }
    }
    IpcHandler {
        target: "clipboard"
        function toggle() {
            // Nothing was clicked, so nobody named an edge: use the pill a
            // keybind is meant to come from. Without this the panel kept the
            // edge of whatever was clicked last and left from the wrong side.
            Services.AppState.clipboardSourceEdge = Services.Sizes.utilEdge
            Services.AppState.toggleOverlay("clipboardVisible")
        }
    }
    IpcHandler {
        target: "utilities"
        function toggle() {
            // Nothing was clicked, so nobody named an edge: use the pill a
            // keybind is meant to come from. Without this the panel kept the
            // edge of whatever was clicked last and left from the wrong side.
            Services.AppState.utilitiesSourceEdge = Services.Sizes.utilEdge
            Services.AppState.toggleOverlay("utilitiesVisible")
        }
    }
    IpcHandler {
        target: "process"
        function toggle() {
            // Nothing was clicked, so nobody named an edge: use the pill a
            // keybind is meant to come from. Without this the panel kept the
            // edge of whatever was clicked last and left from the wrong side.
            Services.AppState.processSourceEdge = Services.Sizes.utilEdge
            Services.AppState.toggleOverlay("processVisible")
        }
    }
    IpcHandler {
        target: "power"
        function toggle() { Services.AppState.powerMenuVisible = !Services.AppState.powerMenuVisible }
    }
    IpcHandler {
        target: "media"
        function toggle() { Services.AppState.mediaVisible = !Services.AppState.mediaVisible }
    }
    IpcHandler {
        target: "calendar"
        function toggle() { Services.AppState.calendarVisible = !Services.AppState.calendarVisible }
    }
    IpcHandler {
        target: "bluetooth"
        function toggle() { Services.AppState.bluetoothVisible = !Services.AppState.bluetoothVisible }
    }
    IpcHandler {
        target: "network"
        function toggle() { Services.AppState.networkVisible = !Services.AppState.networkVisible }
    }
    IpcHandler {
        target: "notifications"
        function toggle() { Services.AppState.notificationsVisible = !Services.AppState.notificationsVisible }
        function screenshot() { Services.Notifications.addSystemToast("SCREENSHOT SAVED", "\uf727", false, "screenshot") }
    }
    IpcHandler {
        target: "bar"
        // Moving the bar is animated by Sizes, so a keybind gets the same
        // slide-out/slide-in as the Settings picker.
        function position(edge: string) {
            if (["top", "bottom", "left", "right"].indexOf(edge) === -1) return
            Services.Prefs.barPosition = edge
        }
        function cycle() {
            const order = ["top", "right", "bottom", "left"]
            const i = order.indexOf(Services.Prefs.barPosition)
            Services.Prefs.barPosition = order[(i + 1) % order.length]
        }
    }
    IpcHandler {
        target: "wallpaper"
        // Scanning and positioning are driven by the picker's onShownChanged, so
        // both entry points (this keybind and the Settings tab) behave the same.
        function open() {
            Services.AppState.closeBigOverlays()
            Services.AppState.wallpaperVisible = true
        }
        function close() { Services.AppState.wallpaperVisible = false }
        function toggle() {
            if (Services.AppState.wallpaperVisible) close()
            else open()
        }
    }

    // ── Always resident ───────────────────────────────────────────────────
    // The bar is the shell; the rest of this list has to answer a key press or
    // a system event instantly, so none of it can be built on demand.
    Bar {}
    OsdPanel {}
    NotificationToast {}
    Widgets.UtilityTriggers {}
    LockScreen {}

    // A singleton is built the first time something asks for it, and nothing
    // asks for this one until Settings > Display is opened -- by which time the
    // monitors have been sitting in Hyprland's own arrangement all session.
    // Touching it here is what makes the saved layout come back at login.
    Component.onCompleted: Services.Displays.refresh()

    // ── Built on demand ───────────────────────────────────────────────────
    Widgets.LazyPanel { preloadMs: 1320; shown: Services.AppState.volumeVisible;        panel: Component { VolumePanel {} } }
    Widgets.LazyPanel { preloadMs: 1440; shown: Services.AppState.brightnessVisible;    panel: Component { BrightnessPanel {} } }
    Widgets.LazyPanel { preloadMs: 1560; shown: Services.AppState.batteryVisible;       panel: Component { BatteryPanel {} } }
    Widgets.LazyPanel { preloadMs: 1680; shown: Services.AppState.mediaVisible;         panel: Component { MediaPanel {} } }
    Widgets.LazyPanel { preloadMs: 1800; shown: Services.AppState.notificationsVisible; panel: Component { NotificationPanel {} } }
    Widgets.LazyPanel { preloadMs: 1920; shown: Services.AppState.settingsVisible;      panel: Component { SettingsPanel {} } }
    Widgets.LazyPanel { preloadMs: 2040; shown: Services.AppState.powerMenuVisible;     panel: Component { PowerMenu {} } }
    Widgets.LazyPanel { preloadMs: 2160; shown: Services.AppState.calendarVisible;      panel: Component { Calendar {} } }
    Widgets.LazyPanel { preloadMs: 2400; shown: Services.AppState.wsPreviewId !== 0;   panel: Component { WorkspacePreview {} } }
    Widgets.LazyPanel { preloadMs: 2280; shown: Services.AppState.networkVisible;       panel: Component { NetworkPanel {} } }
    Widgets.LazyPanel { preloadMs: 2400; shown: Services.AppState.bluetoothVisible;     panel: Component { BluetoothPanel {} } }
    Widgets.LazyPanel { preloadMs: 2520; shown: Services.AppState.usbVisible;           panel: Component { USBPanel {} } }
    Widgets.LazyPanel { preloadMs: 2640; shown: Services.AppState.trayMenuVisible;      panel: Component { TrayMenu {} } }
    Widgets.LazyPanel { preloadMs: 2760; shown: Services.AppState.processVisible;       panel: Component { ProcessPanel {} } }
    Widgets.LazyPanel { preloadMs: 2880; shown: Services.AppState.launcherVisible;      panel: Component { Launcher {} } }
    Widgets.LazyPanel { preloadMs: 3000; shown: Services.AppState.wallpaperVisible;     panel: Component { WallpaperPicker {} } }
    Widgets.LazyPanel { preloadMs: 3360; shown: Services.AppState.clipboardVisible;     panel: Component { Clipboard {} } }
    Widgets.LazyPanel { preloadMs: 3480; shown: Services.AppState.utilitiesVisible;     panel: Component { UtilitiesPanel {} } }
}
