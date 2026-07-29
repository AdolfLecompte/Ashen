// Ashen — Countdown timer service.  by Adolf — github.com/AdolfLecompte
pragma Singleton
import Quickshell
import QtQuick
import "root:/services" as Services

// Named Countdown, not Timer: `Timer` is a QML type and a singleton wearing
// that name would shadow it inside every file that imports the services.
//
// Same reasoning as Stopwatch — the countdown has to outlive the panel, or you
// could never start one and walk away, which is the entire point. Remaining
// time is a subtraction against a wall-clock deadline, so a late tick or a
// suspended laptop cannot make it drift.
Singleton {
    id: root

    property bool running: false
    // Wall-clock ms the countdown ends at, while running
    property double endsAt: 0
    // What is left while paused, and what a reset goes back to
    property double leftover: 0
    property double preset: 5 * 60000
    property bool rang: false

    property int tick: 0

    readonly property double remaining: {
        tick
        // Idle with nothing banked shows the preset, not zero: a timer parked
        // on "5m" that reads 00:00 looks broken, and the ring reads empty when
        // it is in fact completely full.
        if (!running) return leftover > 0 ? leftover : preset
        return Math.max(0, endsAt - Date.now())
    }
    readonly property bool active: running || leftover > 0
    // 1 -> 0 as it runs down; drives the ring in the panel
    readonly property real progress: preset > 0 ? Math.max(0, Math.min(1, remaining / preset)) : 0

    // "05:00" / "1:05:00" — no tenths, this is a thing you glance at
    function format(ms) {
        let t = Math.max(0, Math.ceil(ms / 1000))
        let s = t % 60
        let m = Math.floor(t / 60) % 60
        let h = Math.floor(t / 3600)
        let two = n => (n < 10 ? "0" : "") + n
        return h > 0 ? h + ":" + two(m) + ":" + two(s) : two(m) + ":" + two(s)
    }

    readonly property string display: format(remaining)

    function startFor(ms) {
        if (ms <= 0) return
        preset = ms
        leftover = ms
        endsAt = Date.now() + ms
        rang = false
        running = true
    }
    function start() {
        if (running) return
        let ms = leftover > 0 ? leftover : preset
        if (ms <= 0) return
        endsAt = Date.now() + ms
        rang = false
        running = true
    }
    function pause() {
        if (!running) return
        leftover = remaining
        running = false
    }
    function toggle() { running ? pause() : start() }
    function reset() {
        running = false
        leftover = 0
        endsAt = 0
        rang = false
    }
    // Nudge the preset from the panel's +/- controls
    function bump(deltaMs) {
        if (running) {
            endsAt = Math.max(Date.now(), endsAt + deltaMs)
            preset = Math.max(1000, preset + deltaMs)
        } else {
            preset = Math.max(0, preset + deltaMs)
            leftover = 0
        }
    }

    function ring() {
        running = false
        leftover = 0
        rang = true
        Services.Notifications.addSystemToast("TIMER DONE", "\ue425", false, "countdown")
    }

    Timer {
        interval: 200
        repeat: true
        running: root.running
        onTriggered: {
            root.tick++
            if (Date.now() >= root.endsAt) root.ring()
        }
    }
}
