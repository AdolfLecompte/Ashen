pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    Component.onCompleted: recordingCheckProc.running = true

    Process {
        id: recordingCheckProc
        command: ["sh", "-c", "PID=$(cat /home/adolf/.cache/ashen_recording.pid 2>/dev/null); if [ -n \"$PID\" ] && kill -0 \"$PID\" 2>/dev/null; then cat /home/adolf/.cache/ashen_recording_start 2>/dev/null; else rm -f /home/adolf/.cache/ashen_recording.pid /home/adolf/.cache/ashen_recording_start; fi"]
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
        let path = "/home/adolf/Videos/ashen_" + startMs + ".mp4"
        Quickshell.execDetached(["sh", "-c",
            "mkdir -p /home/adolf/Videos; wf-recorder --audio=\"$(pactl get-default-sink).monitor\" -f '" + path + "' & echo $! > /home/adolf/.cache/ashen_recording.pid; echo " + startMs + " > /home/adolf/.cache/ashen_recording_start"
        ])
        root.recording = true
        root.recordingStartTime = startMs
    }
    function stopRecording() {
        Quickshell.execDetached(["sh", "-c",
            "PID=$(cat /home/adolf/.cache/ashen_recording.pid 2>/dev/null); [ -n \"$PID\" ] && kill -INT \"$PID\"; rm -f /home/adolf/.cache/ashen_recording.pid /home/adolf/.cache/ashen_recording_start"
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
    property bool doNotDisturb: false
    property bool settingsVisible: false
    property string settingsTab: "general"
    property bool notificationsVisible: false
    property real volumePillCenterX: 400
    property real brightnessPillCenterX: 460
    property real batteryPillCenterX: 520
    property bool volumeVisible: false
    property bool brightnessVisible: false
    property bool batteryVisible: false
    property real mediaPillCenterX: 200
    property bool mediaVisible: false
    property bool powerMenuVisible: false
    property bool calendarVisible: false
    property bool networkVisible: false
    property bool bluetoothVisible: false
    property bool usbVisible: false
    property real usbPillCenterX: 500
    // DBusMenuHandle of the tray item whose menu is open (null = none)
    property var trayMenuHandle: null
    property bool trayMenuVisible: false
    property real trayMenuCenterX: 900
    function openTrayMenu(item, centerX) {
        if (root.trayMenuVisible && root.trayMenuHandle === item.menu) {
            root.closeTrayMenu()
            return
        }
        root.trayMenuHandle = item.menu
        root.trayMenuCenterX = centerX
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
