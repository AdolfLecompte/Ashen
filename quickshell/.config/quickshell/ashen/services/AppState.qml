pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

import "root:/services" as Services

Singleton {
    id: root

    // Prefs may already be loaded by the time this singleton is built, in which
    // case onLoadedChanged never fires — so try the restore here too.
    Component.onCompleted: {
        recordingCheckProc.running = true
        root.restoreQuickToggles()
    }

    Process {
        id: recordingCheckProc
        command: ["sh", "-c", "PID=$(cat \"$HOME\"/.cache/ashen_recording.pid 2>/dev/null); if [ -n \"$PID\" ] && kill -0 \"$PID\" 2>/dev/null; then cat \"$HOME\"/.cache/ashen_recording_start 2>/dev/null; else rm -f \"$HOME\"/.cache/ashen_recording.pid \"$HOME\"/.cache/ashen_recording_start; fi"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                let t = text.trim()
                if (t.length > 0) {
                    let startMs = parseFloat(t)
                    if (!isNaN(startMs)) {
                        root.recording = true
                        root.recordingStartTime = startMs
                    }
                }
            }
        }
    }
    // Screen recording: the pid/start files are the source of truth, so a
    // shell restart picks an ongoing recording back up (recordingCheckProc).
    function startRecording() {
        let startMs = Date.now()
        // Settings > Sound > Screen Recording may point somewhere else
        let dir = Prefs.recordDir !== "" ? Prefs.recordDir : Paths.recordings
        let path = dir + "/ashen_" + startMs + ".mp4"
        // Desktop audio is opt-out: the sink monitor is what makes a recording
        // of a video usable, but a silent capture must stay possible.
        let audio = Prefs.recordAudio ? " --audio=\"$(pactl get-default-sink).monitor\"" : ""
        Quickshell.execDetached(["sh", "-c",
            "mkdir -p '" + dir + "'; wf-recorder" + audio + " -c libx264 -x yuv420p -p color_range=tv -p colorspace=bt709 -p color_primaries=bt709 -p color_trc=bt709 -f '" + path + "' & echo $! > \"$HOME\"/.cache/ashen_recording.pid; echo " + startMs + " > \"$HOME\"/.cache/ashen_recording_start"
        ])
        root.recording = true
        root.recordingStartTime = startMs
    }
    function stopRecording() {
        Quickshell.execDetached(["sh", "-c",
            "PID=$(cat \"$HOME\"/.cache/ashen_recording.pid 2>/dev/null); [ -n \"$PID\" ] && kill -INT \"$PID\"; rm -f \"$HOME\"/.cache/ashen_recording.pid \"$HOME\"/.cache/ashen_recording_start"
        ])
        root.recording = false
    }
    function toggleRecording() {
        if (root.recording) root.stopRecording()
        else root.startRecording()
    }

    property bool clipboardVisible: false

    property var bigOverlays: ["launcherVisible", "settingsVisible", "wallpaperVisible", "clipboardVisible", "processVisible", "utilitiesVisible"]
    // Reactive read of a panel's own flag by name, for anything driven from
    // the pill catalogue rather than wired to one panel.
    function overlayOpen(name) { return name !== "" && root[name] === true }

    function toggleOverlay(name) {
        let wasOpen = root[name]
        for (let n of bigOverlays) root[n] = false
        root[name] = !wasOpen
    }
    function closeBigOverlays() {
        for (let n of bigOverlays) root[n] = false
    }
    // Asked for by anything in-process that wants the session locked, so it
    // does not have to shell out to `qs ipc call lockscreen lock`. The lock
    // surface listens; nothing else needs to know it exists.
    signal lockRequested()

    property bool recording: false
    property real recordingStartTime: 0
    // How long it has been running, as mm:ss. Here rather than in the pill:
    // the pill is a control and can be taken off the bar, but the recording
    // carries on, and whatever is showing it then needs the same number.
    property string recordingElapsed: "00:00"
    Timer {
        interval: 1000
        running: root.recording
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            const secs = Math.max(0, Math.floor((Date.now() - root.recordingStartTime) / 1000))
            const m = Math.floor(secs / 60)
            const s = secs % 60
            root.recordingElapsed = (m < 10 ? "0" + m : m) + ":" + (s < 10 ? "0" + s : s)
        }
    }
    property bool keepAwake: false
    property real faceVersion: 0

    // Identity, resolved once at startup: nothing here may be hardcoded, the
    // shell has to follow a rename of the user or the host.
    property string userName: ""
    property string hostName: ""
    property string homeDir: ""
    readonly property string userLabel: userName === "" ? "" : userName + "@" + hostName
    // faceVersion busts Qt's image cache: the path never changes, the file does
    readonly property string facePath: homeDir === ""
        ? "" : "file://" + homeDir + "/.face?" + faceVersion

    Process {
        id: identityProc
        command: ["sh", "-c", "echo \"$(id -un)|$(hostnamectl hostname 2>/dev/null || hostname)|$HOME\""]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                let p = text.trim().split("|")
                if (p.length < 3 || p[0] === "") return
                root.userName = p[0]
                root.hostName = p[1]
                root.homeDir = p[2]
            }
        }
    }
    property bool doNotDisturb: false

    // ── Quick toggles that outlive a restart ──────────────────────────────
    // The live value stays here (everything reads AppState), Prefs only holds
    // the seed. Prefs loads async, so restoring before `loaded` would hand back
    // the default and write that default straight over the saved one.
    property bool prefsRestored: false
    function restoreQuickToggles() {
        if (root.prefsRestored || !Prefs.loaded) return
        // Set first: the change handlers below key on it to tell a restore from
        // a user flip.
        root.prefsRestored = true
        root.doNotDisturb = Prefs.doNotDisturb
        root.keepAwake = Prefs.keepAwake
    }
    Connections {
        target: Prefs
        function onLoadedChanged() { root.restoreQuickToggles() }
    }
    onDoNotDisturbChanged: if (root.prefsRestored) Prefs.doNotDisturb = root.doNotDisturb
    // hypridle is what actually blanks the screen, so the toggle has to reach it
    // no matter where it was flipped (settings, launcher, IPC) — and again when
    // a restart restores it. Only fires once the seed is in: at startup hypridle
    // is already running, and re-launching it would leave two instances.
    onKeepAwakeChanged: {
        if (!root.prefsRestored) return
        Prefs.keepAwake = root.keepAwake
        if (root.keepAwake) Quickshell.execDetached(["sh", "-c", "pkill -9 hypridle"])
        else Idle.start()   // restarts it against the generated config
    }

    property bool settingsVisible: false
    property string settingsTab: "system"
    property bool notificationsVisible: false
    property real volumePillCenterX: 400
    property real brightnessPillCenterX: 460
    property real batteryPillCenterX: 520
    // Vertical twins, used when the bar sits on a side edge
    property real volumePillCenterY: 60
    property real brightnessPillCenterY: 60
    property real batteryPillCenterY: 60
    property real mediaPillCenterY: 60
    property real networkPillCenterY: 60
    property real bluetoothPillCenterY: 60
    property real usbPillCenterY: 60
    property real clockPillCenterX: 960
    property real clockPillCenterY: 60
    property real notificationPillCenterX: 80
    property real notificationPillCenterY: 60
    property bool volumeVisible: false
    property bool brightnessVisible: false
    property bool batteryVisible: false
    property real mediaPillCenterX: 200
    // Media pill footprint, published by the pill itself: MediaPanel morphs out
    // of this exact rect instead of just scaling from its centre point.
    property real mediaPillW: 200
    property real mediaPillH: 44

    // Same story for the clock pill: the calendar panel morphs out of it
    property real clockPillW: 200
    property real clockPillH: 44
    property bool mediaVisible: false
    // True from the frame the morph actually starts drawing (a layer surface is
    // mapped a few frames after the flag flips) until it is home again. The
    // pill hides off this, not off mediaVisible, so the handover has no gap.
    property bool mediaMorphing: false
    property bool clockMorphing: false

    // ── Workspace hover preview ─────────────────────────────────────────
    // Only one chip can be previewed at a time, so one set of fields covers
    // every workspace instead of a pair per chip. 0 = nothing showing.
    property int wsPreviewId: 0
    property string wsPreviewLabel: ""
    property real wsPreviewX: 0
    property real wsPreviewY: 0
    property real wsPreviewW: 32
    property real wsPreviewH: 32
    property bool wsPreviewMorphing: false

    function setWsPreview(id, label, x, y, w, h) {
        root.wsPreviewLabel = label
        root.wsPreviewX = x
        root.wsPreviewY = y
        root.wsPreviewW = w
        root.wsPreviewH = h
        root.wsPreviewId = id
    }
    property bool powerMenuVisible: false
    property bool calendarVisible: false
    property bool networkVisible: false
    property real volumePillW: 44
    property real volumePillH: 32
    property real brightnessPillW: 44
    property real brightnessPillH: 32
    property real batteryPillW: 44
    property real batteryPillH: 32
    property real usbPillW: 44
    property real usbPillH: 32
    property real networkPillW: 44
    property real networkPillH: 32
    property real bluetoothPillW: 44
    property real bluetoothPillH: 32
    property real networkPillCenterX: 700
    property bool bluetoothVisible: false
    property real powerPillCenterX: 1800
    property real powerPillCenterY: 28
    property real powerPillW: 44
    property real powerPillH: 44
    property real bluetoothPillCenterX: 760
    property bool usbVisible: false
    property real usbPillCenterX: 500
    // DBusMenuHandle of the tray item whose menu is open (null = none)
    property var trayMenuHandle: null
    property bool trayMenuVisible: false
    // Written by PillCenter reporters in the bar
    // What each chip is showing right now, so the panel falling out of it can
    // wear the same face for the first few frames of the drop. Replaced whole
    // rather than mutated: a map edited in place emits no change signal.
    property var pillFaces: ({})
    function setPillFace(key, glyph, label) {
        const f = pillFaces[key]
        if (f && f.glyph === glyph && f.label === label)
            return
        const next = Object.assign({}, pillFaces)
        next[key] = { glyph: glyph, label: label }
        root.pillFaces = next
    }
    function pillGlyph(key) { const f = pillFaces[key]; return f ? f.glyph : "" }
    function pillLabel(key) { const f = pillFaces[key]; return f ? f.label : "" }

    function setPillSize(key, w, h) {
        if (key === "network")        { root.networkPillW = w;   root.networkPillH = h }
        else if (key === "bluetooth") { root.bluetoothPillW = w; root.bluetoothPillH = h }
        else if (key === "media")     { root.mediaPillW = w;     root.mediaPillH = h }
        else if (key === "clock")     { root.clockPillW = w;     root.clockPillH = h }
        else if (key === "volume")     { root.volumePillW = w;     root.volumePillH = h }
        else if (key === "brightness") { root.brightnessPillW = w; root.brightnessPillH = h }
        else if (key === "battery")    { root.batteryPillW = w;    root.batteryPillH = h }
        else if (key === "usb")        { root.usbPillW = w;        root.usbPillH = h }
        else if (key === "power")      { root.powerPillW = w;      root.powerPillH = h }
        else if (key === "process")    { root.processPillW = w;    root.processPillH = h }
        else if (key === "settings")   { root.settingsPillW = w;   root.settingsPillH = h }
        else if (key === "clipboard")  { root.clipboardPillW = w;  root.clipboardPillH = h }
    }

    // A chip on the utility pill publishes itself the same way a bar pill
    // does, so a panel reads one set of numbers whichever place its chip is
    // living in today.
    function setChipRect(key, cx, cy, w, h, edge) {
        if (key === "process")        { root.processPillCX = cx;   root.processPillCY = cy
                                        root.processPillW = w;     root.processPillH = h
                                        root.processSourceEdge = edge }
        else if (key === "settings")  { root.settingsPillCX = cx;  root.settingsPillCY = cy
                                        root.settingsPillW = w;    root.settingsPillH = h
                                        root.settingsSourceEdge = edge }
        else if (key === "clipboard") { root.clipboardPillCX = cx; root.clipboardPillCY = cy
                                        root.clipboardPillW = w;   root.clipboardPillH = h
                                        root.clipboardSourceEdge = edge }
        else { root.setPillCenter(key, cx, cy); root.setPillSize(key, w, h) }
    }

    // Where a tool's chip is: an edge name while it lives on the utility pill,
    // "" once it has been moved onto the bar.
    function setChipEdge(key, edge) {
        if (key === "process") root.processSourceEdge = edge
        else if (key === "settings") root.settingsSourceEdge = edge
        else if (key === "clipboard") root.clipboardSourceEdge = edge
    }
    function chipEdgeOf(key) {
        if (key === "process") return root.processSourceEdge
        if (key === "settings") return root.settingsSourceEdge
        if (key === "clipboard") return root.clipboardSourceEdge
        return ""
    }

    function setPillCenter(key, x, y) {
        if (key === "volume")            { root.volumePillCenterX = x;        root.volumePillCenterY = y }
        else if (key === "brightness")   { root.brightnessPillCenterX = x;    root.brightnessPillCenterY = y }
        else if (key === "battery")      { root.batteryPillCenterX = x;       root.batteryPillCenterY = y }
        else if (key === "media")        { root.mediaPillCenterX = x;         root.mediaPillCenterY = y }
        else if (key === "network")      { root.networkPillCenterX = x;       root.networkPillCenterY = y }
        else if (key === "bluetooth")    { root.bluetoothPillCenterX = x;     root.bluetoothPillCenterY = y }
        else if (key === "usb")          { root.usbPillCenterX = x;           root.usbPillCenterY = y }
        else if (key === "clock")        { root.clockPillCenterX = x;         root.clockPillCenterY = y }
        else if (key === "notification") { root.notificationPillCenterX = x;  root.notificationPillCenterY = y }
        else if (key === "power")        { root.powerPillCenterX = x;         root.powerPillCenterY = y }
        else if (key === "process")      { root.processPillCX = x;            root.processPillCY = y }
        else if (key === "settings")     { root.settingsPillCX = x;           root.settingsPillCY = y }
        else if (key === "clipboard")    { root.clipboardPillCX = x;          root.clipboardPillCY = y }
    }

    property real trayMenuCenterX: 900
    property real trayMenuCenterY: 60
    function openTrayMenu(item, centerX, centerY) {
        if (root.trayMenuVisible && root.trayMenuHandle === item.menu) {
            root.closeTrayMenu()
            return
        }
        root.trayMenuHandle = item.menu
        root.trayMenuCenterX = centerX
        root.trayMenuCenterY = centerY !== undefined ? centerY : root.trayMenuCenterY
        root.trayMenuVisible = true
    }
    function closeTrayMenu() {
        root.trayMenuVisible = false
        root.trayMenuHandle = null
    }
    property bool launcherVisible: false
    property bool processVisible: false
    // Where the utility pill's Process chip was when it was clicked, so the
    // panel can grow out of it the way the media pill becomes the media
    // panel. Published by UtilityTriggers at click time -- the chip only
    // reacts to clicks while its pill is fully revealed, so the geometry read
    // there is always settled, never mid-animation.
    property real processPillCX: 0
    property real processPillCY: 0
    property real processPillW: 124
    property real processPillH: 44
    // Which screen edge that chip was on: the pill can turn up on any of the
    // three the bar is not currently sitting on.
    property string processSourceEdge: "bottom"

    // Same four numbers for the clipboard chip on the same pill. A set each
    // rather than one shared set: both panels can be mid-animation at once
    // (one closing while the other opens) and they would fight over it.
    property real clipboardPillCX: 0
    property real clipboardPillCY: 0
    property real clipboardPillW: 44
    property real clipboardPillH: 44
    property string clipboardSourceEdge: "bottom"


    // Settings joins the other two on the utility pill.
    property real settingsPillCX: 0
    property real settingsPillCY: 0
    property real settingsPillW: 44
    property real settingsPillH: 44
    property string settingsSourceEdge: "bottom"

    // The utility drawer: everything the launcher used to hide behind ">".
    // The launcher is for applications; this is for the shell's own actions.
    // Where every utility chip sits, keyed "edge|id". Published continuously by
    // the pill rather than written on click: a panel thrown by a keybind was
    // never told where to grow from, so it used whatever the last click had
    // left behind -- or (0, 0), the top-left corner of the screen.
    property var utilChip: ({})
    function setUtilChip(edge, id, cx, cy, w, h) {
        const k = edge + "|" + id
        const o = utilChip[k]
        if (o && o.cx === cx && o.cy === cy && o.w === w && o.h === h) return
        const next = Object.assign({}, utilChip)
        next[k] = { cx: cx, cy: cy, w: w, h: h }
        root.utilChip = next
    }
    // Falls back to the middle of the edge, so a panel whose chip has not been
    // laid out yet still leaves from the right side of the screen.
    function utilChipOf(edge, id) {
        return utilChip[edge + "|" + id] || null
    }

    // Where a panel should grow from, wherever its chip happens to live: the
    // utility pill on that edge, or the bar. Published continuously by both,
    // so a panel opened by keybind knows its origin without anyone clicking.
    function chipRectOf(key, edge) {
        if (edge !== "") {
            const c = root.utilChipOf(edge, key)
            if (c) return c
        }
        if (key === "process")   return { cx: root.processPillCX,   cy: root.processPillCY,
                                          w: root.processPillW,     h: root.processPillH }
        if (key === "settings")  return { cx: root.settingsPillCX,  cy: root.settingsPillCY,
                                          w: root.settingsPillW,    h: root.settingsPillH }
        if (key === "clipboard") return { cx: root.clipboardPillCX, cy: root.clipboardPillCY,
                                          w: root.clipboardPillW,   h: root.clipboardPillH }
        return { cx: 0, cy: 0, w: 44, h: 44 }
    }

    // Which utility pill is pinned out, by edge ("" = none). One pill, not all
    // three: pinning the bottom one should not drag the side ones out with it.
    property string utilityPinnedEdge: ""

    property bool utilitiesVisible: false
    property real utilitiesPillCX: 0
    property real utilitiesPillCY: 0
    property real utilitiesPillW: 32
    property real utilitiesPillH: 32
    property string utilitiesSourceEdge: "bottom"
    // The button stands down while the panel wears its face.
    property bool processTakenOver: false
    property bool wallpaperVisible: false
    property string networkTab: "wifi"
}
