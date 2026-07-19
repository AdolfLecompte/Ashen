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
        height: 330
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

            // Battery box: a rounded-rectangle OUTLINE that fills along its own
            // border — a dim full track, then an accent stroke covering a fraction
            // of the perimeter equal to the charge level. Percentage sits centered.
            Item {
                id: battBox
                Layout.fillWidth: true
                Layout.preferredHeight: 120

                // Animated fraction the canvas repaints from
                property real frac: Services.Battery.level / 100
                Behavior on frac { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }
                onFracChanged: battCanvas.requestPaint()
                onWidthChanged: battCanvas.requestPaint()
                onHeightChanged: battCanvas.requestPaint()

                Canvas {
                    id: battCanvas
                    anchors.fill: parent
                    onPaint: {
                        var ctx = getContext("2d")
                        ctx.reset()
                        var lw = 5
                        var r = 22
                        var x = lw / 2, y = lw / 2
                        var w = width - lw, h = height - lw
                        function path() {
                            ctx.beginPath()
                            ctx.moveTo(x + r, y)
                            ctx.lineTo(x + w - r, y)
                            ctx.arcTo(x + w, y, x + w, y + r, r)
                            ctx.lineTo(x + w, y + h - r)
                            ctx.arcTo(x + w, y + h, x + w - r, y + h, r)
                            ctx.lineTo(x + r, y + h)
                            ctx.arcTo(x, y + h, x, y + h - r, r)
                            ctx.lineTo(x, y + r)
                            ctx.arcTo(x, y, x + r, y, r)
                            ctx.closePath()
                        }
                        ctx.lineWidth = lw
                        ctx.lineCap = "round"
                        // Dim full track
                        path()
                        ctx.strokeStyle = Services.Colors.ghostAlpha(0.15)
                        ctx.stroke()
                        // Accent fill: one dash covering frac of the perimeter
                        var frac = Math.max(0, Math.min(1, battBox.frac))
                        if (frac > 0) {
                            var perim = 2 * (w + h) - 8 * r + 2 * Math.PI * r
                            path()
                            ctx.strokeStyle = Services.Colors.ghost
                            ctx.setLineDash([perim * frac, perim])
                            ctx.stroke()
                            ctx.setLineDash([])
                        }
                    }
                }

                // Centered battery glyph + percentage
                RowLayout {
                    anchors.centerIn: parent
                    spacing: 12

                    // Glyph tracks charge level (and charging state)
                    Text {
                        text: {
                            if (Services.Battery.charging) return "\ue1a3"   // battery_charging_full
                            var l = Services.Battery.level
                            if (l >= 95) return "\ue1a5"                     // battery_full
                            if (l >= 85) return "\uf0a1"                     // battery_6_bar
                            if (l >= 70) return "\uf0a0"                     // battery_5_bar
                            if (l >= 55) return "\uf09f"                     // battery_4_bar
                            if (l >= 40) return "\uf09e"                     // battery_3_bar
                            if (l >= 25) return "\uf09d"                     // battery_2_bar
                            if (l >= 10) return "\uf09c"                     // battery_1_bar
                            return "\uebdc"                                 // battery_0_bar
                        }
                        color: Services.Battery.charging ? Services.Colors.ghost
                            : (Services.Battery.level <= 15 ? Services.Colors.snow : Services.Colors.ghost)
                        font.family: "Material Symbols Rounded"
                        font.pixelSize: 40
                    }

                    Text {
                        text: Services.Battery.level + "%"
                        color: Services.Colors.snow
                        font.pixelSize: 44
                        font.bold: true
                        font.family: "JetBrainsMono NF"
                    }
                }
            }

            // Status under the box: charging state + time to full/empty
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Text {
                    visible: Services.Battery.charging
                    text: "\uea0b"
                    font.family: "Material Symbols Rounded"
                    font.pixelSize: 16
                    color: Services.Colors.ghost
                }
                Text {
                    text: Services.Battery.charging ? "Charging" : "On battery"
                    color: Services.Colors.snow
                    font.pixelSize: 13
                    font.bold: true
                    font.family: "JetBrainsMono NF"
                }
                Item { Layout.fillWidth: true }
                Text {
                    text: win.timeRemaining !== "--"
                        ? (Services.Battery.charging ? ("Full in " + win.timeRemaining) : (win.timeRemaining + " left"))
                        : (Services.Battery.charging ? "Fully charged" : "Calculating...")
                    color: Services.Colors.ash
                    font.pixelSize: 11
                    font.bold: true
                    font.family: "JetBrainsMono NF"
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
