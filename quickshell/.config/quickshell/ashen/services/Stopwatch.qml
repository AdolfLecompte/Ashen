// Ashen — Stopwatch service.  by Adolf — github.com/AdolfLecompte
pragma Singleton
import Quickshell
import QtQuick

// Lives out here rather than in the clock panel on purpose: a stopwatch that
// resets the moment you close the panel is a toy. Start it, go away, come back.
//
// Time is read off the wall clock, never accumulated tick by tick — a 100 ms
// Timer that fires late (and it will) would quietly lose seconds over an hour.
// The ticker only exists to repaint; `elapsed` is always a subtraction.
Singleton {
    id: root

    property bool running: false
    // Wall-clock ms when the current run began
    property double startedAt: 0
    // Everything banked by previous runs, so pause/resume survives
    property double banked: 0
    property var laps: []

    // Bumped by the ticker purely to invalidate the binding below
    property int tick: 0

    readonly property double elapsed: {
        tick  // dependency: without this the readout freezes between runs
        return banked + (running ? Date.now() - startedAt : 0)
    }

    // "12:34.5" — hours only appear once there are hours to show
    function format(ms) {
        let t = Math.max(0, Math.floor(ms))
        let tenths = Math.floor(t / 100) % 10
        let s = Math.floor(t / 1000) % 60
        let m = Math.floor(t / 60000) % 60
        let h = Math.floor(t / 3600000)
        let two = n => (n < 10 ? "0" : "") + n
        let head = h > 0 ? h + ":" + two(m) : String(m)
        return head + ":" + two(s) + "." + tenths
    }

    readonly property string display: format(elapsed)
    readonly property bool idle: !running && elapsed === 0

    function start() {
        if (running) return
        startedAt = Date.now()
        running = true
    }
    function pause() {
        if (!running) return
        banked += Date.now() - startedAt
        running = false
    }
    function toggle() { running ? pause() : start() }
    function reset() {
        running = false
        banked = 0
        startedAt = 0
        laps = []
    }
    // Each lap keeps both its own split and the total it was taken at
    function lap() {
        if (elapsed === 0) return
        let list = laps.slice()
        let prev = list.length > 0 ? list[list.length - 1].total : 0
        list.push({ index: list.length + 1, total: elapsed, split: elapsed - prev })
        laps = list
    }

    Timer {
        interval: 100
        repeat: true
        running: root.running
        onTriggered: root.tick++
    }
}
