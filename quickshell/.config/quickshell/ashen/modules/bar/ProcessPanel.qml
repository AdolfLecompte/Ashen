import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import "root:/services" as Services

PanelWindow {
    id: root
    anchors { top: true; left: true; right: true; bottom: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    // stay mapped through the close animation
    visible: Services.AppState.processVisible || closeDelay.running

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    readonly property bool shown: Services.AppState.processVisible

    // sampling only runs while the panel is up
    onShownChanged: {
        Services.SysMon.active = shown
        if (!shown) closeDelay.restart()
    }

    Timer { id: closeDelay; interval: 260 }

    MouseArea {
        anchors.fill: parent
        z: -1
        onClicked: Services.AppState.processVisible = false
    }

    Rectangle {
        id: card
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 68
        anchors.horizontalCenter: parent.horizontalCenter
        width: 720
        height: Math.min(700, root.height - 120)
        radius: 22
        color: Services.Colors.crypt
        border.color: Services.Colors.ghostAlpha(0.18)
        border.width: 0
        clip: true

        opacity: root.shown ? 1.0 : 0.0
        scale: root.shown ? 1.0 : 0.97
        Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
        transform: Translate {
            y: root.shown ? 0 : 20
            Behavior on y { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
        }

        MouseArea { anchors.fill: parent; onClicked: {} }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 14

            // ── Header ─────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Rectangle {
                    Layout.preferredWidth: 42
                    Layout.preferredHeight: 42
                    radius: 13
                    color: Services.Colors.ghostAlpha(0.14)
                    Text {
                        anchors.centerIn: parent
                        text: ""
                        color: Services.Colors.ghost
                        font.pixelSize: 22
                        font.family: "Material Symbols Rounded"
                    }
                }

                ColumnLayout {
                    spacing: 0
                    Layout.fillWidth: true
                    Text {
                        text: "Process"
                        color: Services.Colors.snow
                        font.pixelSize: 18
                        font.bold: true
                        font.family: "JetBrainsMono NF"
                    }
                    Text {
                        text: Services.SysMon.cpuModel
                        color: Services.Colors.ash
                        font.pixelSize: 9
                        font.family: "JetBrainsMono NF"
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                }

                // network chip
                Rectangle {
                    Layout.preferredWidth: netRow.implicitWidth + 24
                    Layout.preferredHeight: 42
                    radius: 13
                    color: Services.Colors.ghostAlpha(0.08)

                    Row {
                        id: netRow
                        anchors.centerIn: parent
                        spacing: 8

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: Services.Network.wifiSsid !== "" ? "" : ""
                            color: Services.Network.online ? Services.Colors.ghost : Services.Colors.ash
                            font.pixelSize: 18
                            font.family: "Material Symbols Rounded"
                        }
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 1
                            Text {
                                text: Services.Network.wifiSsid !== ""
                                      ? Services.Network.wifiSsid
                                      : (Services.Network.ethConnection !== "" ? Services.Network.ethConnection : "Offline")
                                color: Services.Colors.snow
                                font.pixelSize: 11
                                font.bold: true
                                font.family: "JetBrainsMono NF"
                            }
                            Text {
                                text: "↓" + Services.SysMon.netRxKBs.toFixed(0) + "  ↑" + Services.SysMon.netTxKBs.toFixed(0) + " KB/s"
                                color: Services.Colors.mist
                                font.pixelSize: 9
                                font.family: "JetBrainsMono NF"
                            }
                        }
                    }
                }
            }

            // ── Hero: CPU dial + live graph ────────────────────
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 152
                radius: 18
                color: Services.Colors.ghostAlpha(0.06)

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 18

                    Item {
                        id: cpuGauge
                        Layout.preferredWidth: 120
                        Layout.preferredHeight: 120
                        readonly property real percent: Services.SysMon.cpuPercent

                        Canvas {
                            id: gaugeCanvas
                            anchors.fill: parent
                            onPaint: {
                                let ctx = getContext("2d")
                                ctx.reset()
                                let cx = width / 2, cy = height / 2
                                let r = (Math.min(width, height) - 14) / 2
                                // 270° dial, open at the bottom
                                let a0 = Math.PI * 0.75
                                let sweep = Math.PI * 1.5
                                ctx.lineCap = "round"
                                ctx.lineWidth = 12
                                ctx.strokeStyle = Services.Colors.ghostAlpha(0.12)
                                ctx.beginPath(); ctx.arc(cx, cy, r, a0, a0 + sweep); ctx.stroke()
                                let frac = Math.max(0, Math.min(1, cpuGauge.percent / 100))
                                if (frac > 0) {
                                    ctx.strokeStyle = Services.Colors.ghost
                                    ctx.beginPath(); ctx.arc(cx, cy, r, a0, a0 + sweep * frac); ctx.stroke()
                                }
                            }
                            Component.onCompleted: requestPaint()
                            Connections {
                                target: cpuGauge
                                function onPercentChanged() { gaugeCanvas.requestPaint() }
                            }
                            Connections {
                                target: Services.Colors
                                function onGhostChanged() { gaugeCanvas.requestPaint() }
                            }
                        }

                        Column {
                            anchors.centerIn: parent
                            spacing: 0
                            Text {
                                text: Math.round(cpuGauge.percent) + "%"
                                color: Services.Colors.snow
                                font.pixelSize: 26
                                font.bold: true
                                font.family: "JetBrainsMono NF"
                                anchors.horizontalCenter: parent.horizontalCenter
                            }
                            Text {
                                text: "CPU"
                                color: Services.Colors.mist
                                font.pixelSize: 10
                                font.family: "JetBrainsMono NF"
                                anchors.horizontalCenter: parent.horizontalCenter
                            }
                            Text {
                                text: Services.SysMon.cpuTemp > 0 ? Services.SysMon.cpuTemp.toFixed(0) + "°C" : ""
                                color: Services.Colors.ash
                                font.pixelSize: 9
                                font.family: "JetBrainsMono NF"
                                anchors.horizontalCenter: parent.horizontalCenter
                                topPadding: 2
                            }
                        }
                    }

                    // filled sparkline: cpu over ram
                    Canvas {
                        id: graph
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        property var cpuHist: Services.SysMon.cpuHistory
                        property var ramHist: Services.SysMon.ramHistory
                        onCpuHistChanged: requestPaint()
                        onRamHistChanged: requestPaint()

                        function series(ctx, h, stroke, fill) {
                            if (!h || h.length < 2) return
                            let step = width / (h.length - 1)
                            ctx.beginPath()
                            ctx.moveTo(0, height - (h[0] / 100) * height)
                            for (let i = 1; i < h.length; i++)
                                ctx.lineTo(i * step, height - (h[i] / 100) * height)
                            ctx.strokeStyle = stroke
                            ctx.lineWidth = 2
                            ctx.stroke()
                            ctx.lineTo(width, height)
                            ctx.lineTo(0, height)
                            ctx.closePath()
                            ctx.fillStyle = fill
                            ctx.fill()
                        }

                        onPaint: {
                            let ctx = getContext("2d")
                            ctx.reset()
                            ctx.clearRect(0, 0, width, height)
                            ctx.strokeStyle = Services.Colors.ghostAlpha(0.08)
                            ctx.lineWidth = 1
                            for (let g = 1; g < 4; g++) {
                                let y = (height / 4) * g
                                ctx.beginPath(); ctx.moveTo(0, y); ctx.lineTo(width, y); ctx.stroke()
                            }
                            graph.series(ctx, ramHist, Services.Colors.mist, Services.Colors.ghostAlpha(0.07))
                            graph.series(ctx, cpuHist, Services.Colors.ghost, Services.Colors.ghostAlpha(0.16))
                        }
                    }
                }
            }

            // ── Memory · Graphics · Storage ────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Repeater {
                    model: [
                        { key: "ram",  label: "Memory",   icon: "" },
                        { key: "gpu",  label: "Graphics", icon: "" },
                        { key: "disk", label: "Storage",  icon: "" },
                    ]

                    delegate: Rectangle {
                        id: statCard
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.preferredHeight: 92
                        radius: 16
                        color: Services.Colors.ghostAlpha(0.06)

                        readonly property real percent: {
                            let m = Services.SysMon
                            if (modelData.key === "ram") return m.ramTotalMB > 0 ? (m.ramUsedMB / m.ramTotalMB) * 100 : 0
                            // dGPU asleep: show how hard the iGPU is clocking instead
                            if (modelData.key === "gpu") return m.dgpuAwake
                                ? m.gpuUsage
                                : (m.igpuMaxFreq > 0 ? (m.igpuFreq / m.igpuMaxFreq) * 100 : 0)
                            return m.diskPercent
                        }
                        readonly property string detail: {
                            let m = Services.SysMon
                            if (modelData.key === "ram") return (m.ramUsedMB / 1024).toFixed(1) + " / " + (m.ramTotalMB / 1024).toFixed(1) + " GB"
                            if (modelData.key === "gpu") return m.dgpuAwake
                                ? "dGPU" + (m.gpuTemp > 0 ? "  ·  " + m.gpuTemp.toFixed(0) + "°C" : "")
                                : "iGPU  ·  " + m.igpuFreq.toFixed(0) + " MHz  ·  dGPU asleep"
                            return m.diskUsedGB.toFixed(0) + " / " + m.diskTotalGB.toFixed(0) + " GB"
                        }
                        readonly property color accent: (modelData.key === "disk" && Services.SysMon.diskPercent >= 90)
                                                        ? Services.Colors.error_ : Services.Colors.ghost

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 6

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 6
                                Text {
                                    text: statCard.modelData.icon
                                    color: Services.Colors.mist
                                    font.pixelSize: 16
                                    font.family: "Material Symbols Rounded"
                                }
                                Text {
                                    text: statCard.modelData.label
                                    color: Services.Colors.mist
                                    font.pixelSize: 10
                                    font.family: "JetBrainsMono NF"
                                    Layout.fillWidth: true
                                }
                                Text {
                                    text: Math.round(statCard.percent) + "%"
                                    color: Services.Colors.snow
                                    font.pixelSize: 16
                                    font.bold: true
                                    font.family: "JetBrainsMono NF"
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 8
                                radius: 4
                                color: Services.Colors.ghostAlpha(0.12)
                                Rectangle {
                                    width: parent.width * Math.max(0, Math.min(1, statCard.percent / 100))
                                    height: parent.height
                                    radius: 4
                                    color: statCard.accent
                                    Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
                                }
                            }

                            Text {
                                text: statCard.detail
                                color: Services.Colors.ash
                                font.pixelSize: 9
                                font.family: "JetBrainsMono NF"
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }
                    }
                }
            }

            // ── Process list ───────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: "Top processes"
                    color: Services.Colors.mist
                    font.pixelSize: 11
                    font.family: "JetBrainsMono NF"
                    Layout.fillWidth: true
                }
                Text {
                    text: "CPU     MEM"
                    color: Services.Colors.ash
                    font.pixelSize: 9
                    font.family: "JetBrainsMono NF"
                    rightPadding: 38
                }
            }

            Flickable {
                Layout.fillWidth: true
                Layout.fillHeight: true
                contentHeight: procCol.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded; width: 4 }

                Column {
                    id: procCol
                    width: parent.width
                    spacing: 3

                    Repeater {
                        model: Services.SysMon.processes

                        delegate: Rectangle {
                            id: procRow
                            required property var modelData
                            width: procCol.width
                            height: 34
                            radius: 10
                            clip: true
                            color: procHover.containsMouse ? Services.Colors.ghostAlpha(0.1)
                                                           : Services.Colors.ghostAlpha(0.04)

                            // the row itself is the load bar
                            Rectangle {
                                anchors.left: parent.left
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                width: parent.width * Math.max(0, Math.min(1, procRow.modelData.cpu / 100))
                                radius: 10
                                color: Services.Colors.ghostAlpha(0.14)
                                Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
                            }

                            MouseArea {
                                id: procHover
                                anchors.fill: parent
                                hoverEnabled: true
                                acceptedButtons: Qt.NoButton
                            }

                            Text {
                                anchors.left: parent.left
                                anchors.leftMargin: 12
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - 215
                                text: procRow.modelData.name
                                color: Services.Colors.snow
                                font.pixelSize: 11
                                font.family: "JetBrainsMono NF"
                                elide: Text.ElideRight
                            }
                            Text {
                                anchors.right: memText.left
                                anchors.rightMargin: 16
                                anchors.verticalCenter: parent.verticalCenter
                                text: procRow.modelData.cpu.toFixed(1) + "%"
                                color: procRow.modelData.cpu > 20 ? Services.Colors.snow : Services.Colors.mist
                                font.pixelSize: 11
                                font.bold: procRow.modelData.cpu > 20
                                font.family: "JetBrainsMono NF"
                            }
                            Text {
                                id: memText
                                anchors.right: killBtn.left
                                anchors.rightMargin: 12
                                anchors.verticalCenter: parent.verticalCenter
                                text: procRow.modelData.mem.toFixed(1) + "%"
                                color: Services.Colors.mist
                                font.pixelSize: 11
                                font.family: "JetBrainsMono NF"
                            }
                            Rectangle {
                                id: killBtn
                                anchors.right: parent.right
                                anchors.rightMargin: 6
                                anchors.verticalCenter: parent.verticalCenter
                                width: 24; height: 24
                                radius: 8
                                opacity: procHover.containsMouse || killMouse.containsMouse ? 1 : 0
                                Behavior on opacity { NumberAnimation { duration: 120 } }
                                color: killMouse.containsMouse ? Services.Colors.ghostAlpha(0.22) : "transparent"
                                Text {
                                    anchors.centerIn: parent
                                    text: ""
                                    color: killMouse.containsMouse ? Services.Colors.error_ : Services.Colors.ash
                                    font.pixelSize: 14
                                    font.family: "Material Symbols Rounded"
                                }
                                MouseArea {
                                    id: killMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: Services.SysMon.kill(procRow.modelData.pid)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
