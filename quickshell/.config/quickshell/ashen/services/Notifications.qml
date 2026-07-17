pragma Singleton
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import QtQuick
import "root:/services" as Services

Singleton {
    id: root

    readonly property string historyPath: "/home/adolf/.local/state/ashen/notifications.json"

    property var history: []
    property var activePopups: []

    function pushPopup(entry) {
        let popupEntry = Object.assign({}, entry)
        root.activePopups = [popupEntry].concat(root.activePopups)
    }

    function dismissPopup(id) {
        root.activePopups = root.activePopups.filter(p => p.id !== id)
    }

    property bool lastCapsLock: false
    property bool lastNumLock: false
    property string lastPowerProfile: ""
    property bool initialized: false

    function addEntry(entry) {
        entry.id = Date.now() + "-" + Math.floor(Math.random() * 100000)
        entry.timestamp = Date.now()
        root.history = [entry].concat(root.history).slice(0, 300)
        if (!Services.AppState.doNotDisturb) {
            root.pushPopup(entry)
        }
        saveHistory()
    }

    function addSystemToast(message, glyph, isLetter, typeKey) {
        // System ones are only shown as a toast, never stored in the history.
        // Replaces any other active one of the same "type" (typeKey) instead of stacking.
        root.activePopups = root.activePopups.filter(p => !(p.source === "system" && p.typeKey === typeKey))
        let entry = {
            appName: "System",
            summary: "SYSTEM ALERT",
            body: message,
            glyph: glyph || "",
            glyphIsLetter: isLetter || false,
            typeKey: typeKey || message,
            icon: "",
            urgency: 0,
            source: "system",
            id: Date.now() + "-" + Math.floor(Math.random() * 100000),
            timestamp: Date.now()
        }
        root.pushPopup(entry)
    }

    function removeAt(index) {
        let arr = root.history.slice()
        arr.splice(index, 1)
        root.history = arr
        saveHistory()
    }

    function clearAll() {
        root.history = []
        saveHistory()
    }

    function saveHistory() {
        let json = JSON.stringify(root.history)
        let b64 = Qt.btoa(json)
        saveProc.command = ["sh", "-c", "mkdir -p /home/adolf/.local/state/ashen && echo '" + b64 + "' | base64 -d > " + root.historyPath]
        saveProc.running = true
    }

    Component.onCompleted: loadProc.running = true

    Process {
        id: loadProc
        command: ["sh", "-c", "cat " + root.historyPath + " 2>/dev/null || echo '[]'"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let parsed = JSON.parse(text.trim() || "[]")
                    root.history = Array.isArray(parsed) ? parsed : []
                } catch (e) {
                    root.history = []
                }
                root.initialized = true
            }
        }
    }

    Process {
        id: saveProc
        running: false
    }

    // --- Real D-Bus notification server (org.freedesktop.Notifications) ---
    NotificationServer {
        id: notifServer
        bodySupported: true
        imageSupported: true
        keepOnReload: true

        // Chromium queries GetCapabilities on startup and refuses the D-Bus
        // route unless the server advertises actions and persistence, falling
        // back to its own in-window message center. Brave notifications
        // (WhatsApp Web) depend on these two being advertised.
        actionsSupported: true
        persistenceSupported: true

        onNotification: notification => {
            notification.tracked = true
            root.addEntry({
                appName: notification.appName || "Unknown",
                summary: notification.summary || "",
                body: notification.body || "",
                icon: notification.appIcon || "",
                urgency: notification.urgency,
                source: "app"
            })
        }
    }

    // --- Caps Lock / Num Lock (poll via hyprctl -j devices) ---
    Process {
        id: kbStateProc
        command: ["sh", "-c", "hyprctl -j devices"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let data = JSON.parse(text)
                    let kb = data.keyboards && data.keyboards.find(k => k.main) || (data.keyboards ? data.keyboards[0] : null)
                    if (!kb) return
                    if (root.initialized) {
                        if (kb.capsLock !== root.lastCapsLock) {
                            root.addSystemToast(kb.capsLock ? "CAPS LOCK ON" : "CAPS LOCK OFF", "", false, "capslock")
                        }
                        if (kb.numLock !== root.lastNumLock) {
                            root.addSystemToast(kb.numLock ? "NUM LOCK ON" : "NUM LOCK OFF", "\uf2af", false, "numlock")
                        }
                    }
                    root.lastCapsLock = kb.capsLock
                    root.lastNumLock = kb.numLock
                } catch (e) {}
            }
        }
    }

    Timer {
        interval: 500
        running: true
        repeat: true
        onTriggered: kbStateProc.running = true
    }

    // --- Power profile changes (powerprofilesctl monitor, streaming) ---
    // --- Cargador conectado/desconectado ---
    property bool lastCharging: false
    Process {
        id: chargerProc
        command: ["sh", "-c", "cat /sys/class/power_supply/AC0/online 2>/dev/null || cat /sys/class/power_supply/ADP1/online 2>/dev/null || echo ''"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                let val = text.trim()
                if (val === "") return
                let charging = val === "1"
                if (root.initialized && charging !== root.lastCharging) {
                    root.addSystemToast(charging ? "CHARGER CONNECTED" : "CHARGER DISCONNECTED", charging ? "" : "", false, "charger")
                }
                root.lastCharging = charging
            }
        }
    }
    Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: chargerProc.running = true
    }

    Process {
        id: profileMonitor
        command: ["sh", "-c", "powerprofilesctl monitor"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                let line = data.trim()
                if (line.length === 0) return
                if (root.initialized && root.lastPowerProfile !== "" && line !== root.lastPowerProfile) {
                    let profIcon = line.indexOf("saver") !== -1 ? ""
                        : line.indexOf("performance") !== -1 ? ""
                        : ""
                    root.addSystemToast("PROFILE: " + line.toUpperCase(), profIcon, false, "powerprofile")
                }
                root.lastPowerProfile = line
            }
        }
        onRunningChanged: if (!running) running = true
    }

    // --- Low battery warnings (20/10/5%), once per threshold ---
    property bool warned20: false
    property bool warned10: false
    property bool warned5: false

    Connections {
        target: Services.Battery
        function onLevelChanged() {
            if (Services.Battery.charging) return
            let lvl = Services.Battery.level
            if (lvl <= 5 && !root.warned5) {
                root.warned5 = true
                root.addSystemToast("BATTERY CRITICAL: 5%", "", false, "battery5")
            } else if (lvl <= 10 && !root.warned10) {
                root.warned10 = true
                root.addSystemToast("BATTERY LOW: 10%", "", false, "battery10")
            } else if (lvl <= 20 && !root.warned20) {
                root.warned20 = true
                root.addSystemToast("BATTERY LOW: 20%", "", false, "battery20")
            }
        }
        function onChargingChanged() {
            if (Services.Battery.charging) {
                root.warned20 = false
                root.warned10 = false
                root.warned5 = false
            }
        }
    }

    // System notice when Do Not Disturb is toggled
    Connections {
        target: Services.AppState
        function onDoNotDisturbChanged() {
            root.addSystemToast(
                Services.AppState.doNotDisturb ? "DO NOT DISTURB ON" : "DO NOT DISTURB OFF",
                "",
                false,
                "dnd"
            )
        }
        function onKeepAwakeChanged() {
            root.addSystemToast(
                Services.AppState.keepAwake ? "KEEP AWAKE ON" : "KEEP AWAKE OFF",
                "",
                false,
                "keepawake"
            )
        }
        function onRecordingChanged() {
            root.addSystemToast(
                Services.AppState.recording ? "SCREEN RECORDING STARTED" : "SCREEN RECORDING STOPPED",
                "",
                false,
                "recording"
            )
        }
    }
}
