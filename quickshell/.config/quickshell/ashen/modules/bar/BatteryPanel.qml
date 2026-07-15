import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import "root:/services" as Services

PanelWindow {
    id: win
    anchors { top: true; left: true; right: true; bottom: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    // stays mapped through the close animation, so the exit plays in reverse
    readonly property bool shown: Services.AppState.batteryVisible
    visible: shown || closeDelay.running
    Timer { id: closeDelay; interval: 300 }

    property string timeRemaining: "--"
    property var availableProfiles: []
    property string activeProfile: ""

    function refreshBattery() { battProc.running = true }
    function refreshProfiles() { profProc.running = true }
    onShownChanged: {
        if (shown) { refreshBattery(); refreshProfiles() }
        else closeDelay.restart()
    }

    function setProfile(name) {
        if (!win.availableProfiles.includes(name)) return
        Quickshell.execDetached(["sh", "-c", "powerprofilesctl set " + name])
        win.activeProfile = name
    }

    function profileDescription(name) {
        if (name === "power-saver") return "Power Saver reduces performance to maximize battery life."
        if (name === "balanced") return "Balanced mode adjusts system resources based on current activity to optimize endurance."
        if (name === "performance") return "Performance mode prioritizes speed and responsiveness over battery life."
        return ""
    }

    Process {
        id: battProc
        command: ["sh", "-c", "upower -i $(upower -e | grep BAT) 2>/dev/null | grep -E 'time to (empty|full)'"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                let line = text.trim()
                if (line.length > 0) {
                    let parts = line.split(":")
                    win.timeRemaining = parts.length > 1 ? parts.slice(1).join(":").trim() : "--"
                } else {
                    win.timeRemaining = "--"
                }
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
                    if (m) {
                        profiles.push(m[2])
                        if (m[1] === "*") active = m[2]
                    }
                }
                win.availableProfiles = profiles
                win.activeProfile = active
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        z: -1
        onClicked: Services.AppState.batteryVisible = false
    }

    Rectangle {
        id: card
        anchors.top: parent.top
        anchors.topMargin: 64
        width: 440
        height: 230
        x: Math.max(12, Math.min(parent.width - width - 12, Services.AppState.batteryPillCenterX - width / 2))
        radius: 18
        color: Services.Colors.surfaceAlpha(0.95)
        border.color: Services.Colors.ghostAlpha(0.2)
        border.width: 0

        opacity: Services.AppState.batteryVisible ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

        transform: Translate {
            id: slideT
            x: Services.AppState.batteryVisible ? 0 : -24
            Behavior on x { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
        }

        MouseArea { anchors.fill: parent; onClicked: {} }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 12

            RowLayout {
                spacing: 14
                Text {
                    text: Services.Battery.level + "%"
                    color: Services.Colors.snow
                    font.pixelSize: 28
                    font.bold: true
                    font.family: "JetBrainsMono NF"
                }
                ColumnLayout {
                    spacing: 2
                    Text {
                        text: Services.Battery.charging ? "Charging" : "On battery"
                        color: Services.Colors.ghost
                        font.pixelSize: 12
                        font.family: "JetBrainsMono NF"
                    }
                    Text {
                        text: win.timeRemaining !== "--" ? win.timeRemaining : (Services.Battery.charging ? "Fully charged" : "Calculating...")
                        color: Services.Colors.ash
                        font.pixelSize: 10
                        font.family: "JetBrainsMono NF"
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                Rectangle {
                    Layout.fillWidth: true
                    height: 6
                    radius: 3
                    color: Services.Colors.ghostAlpha(0.15)
                    Rectangle {
                        height: parent.height
                        radius: 3
                        color: Services.Colors.ghost
                        width: parent.width * (Services.Battery.level / 100)
                        Behavior on width { NumberAnimation { duration: 300 } }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: "0%"
                        color: Services.Colors.ash
                        font.pixelSize: 9
                        font.family: "JetBrainsMono NF"
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: win.timeRemaining !== "--" ? ("Remaining: " + win.timeRemaining) : ""
                        color: Services.Colors.mist
                        font.pixelSize: 9
                        font.family: "JetBrainsMono NF"
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: "100%"
                        color: Services.Colors.ash
                        font.pixelSize: 9
                        font.family: "JetBrainsMono NF"
                    }
                }
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: Services.Colors.ghostAlpha(0.15) }

            Text {
                text: "POWER PROFILE"
                color: Services.Colors.ash
                font.pixelSize: 10
                font.family: "JetBrainsMono NF"
                font.letterSpacing: 1
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Repeater {
                    model: [
                        { id: "power-saver", icon: "" },
                        { id: "balanced", icon: "" },
                        { id: "performance", icon: "" },
                    ]
                    delegate: Rectangle {
                        required property var modelData
                        property bool available: win.availableProfiles.includes(modelData.id)
                        Layout.fillWidth: true
                        height: 64
                        radius: 12
                        color: win.activeProfile === modelData.id ? Services.Colors.ghost : Services.Colors.ghostAlpha(0.12)
                        opacity: available ? 1.0 : 0.35
                        Behavior on color { ColorAnimation { duration: 150 } }

                        Text {
                            anchors.centerIn: parent
                            text: modelData.icon
                            font.family: "Material Symbols Rounded"
                            font.pixelSize: 28
                            color: win.activeProfile === modelData.id ? Services.Colors.abyss : Services.Colors.mist
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: parent.available ? Qt.PointingHandCursor : Qt.ForbiddenCursor
                            enabled: parent.available
                            onClicked: win.setProfile(modelData.id)
                        }
                    }
                }
            }
        }
    }
}
