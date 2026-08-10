// Ashen — persisted user prefs (prefs.json).  by Adolf — github.com/AdolfLecompte
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
    // Legacy single weather location ("lat|lon|City"). Kept only so old prefs.json
    // still parses and Weather can migrate it into weatherLocs once. Do not write.
    property string weatherLoc: ""
    // Saved weather locations, packed into ONE field because JsonAdapter drops
    // sibling writes made in the same tick. Line 0 = active index, then one
    // "lat|lon|City" per line. Empty -> Weather geolocates by IP.
    property string weatherLocs: ""

    // FileView loads async: without gating on this, singletons that read a pref in
    // Component.onCompleted (Weather) see "" and clobber the saved value. Consumers
    // wait for loaded before acting on persisted state.
    property bool loaded: false

    // Night light (blue-light filter, driven by wlsunset via the NightLight
    // service). `Scheduled` makes it warm the screen only between From and To;
    // otherwise it holds Temp constant while enabled. Temp in kelvin (lower=warmer).
    property bool nightLightEnabled: false
    property bool nightLightScheduled: false
    property int nightLightTemp: 4000
    property string nightLightFrom: "19:00"
    property string nightLightTo: "07:00"

    // Which screen edge the bar lives on: "top", "bottom", "left" or "right".
    // Left/right make the bar vertical and every pill switches to its compact
    // stacked layout (see Sizes.barVertical).
    property string barPosition: "top"

    // Light or dark. Applies to the seven fixed schemes and to what matugen is
    // asked for when the palette comes from the wallpaper.
    property string themeMode: "dark"

    // How panels open. "morph": they come out of the capsule you pressed and
    // transform into the panel. "plain": they simply appear, like a window.
    property string panelStyle: "morph"

    // Subtle gradient on active/interactive accents (buttons, pills) when on.
    // Backgrounds never use it. See Colors.accentGradient.
    property bool useGradients: false

    // Paint the Papirus folders with the accent. The theme is built by
    // scripts/ashen-folders.sh and rebuilt whenever the accent moves; this only
    // says whether the desktop is wearing it.
    property bool accentFolders: false

    // Quick toggles that a shell restart used to reset. AppState still owns the
    // live value every consumer reads; these two are only the seed it restores
    // from and writes back to.
    property bool doNotDisturb: false
    property bool keepAwake: false

    // Bar pills the user switched off, comma separated. ONE field rather than a
    // bool per pill: JsonAdapter drops intermediate values when several
    // properties are written in the same tick (see weatherLocs above).
    property string hiddenPills: ""

    // Runtime truth, and what every binding reads. Reading `hiddenPills` back in
    // the same tick it was written returns the OLD value (the adapter batches
    // writes), so two toggles in one frame used to lose one of them.
    property var hiddenPillList: []
    function syncHiddenPills() {
        root.hiddenPillList = root.hiddenPills.split(",").filter(x => x !== "")
    }
    function pillVisible(id) {
        return root.hiddenPillList.indexOf(id) === -1
    }
    function setPillVisible(id, on) {
        let list = root.hiddenPillList.filter(x => x !== id)
        if (!on) list.push(id)
        root.hiddenPillList = list
        // Coalesced to the end of the tick: writing the string twice in one
        // frame makes the adapter keep only the first one.
        pillWriteTimer.restart()
    }
    Timer {
        id: pillWriteTimer
        interval: 0
        onTriggered: root.hiddenPills = root.hiddenPillList.join(",")
    }

    // ── Bar layout ──────────────────────────────────────────────────────
    // Which pills live in which section, and in what order. ONE packed string
    // ("left;centre;right", ids comma separated), never sibling fields: the
    // adapter drops writes made in the same tick.
    property string barLayout: ""

    // Runtime truth. Same reason as hiddenPillList: reading the string back in
    // the tick it was written returns the old value.
    property var barSections: ({ left: [], centre: [], right: [] })

    // ── Monitor layout ──────────────────────────────────────────────────
    // Settings > Display, keyed by monitor DESCRIPTION so it survives a port
    // swap. JSON in one string for the same reason barLayout is packed, and
    // because the record per monitor has eight fields. Read through
    // Services.Displays, never parsed by hand. Empty = never arranged, so
    // whatever Hyprland worked out on its own stands.
    property string displayLayout: ""

    // The arrangement the bar shipped with, used until the user moves anything.
    readonly property var defaultSections: ({
        left: ["launcher", "notifications", "workspaces", "media"],
        centre: ["usb", "clock", "recording"],
        right: ["tray", "system", "power"]
    })

    function syncBarLayout() {
        const raw = root.barLayout || ""
        if (raw === "") {
            // First run, or an upgrade from when only visibility existed: start
            // from the shipped order minus whatever was switched off back then.
            const keep = list => list.filter(id => root.pillVisible(id))
            root.barSections = {
                left: keep(root.defaultSections.left),
                centre: keep(root.defaultSections.centre),
                right: keep(root.defaultSections.right)
            }
            return
        }
        const parts = raw.split(";")
        const cut = i => (parts[i] || "").split(",").filter(x => x !== "")
        // A fourth part is a layout saved while the utility pill was
        // arrangeable; those ids belong to the pill now and are dropped.
        root.barSections = { left: cut(0), centre: cut(1), right: cut(2) }
    }

    readonly property var sectionIds: ["left", "centre", "right"]
    function barPills(section) { return root.barSections[section] || [] }

    function barSectionOf(id) {
        for (const s of root.sectionIds)
            if (root.barSections[s].indexOf(id) !== -1) return s
        return ""
    }

    // Drop `id` into `section` at `index`; section "" parks it as available.
    function moveBarPill(id, section, index) {
        let next = {}
        for (const s of root.sectionIds)
            next[s] = root.barSections[s].filter(x => x !== id)
        const placed = root.sectionIds.indexOf(section) !== -1
        if (placed) {
            const at = (index === undefined || index < 0) ? next[section].length
                     : Math.min(index, next[section].length)
            next[section].splice(at, 0, id)
        }
        root.barSections = next
        // Every pill checks pillVisible() itself, so the two have to agree.
        root.setPillVisible(id, placed)
        barWriteTimer.restart()
    }

    function resetBarLayout() {
        let next = {}
        let shipped = []
        for (const s of root.sectionIds) {
            next[s] = root.defaultSections[s].slice()
            shipped = shipped.concat(next[s])
        }
        root.barSections = next
        // Visibility comes back with them: dragging a pill out to "available"
        // hides it, and reset used to restore only the arrangement -- so a
        // parked pill returned to a slot the bar dutifully spaced for while the
        // pill itself was still switched off. That was the empty gap.
        root.hiddenPillList = root.hiddenPillList.filter(id => shipped.indexOf(id) === -1)
        pillWriteTimer.restart()
        barWriteTimer.restart()
    }

    Timer {
        id: barWriteTimer
        interval: 0
        onTriggered: root.barLayout =
            root.sectionIds.map(s => root.barSections[s].join(",")).join(";")
    }

    // Screen recording. An empty dir means "wherever Paths.recordings points".
    property bool recordAudio: true
    property string recordDir: ""

    // Where the picker looks for wallpapers. Empty means Paths.wallpapers.
    property string wallpaperDir: ""


    // Workspace chips show a glyph for whatever is open on them instead of the
    // number. Empty workspaces always keep their number.
    property bool workspaceIcons: true

    // Idle timeouts in seconds, 0 = never. The Idle service turns these into
    // hypridle.conf; nothing else may write that file.
    property int idleLockSecs: 300
    property int idleScreenOffSecs: 600
    property int idleSuspendSecs: 900

    // Lock screen: the media card is the only thing on it worth turning off.
    property bool lockShowMedia: true

    // Toasts: how long a normal one stays on screen (seconds) and how many may
    // stack before the rest collapse into the "+N" row. System toasts keep their
    // own short dwell — they are an acknowledgement, not a message.
    // A sound when something arrives. Empty file = the shipped default.
    property bool notifySound: false
    property string notifySoundFile: ""
    // Urgency 2 only, for people who want the room quiet otherwise.
    property bool notifySoundCriticalOnly: false
    // 0..1, applied to everything the shell plays.
    property real soundVolume: 0.5

    property int toastSeconds: 6
    property int maxToasts: 5

    // Active keyboard layout, by code ("latam"). switchxkblayout is runtime-only
    // and only the ORDER of kb_layout decides what login starts on. Storing the
    // pick here lets the list order stay put -- the cards must not jump around
    // under the cursor -- and the shell re-applies the choice on startup.
    property string keyboardLayout: ""

    // Every clock in the shell (bar, calendar, lock) formats through these, so
    // the three can't drift apart.
    readonly property string hourToken: clock24h ? "HH" : "hh"
    readonly property string ampmToken: clock24h ? "" : " AP"
    readonly property string timeFormat: hourToken + ":mm" + (clockSeconds ? ":ss" : "") + ampmToken

    readonly property string configDir: Paths.config

    FileView {
        id: prefsFile
        path: root.configDir + "/prefs.json"
        // Deliberately NOT watchChanges: this file has no writer but us, and
        // reload()-ing our own writeAdapter() re-reads it mid-flight and reverts
        // whatever was set a moment earlier.
        // Any write to the adapter lands on disk immediately
        onAdapterUpdated: writeAdapter()
        // File on disk is now the source of truth: let consumers act on it.
        onLoaded: { root.syncHiddenPills(); root.syncBarLayout(); root.loaded = true }
        // First run: no file yet, so seed it with the defaults above. Still
        // "loaded" -- the empty state IS the loaded state (Weather will geolocate).
        onLoadFailed: function(error) { writeAdapter(); root.syncHiddenPills(); root.syncBarLayout(); root.loaded = true }

        JsonAdapter {
            id: adapter
            property alias clockSeconds: root.clockSeconds
            property alias clock24h: root.clock24h
            property alias tempUnit: root.tempUnit
            property alias weatherLoc: root.weatherLoc
            property alias weatherLocs: root.weatherLocs
            property alias keyboardLayout: root.keyboardLayout
            property alias useGradients: root.useGradients
            property alias panelStyle: root.panelStyle
            property alias themeMode: root.themeMode
            property alias doNotDisturb: root.doNotDisturb
            property alias keepAwake: root.keepAwake
            property alias notifySound: root.notifySound
            property alias notifySoundFile: root.notifySoundFile
            property alias notifySoundCriticalOnly: root.notifySoundCriticalOnly
            property alias soundVolume: root.soundVolume
            property alias toastSeconds: root.toastSeconds
            property alias maxToasts: root.maxToasts
            property alias hiddenPills: root.hiddenPills
            property alias barLayout: root.barLayout
            property alias displayLayout: root.displayLayout
            property alias recordAudio: root.recordAudio
            property alias recordDir: root.recordDir
            property alias wallpaperDir: root.wallpaperDir
            property alias lockShowMedia: root.lockShowMedia
            property alias workspaceIcons: root.workspaceIcons
            property alias idleLockSecs: root.idleLockSecs
            property alias idleScreenOffSecs: root.idleScreenOffSecs
            property alias idleSuspendSecs: root.idleSuspendSecs
            property alias barPosition: root.barPosition
            property alias nightLightEnabled: root.nightLightEnabled
            property alias nightLightScheduled: root.nightLightScheduled
            property alias nightLightTemp: root.nightLightTemp
            property alias nightLightFrom: root.nightLightFrom
            property alias nightLightTo: root.nightLightTo
        }
    }
}
