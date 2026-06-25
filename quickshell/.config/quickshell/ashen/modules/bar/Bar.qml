import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.SystemTray
import QtQuick
import QtQuick.Layouts

Scope {
    id: root
    property string currentTime: ""
    property string currentDate: ""
    property string timeIcon: "󰖔"
    property string wifiSsid: "..."
    property string btDevice: "..."
    property int volume: 0

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: {
            let now = new Date()
            let h = now.getHours()
            root.currentTime = Qt.formatDateTime(now, "hh:mm:ss AP")
            root.currentDate = Qt.formatDateTime(now, "ddd, MMM d")
            if (h >= 0 && h < 5)        root.timeIcon = "󰖔"
            else if (h >= 5 && h < 8)   root.timeIcon = "󰖜"
            else if (h >= 8 && h < 17)  root.timeIcon = "󰖙"
            else if (h >= 17 && h < 20) root.timeIcon = "󰖛"
            else                         root.timeIcon = "󰖑"
        }
    }

    Process {
        id: wifiProc
        command: ["nmcli", "-t", "-f", "active,ssid", "dev", "wifi"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                let lines = text.split("\n")
                for (let line of lines) {
                    if (line.startsWith("yes:")) {
                        root.wifiSsid = line.split(":")[1]
                        return
                    }
                }
                root.wifiSsid = "off"
            }
        }
    }

    Timer {
        interval: 10000
        running: true
        repeat: true
        onTriggered: wifiProc.running = true
    }

    Process {
        id: btProc
        command: ["sh", "-c", "bluetoothctl devices Connected | head -1 | cut -d' ' -f3-"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                let name = text.trim()
                root.btDevice = name.length > 0 ? name : "off"
            }
        }
    }

    Timer {
        interval: 10000
        running: true
        repeat: true
        onTriggered: btProc.running = true
    }

    Process {
        id: volProc
        command: ["sh", "-c", "wpctl get-volume @DEFAULT_AUDIO_SINK@ | awk '{printf \"%d\", $2*100}'"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                root.volume = parseInt(text.trim()) || 0
            }
        }
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: volProc.running = true
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            property var modelData
            screen: modelData
            anchors { top: true; left: true; right: true }
            implicitHeight: 56
            color: "transparent"
            exclusionMode: ExclusionMode.Exclusive

            Item {
                anchors.fill: parent

                // ── Izquierda ──────────────────────────
                RowLayout {
                    id: leftSection
                    anchors.left: parent.left
                    anchors.leftMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6

                    Rectangle {
                        width: 40; height: 44
                        radius: 6
                        color: "#1d1d24"
                        border.color: "#24242d"
                        border.width: 1
                        Text {
                            anchors.centerIn: parent
                            text: "󰍉"
                            color: "#6272a4"
                            font.pixelSize: 18
                            font.family: "JetBrainsMono NF"
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                        }
                    }

                    Rectangle {
                        height: 44
                        radius: 6
                        color: "#1d1d24"
                        border.color: "#24242d"
                        border.width: 1
                        width: wsRow.implicitWidth + 12

                        Rectangle {
                            id: slideIndicator
                            width: 30; height: 30
                            radius: 5
                            color: "#6272a4"
                            y: 7
                            x: {
                                let focused = Hyprland.focusedWorkspace
                                if (!focused) return 6
                                let base = Math.floor((focused.id - 1) / 5) * 5
                                let idx = focused.id - base - 1
                                return 6 + idx * 34
                            }
                            Behavior on x {
                                SmoothedAnimation { duration: 250 }
                            }
                        }

                        RowLayout {
                            id: wsRow
                            anchors.centerIn: parent
                            spacing: 4

                            Repeater {
                                model: 5
                                delegate: Item {
                                    required property int index
                                    property int wsId: {
                                        let focused = Hyprland.focusedWorkspace
                                        if (!focused) return index + 1
                                        let base = Math.floor((focused.id - 1) / 5) * 5
                                        return base + index + 1
                                    }
                                    property bool isActive: Hyprland.focusedWorkspace && Hyprland.focusedWorkspace.id === wsId
                                    property bool hasWindows: Hyprland.workspaces.values.find(w => w.id === wsId) !== undefined
                                    width: 30; height: 30

                                    Rectangle {
                                        anchors.fill: parent
                                        radius: 5
                                        color: "#6272a4"
                                        opacity: parent.hasWindows && !parent.isActive ? 0.15 : 0
                                        Behavior on opacity {
                                            NumberAnimation { duration: 200 }
                                        }
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        text: wsId
                                        color: parent.isActive ? "#0f0f12" : "#7878a0"
                                        font.pixelSize: 13
                                        font.family: "JetBrainsMono NF"
                                        font.bold: parent.isActive
                                        z: 1
                                        Behavior on color {
                                            ColorAnimation { duration: 200 }
                                        }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: Hyprland.dispatch("workspace " + wsId)
                                    }
                                }
                            }
                        }
                    }
                }

                // ── Centro ─────────────────────────────
                Rectangle {
                    anchors.centerIn: parent
                    height: 44
                    width: clockRow.implicitWidth + 40
                    radius: 6
                    color: "#1d1d24"
                    border.color: "#24242d"
                    border.width: 1

                    RowLayout {
                        id: clockRow
                        anchors.centerIn: parent
                        spacing: 16

                        Column {
                            spacing: 1

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: root.currentTime
                                color: "#d4d4e0"
                                font.pixelSize: 15
                                font.family: "JetBrainsMono NF"
                                font.bold: true
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: root.currentDate
                                color: "#7878a0"
                                font.pixelSize: 10
                                font.family: "JetBrainsMono NF"
                            }
                        }

                        Text {
                            text: root.timeIcon
                            font.pixelSize: 24
                            font.family: "JetBrainsMono NF"
                            color: {
                                let h = new Date().getHours()
                                if (h >= 0 && h < 5)        return "#aab4d4"
                                else if (h >= 5 && h < 8)   return "#c4a882"
                                else if (h >= 8 && h < 17)  return "#c4c882"
                                else if (h >= 17 && h < 20) return "#c4a882"
                                else                         return "#8899cc"
                            }
                        }
                    }
                }

                // ── Derecha ────────────────────────────
                RowLayout {
                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter

                    Rectangle {
                        height: 44
                        radius: 6
                        color: "#1d1d24"
                        border.color: "#24242d"
                        border.width: 1
                        width: sysRow.implicitWidth + 16

                        RowLayout {
                            id: sysRow
                            anchors.centerIn: parent
                            spacing: 10

                            Text {
                                text: "󰂚"
                                color: "#d4d4e0"
                                font.pixelSize: 16
                                font.family: "JetBrainsMono NF"
                            }

                            Rectangle { width: 1; height: 22; color: "#24242d" }

                            RowLayout {
                                spacing: 4
                                Text {
                                    text: root.wifiSsid === "off" ? "󰤭" : "󰤨"
                                    color: root.wifiSsid === "off" ? "#8a5a5a" : "#d4d4e0"
                                    font.pixelSize: 16
                                    font.family: "JetBrainsMono NF"
                                }
                                Text {
                                    text: root.wifiSsid
                                    color: "#d4d4e0"
                                    font.pixelSize: 11
                                    font.family: "JetBrainsMono NF"
                                }
                            }

                            RowLayout {
                                spacing: 4
                                Text {
                                    text: root.btDevice === "off" ? "󰂲" : "󰂯"
                                    color: root.btDevice === "off" ? "#8a5a5a" : "#6272a4"
                                    font.pixelSize: 16
                                    font.family: "JetBrainsMono NF"
                                }
                                Text {
                                    visible: root.btDevice !== "off"
                                    text: root.btDevice
                                    color: "#d4d4e0"
                                    font.pixelSize: 11
                                    font.family: "JetBrainsMono NF"
                                }
                            }

                            RowLayout {
                                spacing: 4
                                Text {
                                    text: root.volume === 0 ? "󰝟" : "󰕾"
                                    color: "#d4d4e0"
                                    font.pixelSize: 16
                                    font.family: "JetBrainsMono NF"
                                }
                                Text {
                                    text: root.volume + "%"
                                    color: "#d4d4e0"
                                    font.pixelSize: 11
                                    font.family: "JetBrainsMono NF"
                                }
                            }

                            Rectangle { width: 1; height: 22; color: "#24242d" }

                            Repeater {
                                model: SystemTray.items
                                delegate: Item {
                                    required property SystemTrayItem modelData
                                    width: 22; height: 22
                                    Image {
                                        anchors.centerIn: parent
                                        source: modelData.icon
                                        width: 18; height: 18
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                                        onClicked: (mouse) => {
                                            if (mouse.button === Qt.LeftButton)
                                                modelData.activate()
                                            else
                                                modelData.provideContext(Qt.point(x, y))
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
}
