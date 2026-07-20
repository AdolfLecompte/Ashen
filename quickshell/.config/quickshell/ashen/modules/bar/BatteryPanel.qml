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
    // Reset the trace once the panel is fully hidden, so its stale full buffer
    // isn't shown for a frame on the next open (which read as a full->empty jump).
    Timer { id: closeDelay; interval: 300; onTriggered: battBox.frac = 0 }
    // Holds the border sweep until the window has mapped and the card settled,
    // so the whole 0->level trace is actually seen (see introSweep).
    Timer { id: openDelay; interval: 260; onTriggered: { battBox.armed = true; introSweep.restart() } }

    property string timeRemaining: "--"
    property var availableProfiles: []
    property string activeProfile: ""

    function refreshBattery() { battProc.running = true }
    function refreshProfiles() { profProc.running = true }
    onShownChanged: {
        if (shown) { refreshBattery(); refreshProfiles(); battBox.armed = false; battBox.frac = 0; openDelay.restart() }
        else { battBox.armed = false; closeDelay.restart() }
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

                // Live charge as a 0..1 fraction; `frac` is what the canvas
                // actually strokes, so it can animate independently of the level.
                property real target: Services.Battery.level / 100
                property real frac: 0
                // Canvas keeps its last rendered image as a texture: on re-map
                // it flashes that stale (full) buffer before the sweep repaints.
                // Gate the whole canvas on `armed` so it's invisible until the
                // sweep actually starts -> no full-flash, no jump.
                property bool armed: false
                onFracChanged: battCanvas.requestPaint()
                onWidthChanged: battCanvas.requestPaint()
                onHeightChanged: battCanvas.requestPaint()

                // Entry sweep: trace the border from 0 up to the level. Started
                // by win's openDelay timer (not directly on open) so the window
                // has mapped and the card has settled first -- otherwise the
                // first half of the sweep plays before the panel is on screen.
                SequentialAnimation {
                    id: introSweep
                    PropertyAction { target: battBox; property: "frac"; value: 0 }
                    NumberAnimation {
                        target: battBox; property: "frac"
                        to: battBox.target
                        duration: 6500; easing.type: Easing.OutCubic
                    }
                    // The sweep's end value is captured when it starts; if the
                    // async battery refresh landed a fresher level mid-sweep, the
                    // onTargetChanged handler skipped it (guarded on !running), so
                    // reconcile to the live target once the trace settles.
                    onStopped: if (win.shown && battBox.armed && battBox.frac !== battBox.target) liveFrac.restart()
                }
                // After the sweep, ease to live level changes (e.g. while charging).
                onTargetChanged: if (win.shown && battBox.armed && !introSweep.running) liveFrac.restart()
                NumberAnimation {
                    id: liveFrac
                    target: battBox; property: "frac"
                    to: battBox.target
                    duration: 500; easing.type: Easing.OutCubic
                }

                Canvas {
                    id: battCanvas
                    anchors.fill: parent
                    opacity: battBox.armed ? 1 : 0
                    onPaint: {
                        var ctx = getContext("2d")
                        ctx.reset()
                        var lw = 7
                        var r = 22
                        var x = lw / 2, y = lw / 2
                        var w = width - lw, h = height - lw
                        // Starts at the middle of the top edge so the accent
                        // trace grows from top-centre (clockwise), not a corner.
                        function path() {
                            ctx.beginPath()
                            ctx.moveTo(x + w / 2, y)
                            ctx.lineTo(x + w - r, y)
                            ctx.arcTo(x + w, y, x + w, y + r, r)
                            ctx.lineTo(x + w, y + h - r)
                            ctx.arcTo(x + w, y + h, x + w - r, y + h, r)
                            ctx.lineTo(x + r, y + h)
                            ctx.arcTo(x, y + h, x, y + h - r, r)
                            ctx.lineTo(x, y + r)
                            ctx.arcTo(x, y, x + r, y, r)
                            ctx.lineTo(x + w / 2, y)
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

            Item {
                id: profSelect
                Layout.fillWidth: true
                Layout.preferredHeight: 64
                property Item activeProf: null

                // Sliding highlight behind the active profile (workspace-style)
                Rectangle {
                    visible: profSelect.activeProf !== null
                    x: profSelect.activeProf ? profSelect.activeProf.x : 0
                    width: profSelect.activeProf ? profSelect.activeProf.width : 0
                    height: 64
                    radius: 12
                    color: Services.Colors.ghost
                    Behavior on x { SmoothedAnimation { duration: 250 } }
                }

                RowLayout {
                anchors.fill: parent
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
                        readonly property bool active: win.activeProfile === modelData.id
                        onActiveChanged: if (active) profSelect.activeProf = this
                        Component.onCompleted: if (active) profSelect.activeProf = this
                        Layout.fillWidth: true
                        height: 64
                        radius: 12
                        color: active ? "transparent" : Services.Colors.ghostAlpha(0.12)
                        opacity: available ? 1.0 : 0.35
                        Behavior on color { ColorAnimation { duration: 150 } }

                        Text {
                            anchors.centerIn: parent
                            text: modelData.icon
                            font.family: "Material Symbols Rounded"
                            font.pixelSize: 28
                            color: active ? Services.Colors.abyss : Services.Colors.mist
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
}
