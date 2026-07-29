pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

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

    property var bigOverlays: ["launcherVisible", "settingsVisible", "emojisVisible", "glyphVisible", "wallpaperVisible", "clipboardVisible", "processVisible"]
    function toggleOverlay(name) {
        let wasOpen = root[name]
        for (let n of bigOverlays) root[n] = false
        root[name] = !wasOpen
    }
    function closeBigOverlays() {
        for (let n of bigOverlays) root[n] = false
    }
    property bool emojisVisible: false
    property bool glyphVisible: false
    property bool recording: false
    property real recordingStartTime: 0
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
    property real networkPillCenterX: 700
    property bool bluetoothVisible: false
    property real bluetoothPillCenterX: 760
    property bool usbVisible: false
    property real usbPillCenterX: 500
    // DBusMenuHandle of the tray item whose menu is open (null = none)
    property var trayMenuHandle: null
    property bool trayMenuVisible: false
    // Written by PillCenter reporters in the bar
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
    property bool wallpaperVisible: false
    property string networkTab: "wifi"
}
