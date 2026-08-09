// Ashen — monitor layout (Settings > Display).  by Adolf — github.com/AdolfLecompte
pragma Singleton
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick

// Reads the real monitor state from Hyprland, keeps the user's arrangement in
// Prefs, and applies it with hyprctl. Nothing is written to the repo's
// monitors.lua: a screen layout is per-machine, and that file is a stow symlink
// into someone's checkout. Ashen re-applies its own copy on startup instead,
// the same way the keyboard layout is restored.
Singleton {
    id: root

    // ── What Hyprland says is out there ──────────────────────────────────
    // Every monitor, DISABLED ONES INCLUDED -- `hyprctl -j monitors` alone
    // hides them, and those are exactly the ones you need to turn back on.
    property var monitors: []
    property bool probed: false

    function refresh() { probe.running = true }

    Process {
        id: probe
        running: true
        command: ["hyprctl", "-j", "monitors", "all"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.monitors = JSON.parse(text)
                    root.probed = true
                } catch (e) {
                    // A half-written socket read is not worth clearing the list
                    // for: the next event asks again.
                }
            }
        }
    }

    // Monitors come and go while the shell is up. The Hyprland singleton talks
    // the event socket, so it is the reliable trigger; the binary is only how
    // we read the detail it does not carry.
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            const n = event.name
            if (n === "monitoradded" || n === "monitorremoved" || n === "monitoraddedv2")
                settle.restart()
        }
    }
    Timer {
        id: settle
        // Hyprland announces the monitor before it has finished configuring it.
        interval: 300
        onTriggered: root.refresh()
    }

    // ── Identity ─────────────────────────────────────────────────────────
    // A monitor is its DESCRIPTION, never its name: HDMI-A-1 is handed out by
    // port order and moves between reboots, so a layout keyed by name ends up
    // on the wrong screen. Hyprland takes `desc:` wherever it takes an output.
    //
    // Not everything HAS one, though -- a headless output made for testing
    // reports an empty description -- and `desc:` with nothing after it matches
    // nothing at all. Those fall back to the name, which is the only handle
    // they have.
    function keyOf(m) {
        if (!m) return ""
        return m.description && m.description !== "" ? m.description : m.name
    }
    function outputOf(m) {
        if (!m) return ""
        return m.description && m.description !== "" ? "desc:" + m.description : m.name
    }

    function byName(name) {
        for (const m of root.monitors) if (m.name === name) return m
        return null
    }
    function byKey(key) {
        for (const m of root.monitors) if (root.keyOf(m) === key) return m
        return null
    }

    // The one the grid puts in the middle: the machine's own panel. eDP and
    // LVDS are the two names a built-in display ever gets.
    readonly property string primaryKey: {
        for (const m of root.monitors)
            if (m.name.startsWith("eDP") || m.name.startsWith("LVDS"))
                return root.keyOf(m)
        return root.monitors.length > 0 ? root.keyOf(root.monitors[0]) : ""
    }

    // ── The saved arrangement ────────────────────────────────────────────
    // ONE string of JSON in Prefs, not a field per monitor: the JsonAdapter
    // drops sibling writes made in the same tick, which is the same reason
    // barLayout and weatherLoc are packed.
    readonly property var layout: {
        try {
            return Prefs.displayLayout === "" ? ({}) : JSON.parse(Prefs.displayLayout)
        } catch (e) {
            return ({})
        }
    }

    // What a monitor gets when it has never been arranged: where it already is.
    function defaults(m) {
        return {
            cell: root.keyOf(m) === root.primaryKey ? 4 : -1,
            mode: "preferred",
            scale: m && m.scale ? m.scale : 1,
            transform: m && m.transform ? m.transform : 0,
            disabled: m ? !!m.disabled : false,
            mirror: "",
            ws: [],
            defaultWs: 0
        }
    }

    function entry(key) {
        const saved = root.layout[key]
        const m = root.byKey(key)
        const d = root.defaults(m)
        if (!saved) return d
        return {
            cell:      saved.cell      !== undefined ? saved.cell      : d.cell,
            mode:      saved.mode      !== undefined ? saved.mode      : d.mode,
            scale:     saved.scale     !== undefined ? saved.scale     : d.scale,
            transform: saved.transform !== undefined ? saved.transform : d.transform,
            disabled:  saved.disabled  !== undefined ? saved.disabled  : d.disabled,
            mirror:    saved.mirror    !== undefined ? saved.mirror    : d.mirror,
            ws:        saved.ws        !== undefined ? saved.ws        : d.ws,
            defaultWs: saved.defaultWs !== undefined ? saved.defaultWs : d.defaultWs
        }
    }

    // Merge a patch into what was SAVED, never onto `entry()`. `entry()` fills
    // its gaps from the monitor's live state, so merging onto it freezes the
    // rotation and scale Hyprland happened to be showing at that instant into
    // settings the user never touched -- a drag across the board once wrote a
    // 90 degree rotation nobody asked for. Only chosen fields are stored; the
    // rest stay absent and keep being read live.
    function setEntry(key, patch) {
        const next = Object.assign({}, root.layout)
        next[key] = Object.assign({}, next[key] || {}, patch)
        Prefs.displayLayout = JSON.stringify(next)
    }

    // Two monitors cannot share a cell; the one already there takes the vacated
    // one, so a drag is always a swap and never silently stacks them.
    function moveToCell(key, cell) {
        const next = Object.assign({}, root.layout)
        const wasAt = root.entry(key).cell
        for (const k in next) {
            if (k !== key && next[k] && next[k].cell === cell)
                next[k] = Object.assign({}, next[k], { cell: wasAt })
        }
        next[key] = Object.assign({}, next[key] || {}, { cell: cell })
        Prefs.displayLayout = JSON.stringify(next)
    }

    // ── Geometry ─────────────────────────────────────────────────────────
    // Hyprland positions in LOGICAL pixels: the mode divided by the scale, and
    // with the axes swapped when the screen is turned on its side.
    function modeSize(m, e) {
        let w = m ? m.width : 0
        let h = m ? m.height : 0
        if (e.mode !== "preferred") {
            const mm = e.mode.match(/^(\d+)x(\d+)/)
            if (mm) { w = parseInt(mm[1]); h = parseInt(mm[2]) }
        }
        return { w: w, h: h }
    }
    function logicalSize(m, e) {
        const s = root.modeSize(m, e)
        const sc = e.scale > 0 ? e.scale : 1
        const w = Math.round(s.w / sc)
        const h = Math.round(s.h / sc)
        const turned = e.transform === 1 || e.transform === 3
        return { w: turned ? h : w, h: turned ? w : h }
    }

    // Cell 0..8 of the 3x3 grid to an absolute position. The centre monitor is
    // the origin and everything else is glued to its edge: Hyprland allows gaps
    // between monitors, but a gap is a strip the cursor cannot cross.
    // "auto" for a screen with no slot yet: it has not been arranged, so
    // Hyprland goes on laying it out. Handing those "0x0" stacks them on top of
    // the centre monitor -- two screens at the same origin, showing the same
    // pixels, which looks exactly like a mirror nobody asked for.
    function positionFor(key) {
        const e = root.entry(key)
        const m = root.byKey(key)
        if (!m || e.cell < 0 || e.cell > 8) return "auto"
        if (e.cell === 4) return "0x0"

        const centre = root.byKey(root.primaryKey)
        const cSize = centre ? root.logicalSize(centre, root.entry(root.primaryKey)) : { w: 0, h: 0 }
        const size = root.logicalSize(m, e)

        const dc = (e.cell % 3) - 1
        const dr = Math.floor(e.cell / 3) - 1
        const x = dc < 0 ? -size.w : (dc > 0 ? cSize.w : 0)
        const y = dr < 0 ? -size.h : (dr > 0 ? cSize.h : 0)
        return x + "x" + y
    }

    // Hyprland refuses a scale whose buffer is not a whole number of pixels, so
    // only the ones that divide cleanly are ever offered.
    readonly property var scaleLadder: [1, 1.25, 1.333333, 1.5, 1.75, 2, 2.5, 3]
    function validScales(w, h) {
        const out = []
        for (const s of root.scaleLadder) {
            const bw = w / s, bh = h / s
            if (Math.abs(bw - Math.round(bw)) < 0.001 && Math.abs(bh - Math.round(bh)) < 0.001)
                out.push(s)
        }
        return out.length > 0 ? out : [1]
    }

    // ── Applying ─────────────────────────────────────────────────────────
    // hyprctl keyword is dead on a Lua config ("can't work with non-legacy
    // parsers"); everything goes through eval. `mirror` MUST be written even
    // when empty -- leaving the key out merges with what was there before, so
    // an omitted mirror never comes off.
    function specFor(key) {
        const m = root.byKey(key)
        if (!m) return ""
        const e = root.entry(key)
        const out = root.outputOf(m)
        if (e.disabled)
            return 'hl.monitor({output="' + out + '", disabled=true});'

        let s = 'hl.monitor({output="' + out + '"'
        s += ', mode="' + (e.mode === "preferred" ? "preferred" : e.mode) + '"'
        s += ', scale=' + e.scale
        s += ', transform=' + e.transform
        if (e.mirror !== "") {
            // A mirrored output has no geometry of its own: it stops being a
            // wl_output at all, so position and rotation mean nothing here.
            // The target goes through outputOf as well -- a monitor with no
            // description is named plainly, and `desc:` on it matches nothing.
            s += ', mirror="' + root.outputOf(root.byKey(e.mirror)) + '"'
            s += ', position="auto"'
        } else {
            s += ', mirror=""'
            s += ', position="' + root.positionFor(key) + '"'
        }
        return s + ', disabled=false});'
    }

    // ── Which workspaces belong to which screen ──────────────────────────
    // A workspace lives on exactly one monitor, so claiming it here gives it up
    // everywhere else.
    function assignWorkspace(key, n, on) {
        const next = Object.assign({}, root.layout)
        for (const k in next) {
            if (!next[k] || !next[k].ws) continue
            next[k] = Object.assign({}, next[k], { ws: next[k].ws.filter(w => w !== n) })
            if (next[k].defaultWs === n) next[k].defaultWs = 0
        }
        // Saved record only, for the same reason setEntry uses one.
        const mine = Object.assign({}, next[key] || {})
        const list = (mine.ws || []).filter(w => w !== n)
        if (on) list.push(n)
        list.sort((a, b) => a - b)
        mine.ws = list
        if (mine.defaultWs === n && !on) mine.defaultWs = 0
        if (on && mine.defaultWs === 0) mine.defaultWs = list[0]
        next[key] = mine
        Prefs.displayLayout = JSON.stringify(next)
    }

    function ownerOf(n) {
        for (const k in root.layout) {
            const e = root.layout[k]
            if (e && e.ws && e.ws.indexOf(n) >= 0) return k
        }
        return ""
    }

    // A rule says where a workspace is BORN, which is why an existing one does
    // not move when the rule changes -- measured, not assumed. Empty ones are
    // destroyed the moment they lose focus and come back in the right place;
    // only the ones holding windows have to be pushed by hand.
    function occupied(id) {
        for (const t of Hyprland.toplevels.values)
            if (t.workspace && t.workspace.id === id) return true
        return false
    }

    function workspaceChunk() {
        let rules = ""
        let moves = ""
        for (const m of root.monitors) {
            const k = root.keyOf(m)
            const e = root.entry(k)
            // A mirror is not a place windows can go, and neither is a screen
            // that is switched off.
            if (e.mirror !== "" || e.disabled) continue
            const out = root.outputOf(m)
            for (const w of (e.ws || [])) {
                rules += 'hl.workspace_rule({workspace="' + w + '", monitor="' + out + '"'
                       + (w === e.defaultWs ? ', default=true' : '') + '});'
                if (root.occupied(w))
                    moves += 'hl.dispatch(hl.dsp.workspace.move({workspace=' + w
                           + ', monitor="' + out + '"}));'
            }
        }
        return rules + moves
    }

    function applyAll() {
        let chunk = ""
        // The centre goes down first: everything else is positioned against it.
        if (root.primaryKey !== "") chunk += root.specFor(root.primaryKey)
        for (const m of root.monitors) {
            const k = root.keyOf(m)
            if (k !== root.primaryKey) chunk += root.specFor(k)
        }
        // Workspaces last: a rule pointing at a screen that is not up yet has
        // nowhere to put anything.
        chunk += root.workspaceChunk()
        if (chunk === "") return
        Quickshell.execDetached(["hyprctl", "eval", chunk])
        settle.restart()
    }

    // ── Not getting locked out ───────────────────────────────────────────
    // A mode the panel cannot show leaves a black screen with the dialog on it.
    // The arrangement in force is saved before anything changes and comes back
    // on its own unless someone says it worked.
    property string pending: ""
    property int countdown: 0
    readonly property bool awaitingConfirm: root.pending !== ""
    // The last arrangement that was PUT ON SCREEN and lived. Not the same thing
    // as what is in Prefs: the editor writes every change straight there, so by
    // the time Apply is pressed Prefs already holds the layout being tried out.
    // Snapshotting Prefs here would make the revert restore the very thing it
    // is meant to undo -- the lock-out guard would have guarded nothing.
    property string lastGood: ""

    function applyWithRevert() {
        root.pending = root.lastGood
        root.applyAll()
        root.countdown = 10
        revertTimer.start()
    }
    function confirm() {
        revertTimer.stop()
        root.lastGood = Prefs.displayLayout
        root.pending = ""
        root.countdown = 0
    }
    function revert() {
        revertTimer.stop()
        Prefs.displayLayout = root.pending
        root.pending = ""
        root.countdown = 0
        root.applyAll()
    }
    Timer {
        id: revertTimer
        interval: 1000
        repeat: true
        onTriggered: {
            root.countdown -= 1
            if (root.countdown <= 0) root.revert()
        }
    }

    // ── Startup and reload ───────────────────────────────────────────────
    // Applying before the prefs are in would push the defaults over the saved
    // arrangement, so this waits the same way Idle does.
    property bool ready: false
    function arm() {
        if (root.ready || !Prefs.loaded || !root.probed) return
        root.ready = true
        // What is in force at startup is by definition an arrangement that
        // works: it is the one the screen is showing.
        root.lastGood = Prefs.displayLayout
        if (Prefs.displayLayout !== "") root.applyAll()
    }
    onProbedChanged: root.arm()
    Component.onCompleted: root.arm()
    Connections {
        target: Prefs
        function onLoadedChanged() { root.arm() }
    }

    // `hyprctl reload` re-reads monitors.lua and throws away everything applied
    // at runtime, this included.
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "configreloaded" && root.ready) reapply.restart()
        }
    }
    Timer {
        id: reapply
        interval: 400
        onTriggered: root.applyAll()
    }
}
