pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    Component.onCompleted: recordingCheckProc.running = true

    Process {
        id: recordingCheckProc
        command: ["sh", "-c", "PID=$(cat /home/adolf-arch/.cache/ashen_recording.pid 2>/dev/null); if [ -n \"$PID\" ] && kill -0 \"$PID\" 2>/dev/null; then cat /home/adolf-arch/.cache/ashen_recording_start 2>/dev/null; else rm -f /home/adolf-arch/.cache/ashen_recording.pid /home/adolf-arch/.cache/ashen_recording_start; fi"]
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
    property bool clipboardVisible: false

    property var bigOverlays: ["launcherVisible", "settingsVisible", "emojisVisible", "glyphVisible", "wallpaperVisible", "clipboardVisible"]
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
    property bool launcherVisible: false
    property bool wallpaperVisible: false
    property string networkTab: "wifi"
}
