import Quickshell
import Quickshell.Io
import QtQuick
import "root:/services" as Services

Scope {
    id: root

    // Each reading is a process, and a key held down asks faster than one can
    // answer. Asking again while one is in flight used to be dropped on the
    // floor, so the OSD showed the value from two steps ago; now the last ask
    // is remembered and replayed the moment the reply lands.
    property bool volPending: false
    property bool brtPending: false

    IpcHandler {
        target: "osd"
        function volume() {
            if (volumeProc.running) root.volPending = true
            else volumeProc.running = true
        }
        function brightness() {
            if (brightnessProc.running) root.brtPending = true
            else brightnessProc.running = true
        }
    }

    Process {
        id: volumeProc
        command: ["sh", "-c", "wpctl get-volume @DEFAULT_AUDIO_SINK@"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                let muted = text.indexOf("MUTED") !== -1
                let match = text.match(/([0-9]*\.?[0-9]+)/)
                let vol = match ? parseFloat(match[1]) : 0
                let ic = Services.Audio.icon(muted ? 0 : Math.round(vol * 100), muted, Services.Audio.headphones)
                win.showOsd(ic, muted ? 0 : vol)
                if (root.volPending) { root.volPending = false; volumeProc.running = true }
            }
        }
    }

    Process {
        id: brightnessProc
        command: ["sh", "-c", "brightnessctl -m"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                let parts = text.trim().split(",")
                let pctStr = parts.length > 3 ? parts[3].replace("%", "") : "0"
                let pct = parseFloat(pctStr) / 100.0
                win.showOsd("", pct)
                if (root.brtPending) { root.brtPending = false; brightnessProc.running = true }
            }
        }
    }

    PanelWindow {
        id: win
        anchors { top: true; right: true; bottom: true }
        screen: Services.Screens.active
        implicitWidth: 90
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        visible: hideTimer.running || unmapDelay.running

        property real level: 0
        property string icon: ""

        function showOsd(ic, lv) {
            win.icon = ic
            win.level = lv
            hideTimer.restart()
        }

        Timer {
            id: hideTimer
            interval: 1400
            onTriggered: unmapDelay.restart()
        }
        // keep the window mapped a bit longer so the fade-out is visible,
        // then actually unmap it so it does not block clicks
        Timer {
            id: unmapDelay
            interval: 250
        }

        Rectangle {
            // Clears whichever edge the bar is on
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.rightMargin: Math.max(20, Services.Sizes.marginRight)
            width: 48
            height: 250
            radius: 14
            color: Services.Colors.surfacePanel
            border.color: Services.Colors.ghostAlpha(0.2)
            border.width: 0

            opacity: hideTimer.running ? 1.0 : 0.0
            scale: hideTimer.running ? 1.0 : 0.85
            Behavior on opacity { NumberAnimation { duration: Services.Sizes.msStandard; easing.type: Services.Sizes.easeOut } }
            Behavior on scale { NumberAnimation { duration: Services.Sizes.msStandard; easing.type: Easing.OutBack; easing.overshoot: Services.Sizes.overshoot } }

            Column {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 10

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: win.icon
                    font.family: "Material Symbols Rounded"
                    font.pixelSize: 20
                    color: Services.Colors.ghost
                }

                Rectangle {
                    width: 8
                    height: parent.height - 70
                    anchors.horizontalCenter: parent.horizontalCenter
                    radius: 4
                    color: Services.Colors.ghostAlpha(0.15)

                    Rectangle {
                        anchors.bottom: parent.bottom
                        width: parent.width
                        radius: 4
                        color: Services.Colors.ghost
                        // Down the bar, not across it: the fill IS vertical.
                        gradient: Services.Prefs.useGradients ? Services.Colors.accentGradientV : null
                        height: parent.height * Math.max(0, Math.min(1, win.level))
                        // Short: at 260 ms every tap on the volume key restarted
                        // an animation the next tap interrupted, so the bar
                        // crawled a step behind the key being held down.
                        Behavior on height { NumberAnimation { duration: Services.Sizes.msMicro; easing.type: Services.Sizes.easeOut } }
                    }
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Math.round(win.level * 100) + "%"
                    font.family: "JetBrainsMono NF"
                    font.pixelSize: 11
                    font.bold: true
                    color: Services.Colors.snow
                }
            }
        }
    }
}
