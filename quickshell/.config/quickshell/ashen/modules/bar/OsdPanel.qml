import Quickshell
import Quickshell.Io
import QtQuick
import "root:/services" as Services

Scope {
    id: root

    IpcHandler {
        target: "osd"
        function volume() {
            volumeProc.running = true
        }
        function brightness() {
            brightnessProc.running = true
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
            }
        }
    }

    PanelWindow {
        id: win
        anchors { top: true; right: true; bottom: true }
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
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.rightMargin: 20
            width: 48
            height: 250
            radius: 14
            color: Services.Colors.surfaceAlpha(0.9)
            border.color: Services.Colors.ghostAlpha(0.2)
            border.width: 0

            opacity: hideTimer.running ? 1.0 : 0.0
            scale: hideTimer.running ? 1.0 : 0.85
            Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
            Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutBack } }

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
                        height: parent.height * Math.max(0, Math.min(1, win.level))
                        Behavior on height { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
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
