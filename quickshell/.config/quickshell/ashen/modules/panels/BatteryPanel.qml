import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import "root:/services" as Services
import "root:/modules/widgets" as Widgets

PanelWindow {
    id: win
    anchors { top: true; left: true; right: true; bottom: true }
    screen: Services.Screens.active
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    // stays mapped through the close animation, so the exit plays in reverse
    readonly property bool shown: Services.AppState.batteryVisible
    visible: shown || closeDelay.running
    // Mapped until the drop is all the way home; see DropCard.closeMs.
    Timer { id: closeDelay; interval: card.closeMs }

    // The dial is held dark until the card is really on screen, then sweeps up
    // from empty; DialGauge does the sweep itself off this flag.
    property bool battArmed: false
    // Holds the sweep until the card's contents are actually on screen, so the
    // whole 0->level trace is seen. It has to clear the drop's own wait for the
    // window plus the pause before the contents fade in — at 260 the sweep was
    // running behind a body still at zero opacity, and most of it was spent
    // before there was anything to look at.
    Timer {
        id: openDelay
        interval: Services.Sizes.panelArmMs + 360
        onTriggered: win.battArmed = true
    }

    property string timeRemaining: "--"
    property var availableProfiles: []
    property string activeProfile: ""

    function refreshBattery() { battProc.running = true }
    function refreshProfiles() { profProc.running = true }
    onShownChanged: {
        if (shown) { refreshBattery(); refreshProfiles(); win.battArmed = false; openDelay.restart() }
        else { win.battArmed = false; closeDelay.restart() }
    }

    function setProfile(name) {
        if (!win.availableProfiles.includes(name)) return
        Quickshell.execDetached(["sh", "-c", "powerprofilesctl set " + name])
        win.activeProfile = name
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

    // Grows out of its chip when the chip is on the bar; unfolds where it
    // lives when the chip is hidden.
    Widgets.PanelHost {
        id: card
        shown: Services.AppState.batteryVisible
        pillKey: "battery"
        pillCX: Services.AppState.batteryPillCenterX
        pillCY: Services.AppState.batteryPillCenterY
        pillW: Services.AppState.batteryPillW
        pillH: Services.AppState.batteryPillH
        pillActive: Services.Battery.charging
        pillGlyph: Services.AppState.pillGlyph("battery")
        pillLabel: Services.AppState.pillLabel("battery")
        openW: 440
        openH: 400
        cardRadius: 18

        body: Component {
            Item {
                // Where the chip's glyph and reading land.
                readonly property Item glyphTarget: dial.glyphItem
                readonly property Item labelTarget: dial.labelItem

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 20
                    spacing: 12

                    // The same dial as sound and brightness, grown: reading in the
                    // middle, charge around the rim. It used to be a rounded-rectangle
                    // outline traced along its own border, which was a shape nothing
                    // else in the shell used and had its own ladder of thresholds so
                    // the trace could sit at 86% while the number said 91.
                    Widgets.DialGauge {
                        id: dial
                        Layout.alignment: Qt.AlignHCenter
                        size: 200
                        lw: 13
                        value: Math.max(0, Math.min(1, Services.Battery.level / 100))
                        glyph: Services.AppState.pillGlyph("battery")
                        glyphSize: 34
                        label: Math.round(dial.frac * 100) + "%"
                        labelSize: 40
                        captionSize: 0
                        // Accent at every level, never red: error_ is for things
                        // that actually went wrong, and a low battery is the panel
                        // doing its job. The old gauge made the same choice.
                        fillColor: Services.Colors.ghost
                        // Breathes while it is filling. Charging is the one state here
                        // that is still happening rather than simply being.
                        glow: Services.Battery.charging
                        armed: win.battArmed
                        sweepMs: 1500
                        hideGlyph: card.morphingGlyph
                        hideLabel: card.morphingLabel
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
                            gradient: Services.Prefs.useGradients ? Services.Colors.accentGradient : null
                            Behavior on x { SmoothedAnimation { duration: Services.Sizes.msPronounced } }
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
                                // Only the sliding indicator carries the active fill;
                                // idle slots are bare (hover just brightens them).
                                color: active ? "transparent"
                                    : profHover.containsMouse ? Services.Colors.ghostAlpha(0.12) : "transparent"
                                opacity: available ? 1.0 : 0.35
                                Behavior on color { ColorAnimation { duration: Services.Sizes.msMicro } }

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData.icon
                                    font.family: "Material Symbols Rounded"
                                    font.pixelSize: 28
                                    color: active ? Services.Colors.abyss : Services.Colors.mist
                                }

                                MouseArea {
                                    id: profHover
                                    anchors.fill: parent
                                    hoverEnabled: parent.available
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
    }
}