import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import "root:/services" as Services
import "root:/modules/widgets" as Widgets

PanelWindow {
    id: root
    anchors { top: true; left: true; right: true; bottom: true }
    screen: Services.Screens.active
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
        // The chip steps aside for as long as the panel wears its face.
        Services.AppState.processTakenOver = shown
        if (!shown) closeDelay.restart()
    }

    Timer { id: closeDelay; interval: card.closeMs }

    Component.onDestruction: Services.AppState.processTakenOver = false

    // ── Shared card furniture ───────────────────────────────────────────
    // Every reading on this panel is one of three shapes, so the shape is
    // written once here and the cards below only say what goes in it. The
    // old panel had each card carrying its own copy of the same column of
    // margins and corner radii, and they had already drifted apart.

    // A 270° dial with its reading in the middle. Used where the number is
    // the whole story (memory, storage) and there is no history worth
    // plotting next to it.
    component Ring: Item {
        id: ring
        property real percent: 0
        property string caption: "Used"
        property color accent: Services.Colors.ghost

        Canvas {
            id: ringCv
            anchors.fill: parent
            onPaint: {
                const ctx = getContext("2d")
                ctx.reset()
                const cx = width / 2, cy = height / 2
                const r = (Math.min(width, height) - 11) / 2
                // Open at the bottom, so the gap reads as the start of the run
                const a0 = Math.PI * 0.75
                const sweep = Math.PI * 1.5
                ctx.lineCap = "round"
                ctx.lineWidth = 9
                ctx.strokeStyle = Services.Colors.ghostAlpha(0.12)
                ctx.beginPath(); ctx.arc(cx, cy, r, a0, a0 + sweep); ctx.stroke()
                const f = Math.max(0, Math.min(1, ring.percent / 100))
                if (f > 0) {
                    ctx.strokeStyle = ring.accent
                    ctx.beginPath(); ctx.arc(cx, cy, r, a0, a0 + sweep * f); ctx.stroke()
                }
            }
            Component.onCompleted: requestPaint()
            // Canvas has no binding to repaint on: every input needs saying.
            Connections {
                target: ring
                function onPercentChanged() { ringCv.requestPaint() }
                function onAccentChanged() { ringCv.requestPaint() }
            }
            Connections {
                target: Services.Colors
                function onGhostChanged() { ringCv.requestPaint() }
            }
        }

        Column {
            anchors.centerIn: parent
            spacing: 0
            Text {
                text: Math.round(ring.percent) + "%"
                color: Services.Colors.snow
                font.pixelSize: 20
                font.bold: true
                font.family: "JetBrainsMono NF"
                anchors.horizontalCenter: parent.horizontalCenter
            }
            Text {
                text: ring.caption
                color: Services.Colors.mist
                font.pixelSize: 9
                font.family: "JetBrainsMono NF"
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        z: -1
        onClicked: Services.AppState.processVisible = false
    }

    // The same drop the clock and every system chip opens with -- the shared
    // component, not another copy of the maths. Its pill is a chip on the
    // utility trigger rather than one on the bar, so it names that edge and
    // where it lands; everything else is identical. The utility pill can turn
    // up on any of the three edges the bar is not on, so both follow it there.
    // Live from the pill, not a value written when something was clicked:
    // a keybind never clicks, and the panel used to grow from wherever the
    // last click had left the numbers.
    readonly property var chip: Services.AppState.utilChipOf(root.srcEdge, "process")
    readonly property string srcEdge: Services.AppState.processSourceEdge
    readonly property real openXCalc: srcEdge === "left" ? Services.Sizes.panelTop
        : srcEdge === "right" ? root.width - card.openW - Services.Sizes.panelTop
        : (root.width - card.openW) / 2
    readonly property real openYCalc: srcEdge === "top" ? Services.Sizes.panelTop
        : srcEdge === "bottom" ? root.height - card.openH - Math.max(68, Services.Sizes.marginBottom + 18)
        : (root.height - card.openH) / 2

    Widgets.DropCard {
        id: card
        shown: root.shown
        sourceEdge: root.srcEdge
        openXOverride: root.openXCalc
        openYOverride: root.openYCalc

        pillCX: (root.chip ? root.chip.cx : 0)
        pillCY: (root.chip ? root.chip.cy : 0)
        pillW: (root.chip ? root.chip.w : 44)
        pillH: (root.chip ? root.chip.h : 44)

        // Wide rather than tall: the readings tile across the left, the live
        // process list runs down the right. The old portrait card stacked the
        // two and neither had the room it wanted.
        openW: Math.min(1080, root.width - 80)
        openH: Math.min(560, root.height - 120)
        cardRadius: 22

        RowLayout {
            anchors.fill: parent
            anchors.margins: 18
            spacing: 16

            // ── Left: what the machine is doing ────────────────
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 12

                // No head: the cards below say what they are, and a 40 px
                // icon over "Process" only repeated the pill you came from.
                // The chip it is all running on is worth a line; the title
                // was not.
                Text {
                    opacity: card.contentAmt
                    Layout.fillWidth: true
                    text: Services.SysMon.cpuModel
                    color: Services.Colors.ash
                    font.pixelSize: Services.Sizes.fsMeta
                    font.family: "JetBrainsMono NF"
                    elide: Text.ElideRight
                }

                // ── Row 1: the two live loads ──────────────────
                // CPU and GPU both have a history worth plotting, so they get
                // the wide card with a plot under the reading. Memory and
                // storage do not move like that and get dials instead.
                RowLayout {
                    Layout.fillWidth: true
                    // Explicit: a Layout inside a Layout fills by default, and
                    // with that on it swallowed the whole column and pushed the
                    // dials off the bottom of the card.
                    Layout.fillHeight: false
                    Layout.preferredHeight: 150
                    spacing: 12

                    Rectangle {
                        opacity: card.contentAmt
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: 18
                        color: Services.Colors.ghostAlpha(0.06)

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 14
                            spacing: 8

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 10
                                Rectangle {
                                    Layout.preferredWidth: 34
                                    Layout.preferredHeight: 34
                                    radius: 11
                                    color: Services.Colors.ghostAlpha(0.14)
                                    Text {
                                        anchors.centerIn: parent
                                        text: ""
                                        color: Services.Colors.ghost
                                        font.pixelSize: 18
                                        font.family: "Material Symbols Rounded"
                                    }
                                }
                                ColumnLayout {
                                    spacing: 0
                                    Layout.fillWidth: true
                                    Text {
                                        text: "CPU"
                                        color: Services.Colors.snow
                                        font.pixelSize: 14
                                        font.bold: true
                                        font.family: "JetBrainsMono NF"
                                    }
                                    Text {
                                        text: "load"
                                        color: Services.Colors.mist
                                        font.pixelSize: 9
                                        font.family: "JetBrainsMono NF"
                                    }
                                }
                                Text {
                                    text: Math.round(Services.SysMon.cpuPercent) + "%"
                                    color: Services.Colors.snow
                                    font.pixelSize: 20
                                    font.bold: true
                                    font.family: "JetBrainsMono NF"
                                }
                            }

                            Widgets.Sparkline {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                primary: Services.SysMon.cpuHistory
                                gridLines: 2
                            }
                        }
                    }

                    Rectangle {
                        opacity: card.contentAmt
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: 18
                        color: Services.Colors.ghostAlpha(0.06)

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 14
                            spacing: 8

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 10
                                Rectangle {
                                    Layout.preferredWidth: 34
                                    Layout.preferredHeight: 34
                                    radius: 11
                                    color: Services.Colors.ghostAlpha(0.14)
                                    Text {
                                        anchors.centerIn: parent
                                        text: ""
                                        color: Services.Colors.ghost
                                        font.pixelSize: 18
                                        font.family: "Material Symbols Rounded"
                                    }
                                }
                                ColumnLayout {
                                    spacing: 0
                                    Layout.fillWidth: true
                                    Text {
                                        text: "GPU"
                                        color: Services.Colors.snow
                                        font.pixelSize: 14
                                        font.bold: true
                                        font.family: "JetBrainsMono NF"
                                    }
                                    Text {
                                        text: Services.SysMon.dgpuAwake ? "dGPU" : "iGPU"
                                        color: Services.Colors.mist
                                        font.pixelSize: 9
                                        font.family: "JetBrainsMono NF"
                                    }
                                }
                                Text {
                                    text: Math.round(Services.SysMon.gpuPercent) + "%"
                                    color: Services.Colors.snow
                                    font.pixelSize: 20
                                    font.bold: true
                                    font.family: "JetBrainsMono NF"
                                }
                            }

                            Widgets.Sparkline {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                primary: Services.SysMon.gpuHistory
                                gridLines: 2
                            }
                        }
                    }
                }

                // ── Row 2: the readings with no history ────────
                // Memory, storage and the temperatures: none of these moves in
                // a way a plot would say anything about, so each shows the
                // reading itself instead of a graph of it.
                RowLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: false
                    Layout.preferredHeight: 180
                    spacing: 12

                    Rectangle {
                        opacity: card.contentAmt
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: 18
                        color: Services.Colors.ghostAlpha(0.06)

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 14
                            spacing: 6

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8
                                Text {
                                    text: "\ue30d"
                                    color: Services.Colors.mist
                                    font.pixelSize: 16
                                    font.family: "Material Symbols Rounded"
                                }
                                Text {
                                    text: "Memory"
                                    color: Services.Colors.snow
                                    font.pixelSize: 13
                                    font.bold: true
                                    font.family: "JetBrainsMono NF"
                                    Layout.fillWidth: true
                                }
                            }

                            Ring {
                                Layout.alignment: Qt.AlignHCenter
                                Layout.fillHeight: true
                                Layout.preferredWidth: 118
                                Layout.preferredHeight: 118
                                percent: Services.SysMon.ramTotalMB > 0
                                    ? (Services.SysMon.ramUsedMB / Services.SysMon.ramTotalMB) * 100 : 0
                            }

                            Text {
                                text: (Services.SysMon.ramUsedMB / 1024).toFixed(1) + " / "
                                      + (Services.SysMon.ramTotalMB / 1024).toFixed(1) + " GB"
                                color: Services.Colors.ash
                                font.pixelSize: 9
                                font.family: "JetBrainsMono NF"
                                Layout.alignment: Qt.AlignHCenter
                            }
                        }
                    }

                    Rectangle {
                        opacity: card.contentAmt
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: 18
                        color: Services.Colors.ghostAlpha(0.06)

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 14
                            spacing: 6

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8
                                Text {
                                    text: "\ue1db"
                                    color: Services.Colors.mist
                                    font.pixelSize: 16
                                    font.family: "Material Symbols Rounded"
                                }
                                Text {
                                    text: "Storage"
                                    color: Services.Colors.snow
                                    font.pixelSize: 13
                                    font.bold: true
                                    font.family: "JetBrainsMono NF"
                                    Layout.fillWidth: true
                                }
                            }

                            Ring {
                                Layout.alignment: Qt.AlignHCenter
                                Layout.fillHeight: true
                                Layout.preferredWidth: 118
                                Layout.preferredHeight: 118
                                percent: Services.SysMon.diskPercent
                                // Past nine tenths full it stops being a
                                // reading and starts being a warning.
                                accent: Services.SysMon.diskPercent >= 90
                                    ? Services.Colors.error_ : Services.Colors.ghost
                            }

                            Text {
                                text: Services.SysMon.diskUsedGB.toFixed(0) + " / "
                                      + Services.SysMon.diskTotalGB.toFixed(0) + " GB"
                                color: Services.Colors.ash
                                font.pixelSize: 9
                                font.family: "JetBrainsMono NF"
                                Layout.alignment: Qt.AlignHCenter
                            }
                        }
                    }

                    // Both temperatures in one place. They used to hang off the
                    // CPU and GPU cards as a line of small print each, which
                    // put the one reading you check when the fans spin up in
                    // the two places you were least likely to look.
                    Rectangle {
                        opacity: card.contentAmt
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: 18
                        color: Services.Colors.ghostAlpha(0.06)

                        // A die is happy to about 80 and in trouble past 90, so
                        // the bar is read against 100 and goes red at 80.
                        component TempRow: ColumnLayout {
                            id: tr
                            property string label: ""
                            property real value: 0
                            property bool known: true
                            spacing: 3

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 6
                                Text {
                                    text: tr.label
                                    color: Services.Colors.mist
                                    font.pixelSize: 10
                                    font.family: "JetBrainsMono NF"
                                    Layout.fillWidth: true
                                }
                                Text {
                                    text: tr.known ? tr.value.toFixed(0) + "°C" : "--"
                                    color: tr.value >= 80 ? Services.Colors.error_ : Services.Colors.snow
                                    font.pixelSize: 15
                                    font.bold: true
                                    font.family: "JetBrainsMono NF"
                                }
                            }
                            Rectangle {
                                Layout.fillWidth: true
                                height: 6
                                radius: 3
                                color: Services.Colors.ghostAlpha(0.12)
                                Rectangle {
                                    width: parent.width * Math.max(0, Math.min(1, tr.value / 100))
                                    height: parent.height
                                    radius: 3
                                    color: tr.value >= 80 ? Services.Colors.error_ : Services.Colors.ghost
                                    Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
                                }
                            }
                        }

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 14
                            spacing: 10

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8
                                Text {
                                    text: "\ue1ff"
                                    color: Services.Colors.mist
                                    font.pixelSize: 16
                                    font.family: "Material Symbols Rounded"
                                }
                                Text {
                                    text: "Temperature"
                                    color: Services.Colors.snow
                                    font.pixelSize: 13
                                    font.bold: true
                                    font.family: "JetBrainsMono NF"
                                    Layout.fillWidth: true
                                }
                            }

                            Item { Layout.fillHeight: true }

                            TempRow {
                                Layout.fillWidth: true
                                label: "CPU"
                                value: Services.SysMon.cpuTemp
                                known: Services.SysMon.cpuTemp > 0
                            }
                            // A sleeping dGPU reports nothing, and waking it to
                            // ask would cost more battery than the number is
                            // worth -- so it says so rather than showing a zero.
                            TempRow {
                                Layout.fillWidth: true
                                label: Services.SysMon.dgpuAwake ? "GPU" : "GPU (asleep)"
                                value: Services.SysMon.gpuTemp
                                known: Services.SysMon.dgpuAwake && Services.SysMon.gpuTemp > 0
                            }

                            Item { Layout.fillHeight: true }
                        }
                    }
                }

                // ── Row 3: the link ───────────────────────────
                // Full width, because a rate is only worth reading as a shape
                // over time and the plot needs the run to show one.
                Rectangle {
                    opacity: card.contentAmt
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: 18
                    color: Services.Colors.ghostAlpha(0.06)

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 14

                        ColumnLayout {
                            // Explicit: a Layout nested in a Layout fills by
                            // default, so this took half the card and left the
                            // plot squeezed into the rest -- the readings ran
                            // out of room and the trace looked clipped.
                            Layout.fillWidth: false
                            Layout.preferredWidth: 150
                            spacing: 2

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8
                                Text {
                                    text: Services.Network.wifiSsid !== ""
                                        ? (Services.Network.wifiSignal >= 75 ? "\ue1ba"
                                         : Services.Network.wifiSignal >= 50 ? "\uebe1"
                                         : Services.Network.wifiSignal >= 25 ? "\uebd6" : "\uebe4")
                                        : (Services.Network.ethConnection !== "" ? "\ueb2f" : "\ue648")
                                    color: Services.Network.online ? Services.Colors.ghost : Services.Colors.ash
                                    font.pixelSize: 16
                                    font.family: "Material Symbols Rounded"
                                }
                                Text {
                                    text: "Network"
                                    color: Services.Colors.snow
                                    font.pixelSize: 13
                                    font.bold: true
                                    font.family: "JetBrainsMono NF"
                                    Layout.fillWidth: true
                                }
                            }

                            Text {
                                text: Services.Network.wifiSsid !== ""
                                      ? Services.Network.wifiSsid
                                      : (Services.Network.ethConnection !== ""
                                         ? Services.Network.ethDevice : "Offline")
                                color: Services.Colors.mist
                                font.pixelSize: 9
                                font.family: "JetBrainsMono NF"
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8
                                Text {
                                    text: "↓ " + Services.SysMon.netRxKBs.toFixed(0)
                                    color: Services.Colors.snow
                                    font.pixelSize: 10
                                    font.bold: true
                                    font.family: "JetBrainsMono NF"
                                }
                                Text {
                                    text: "↑ " + Services.SysMon.netTxKBs.toFixed(0) + " KB/s"
                                    color: Services.Colors.mist
                                    font.pixelSize: 10
                                    font.family: "JetBrainsMono NF"
                                }
                            }
                        }

                        Widgets.Sparkline {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            primary: Services.SysMon.netRxHistory
                            secondary: Services.SysMon.netTxHistory
                            autoScale: true
                            minTop: 64
                            lineWidth: 1.5
                        }
                    }
                }
            }

            // ── Right: what is running, and what can be stopped ─
            ColumnLayout {
                // Explicit again: a Layout nested in a Layout fills by default,
                // so preferredWidth alone was ignored and this column took an
                // even share of the card instead of the strip it asks for.
                Layout.fillWidth: false
                Layout.preferredWidth: 420
                Layout.fillHeight: true
                spacing: 12

                // Same head as the left column, so the two columns start on
                // the same line and read as one panel rather than two.
                Text {
                    opacity: card.contentAmt
                    Layout.fillWidth: true
                    text: Services.SysMon.processes.length + " running  ·  by CPU"
                    color: Services.Colors.ash
                    font.pixelSize: Services.Sizes.fsMeta
                    font.family: "JetBrainsMono NF"
                }

                RowLayout {
                    opacity: card.contentAmt
                    Layout.fillWidth: true
                    Text {
                        text: "Name"
                        color: Services.Colors.mist
                        font.pixelSize: 9
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
                    opacity: card.contentAmt
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
                                Widgets.IconButton {
                                    id: killBtn
                                    anchors.right: parent.right
                                    anchors.rightMargin: 6
                                    anchors.verticalCenter: parent.verticalCenter
                                    size: 24
                                    glyph: "\ue5cd"
                                    // Only offered on the row being pointed at: a kill button on
                                    // every line at once makes the list look like a minefield.
                                    opacity: procHover.containsMouse || killBtn.hovered ? 1 : 0
                                    visible: opacity > 0.01
                                    Behavior on opacity { NumberAnimation { duration: 120 } }
                                    onActivated: Services.SysMon.kill(procRow.modelData.pid)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
