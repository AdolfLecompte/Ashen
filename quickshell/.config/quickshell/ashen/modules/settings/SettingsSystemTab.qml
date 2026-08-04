import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import "root:/services" as Services
import "root:/modules/settings/components"

// Power profile, battery estimate and the toggles that decide whether the
// machine is allowed to go to sleep.
TabPage {
    id: tab

    // Idle steps in minutes; 0 means the listener is left out of hypridle.conf.
    function stepIdle(secs, deltaMin) {
        return Math.max(0, Math.min(120 * 60, secs + deltaMin * 60))
    }
    function idleLabel(secs) {
        if (secs <= 0) return "Never"
        return (secs % 60 === 0 ? (secs / 60) + " min" : secs + " s")
    }

    property string timeRemaining: "--"
    property var availableProfiles: []
    property string activeProfile: ""

    function setProfile(name) {
        if (!availableProfiles.includes(name)) return
        Quickshell.execDetached(["sh", "-c", "powerprofilesctl set " + name])
        activeProfile = name
    }

    Component.onCompleted: {
        battProc.running = true
        profProc.running = true
    }

    Process {
        id: battProc
        command: ["sh", "-c", "upower -i $(upower -e | grep BAT) 2>/dev/null | grep -E 'time to (empty|full)'"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                let line = text.trim()
                tab.timeRemaining = line.length > 0 ? line.split(":").slice(1).join(":").trim() : "--"
            }
        }
    }
    Process {
        id: profProc
        command: ["sh", "-c", "powerprofilesctl list"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                let lines = text.split("\n")
                let profiles = []
                let active = ""
                for (let line of lines) {
                    let m = line.match(/^\s*(\*?)\s*([\w-]+):$/)
                    if (m) { profiles.push(m[2]); if (m[1] === "*") active = m[2] }
                }
                tab.availableProfiles = profiles
                tab.activeProfile = active
            }
        }
    }

    Card {
        title: "Power & Session"
        RowLayout {
            spacing: 14
            Text {
                text: Services.Battery.level + "%"
                color: Services.Colors.snow
                font.pixelSize: 24
                font.bold: true
                font.family: "JetBrainsMono NF"
            }
            ColumnLayout {
                spacing: 2
                Text {
                    text: Services.Battery.charging ? "Charging" : "On battery"
                    color: Services.Colors.mist
                    font.pixelSize: 11
                    font.family: "JetBrainsMono NF"
                }
                Text {
                    text: tab.timeRemaining !== "--" ? tab.timeRemaining : (Services.Battery.charging ? "Fully charged" : "Calculating...")
                    color: Services.Colors.ash
                    font.pixelSize: 10
                    font.family: "JetBrainsMono NF"
                }
            }
        }

        SectionLabel { text: "Power Profile" }

        Segmented {
            stacked: true
            options: [
                { id: "power-saver", icon: "", label: "Saver", available: tab.availableProfiles.includes("power-saver") },
                { id: "balanced", icon: "", label: "Balanced", available: tab.availableProfiles.includes("balanced") },
                { id: "performance", icon: "", label: "Performance", available: tab.availableProfiles.includes("performance") },
            ]
            current: tab.activeProfile
            onPicked: id => tab.setProfile(id)
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 12
            Text {
                text: ""
                font.family: "Material Symbols Rounded"
                font.pixelSize: 20
                color: Services.AppState.keepAwake ? Services.Colors.ghost : Services.Colors.mist
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Text { text: "Keep Awake"; color: Services.Colors.snow; font.pixelSize: 13; font.bold: true; font.family: "JetBrainsMono NF" }
                Text { text: "Prevents auto-lock and screen dimming"; color: Services.Colors.ash; font.pixelSize: 10; font.family: "JetBrainsMono NF" }
            }
            Toggle {
                checked: Services.AppState.keepAwake
                // AppState drives hypridle itself, so every flip agrees
                onToggled: Services.AppState.keepAwake = !Services.AppState.keepAwake
            }
        }

    }

    Card {
        title: "Lock Screen"

        RowLayout {
            Layout.fillWidth: true
            spacing: 12
            RowGlyph { glyph: "\ue899" }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Text {
                    text: "Show what is playing"
                    color: Services.Colors.snow
                    font.pixelSize: 13
                    font.bold: true
                    font.family: "JetBrainsMono NF"
                }
                Text {
                    text: "Track, cover art and controls on the lock screen"
                    color: Services.Colors.ash
                    font.pixelSize: 10
                    font.family: "JetBrainsMono NF"
                }
            }
            Toggle {
                checked: Services.Prefs.lockShowMedia
                onToggled: Services.Prefs.lockShowMedia = !Services.Prefs.lockShowMedia
            }
        }
    }

    Card {
        title: "Idle & Suspend"

        Text {
            text: "Countdowns start from the last input. Keep Awake pauses all three."
            color: Services.Colors.ash
            font.pixelSize: 10
            font.family: "JetBrainsMono NF"
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }

        Repeater {
            model: [
                { key: "lock", label: "Lock the screen" },
                { key: "screenOff", label: "Turn the screen off" },
                { key: "suspend", label: "Suspend" },
            ]
            delegate: RowLayout {
                required property var modelData
                Layout.fillWidth: true
                spacing: 10
                readonly property int secs: modelData.key === "lock" ? Services.Prefs.idleLockSecs
                    : modelData.key === "screenOff" ? Services.Prefs.idleScreenOffSecs
                    : Services.Prefs.idleSuspendSecs
                function apply(v) {
                    if (modelData.key === "lock") Services.Prefs.idleLockSecs = v
                    else if (modelData.key === "screenOff") Services.Prefs.idleScreenOffSecs = v
                    else Services.Prefs.idleSuspendSecs = v
                }

                Text {
                    Layout.fillWidth: true
                    text: modelData.label
                    color: Services.Colors.snow
                    font.pixelSize: 12
                    font.family: "JetBrainsMono NF"
                }
                Text {
                    text: tab.idleLabel(parent.secs)
                    color: parent.secs > 0 ? Services.Colors.ghost : Services.Colors.mist
                    font.pixelSize: 13
                    font.bold: true
                    font.family: "JetBrainsMono NF"
                    Layout.preferredWidth: 64
                    horizontalAlignment: Text.AlignRight
                }
                StepBtn {
                    glyph: ""
                    onClicked: parent.apply(tab.stepIdle(parent.secs, -5))
                }
                StepBtn {
                    glyph: ""
                    onClicked: parent.apply(tab.stepIdle(parent.secs, 5))
                }
            }
        }

        Text {
            // Ordering mistakes are easy to make and impossible to see
            visible: Services.Prefs.idleSuspendSecs > 0
                && Services.Prefs.idleLockSecs > Services.Prefs.idleSuspendSecs
            text: "Suspend fires before the lock does — the machine will sleep unlocked."
            color: Services.Colors.error_
            font.pixelSize: 10
            font.family: "JetBrainsMono NF"
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }
    }


    Item { Layout.preferredHeight: 8 }
}
