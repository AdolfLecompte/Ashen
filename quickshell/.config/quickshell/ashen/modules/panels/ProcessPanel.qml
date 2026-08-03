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

    // Clicking anywhere off the card closes it, the same as every other panel.
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
    readonly property string srcEdge: Services.AppState.processSourceEdge
    // Its chip: on the utility pill of that edge, or on the bar.
    readonly property var chipRect: Services.AppState.chipRectOf("process", root.srcEdge)
    readonly property real openXCalc: srcEdge === "" ? NaN
        : srcEdge === "left" ? Services.Sizes.panelTop
        : srcEdge === "right" ? root.width - card.openW - Services.Sizes.panelTop
        : (root.width - card.openW) / 2
    readonly property real openYCalc: srcEdge === "" ? NaN
        : srcEdge === "top" ? Services.Sizes.panelTop
        : srcEdge === "bottom" ? root.height - card.openH - Math.max(68, Services.Sizes.marginBottom + 18)
        : (root.height - card.openH) / 2

    Widgets.PanelHost {
        id: card
        shown: root.shown
        sourceEdge: root.srcEdge
        openXOverride: root.openXCalc
        openYOverride: root.openYCalc

        pillCX: root.chipRect.cx
        pillCY: root.chipRect.cy
        pillW: root.chipRect.w
        pillH: root.chipRect.h

        // Laid out like the board itself: the socket square, the card long,
        // the memory a tall stick, the drive a wide slab, and the two probes
        // narrow columns down the side.
        readonly property int cell: 116
        readonly property int gap: 12
        readonly property int pad: 22
        function span(n) { return n * cell + (n - 1) * gap }
        openW: span(8) + pad * 2
        openH: span(3) + pad * 2 + 22
        cardRadius: 22

        pillKey: "process"
        restSide: "bottom"


        body: Component {
            Item {
                id: bodyRoot

                function stage(i) {
                    const start = Math.min(0.5, i * 0.09)
                    return Math.max(0, Math.min(1, (card.contentAmt - start) / (1 - start)))
                }

                // One reading, one vessel. It says which cell it starts in
                // and how many it covers; the shape follows from that.
                component Tank: Rectangle {
                    id: tank
                    property string glyph: ""
                    property string title: ""
                    // 0..1, how full the vessel is
                    property real level: 0
                    property string reading: ""
                    property string sub: ""
                    property bool alarm: false
                    property int index: 0
                    // Place on the grid: column, row, and how many cells wide
                    // and tall.
                    property int col: 0
                    property int row: 0
                    property int cw: 1
                    property int ch: 1
                    // Tall and narrow: the reading goes under the glyph rather
                    // than beside it, and the name sits at the foot.
                    readonly property bool tall: ch > cw

                    x: col * (card.cell + card.gap)
                    y: row * (card.cell + card.gap)
                    width: card.span(cw)
                    height: card.span(ch)
                    radius: Services.Sizes.cardLgR
                    color: Services.Colors.fillInset
                    clip: true
                    opacity: bodyRoot.stage(index)
                    transform: Translate { y: (1 - bodyRoot.stage(tank.index)) * 12 }

                    readonly property color tone: tank.alarm ? Services.Colors.error_
                                                             : Services.Colors.ghost

                    Widgets.LiquidFill {
                        anchors.fill: parent
                        shape: "rect"
                        radius_: tank.radius
                        level: tank.level
                        // A narrow vessel takes a smaller swell, or the wave is
                        // taller than the column is wide.
                        waveAmp: tank.tall ? 2.5 : 4
                        periodMs: 5200
                        running: root.shown
                        color_: Qt.rgba(tank.tone.r, tank.tone.g, tank.tone.b, 0.30)
                    }

                    Column {
                        anchors.centerIn: parent
                        width: parent.width - 12
                        spacing: tank.tall ? 6 : 4

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: tank.glyph
                            color: tank.tone
                            font.pixelSize: tank.cw >= 2 && tank.ch >= 2 ? 34 : 22
                            font.family: "Material Symbols Rounded"
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: tank.reading
                            color: Services.Colors.snow
                            font.pixelSize: tank.cw >= 2 && tank.ch >= 2
                                ? Services.Sizes.fsHero : Services.Sizes.fsReadout
                            font.bold: true
                            font.family: "JetBrainsMono NF"
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            text: tank.title
                            color: Services.Colors.mist
                            font.pixelSize: Services.Sizes.fsBody
                            font.bold: true
                            font.family: "JetBrainsMono NF"
                            elide: Text.ElideRight
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            text: tank.sub
                            visible: tank.sub !== ""
                            color: Services.Colors.ash
                            font.pixelSize: Services.Sizes.fsMeta
                            font.family: "JetBrainsMono NF"
                            elide: Text.ElideRight
                        }
                    }
                }

                Text {
                    id: chipLine
                    opacity: card.contentAmt
                    x: card.pad
                    y: card.pad - 2
                    width: parent.width - card.pad * 2
                    text: Services.SysMon.cpuModel
                    color: Services.Colors.ash
                    font.pixelSize: Services.Sizes.fsMeta
                    font.family: "JetBrainsMono NF"
                    elide: Text.ElideRight
                }

                Item {
                    x: card.pad
                    y: card.pad + 22
                    width: card.span(8)
                    height: card.span(3)

                    // The socket: square, and the biggest thing on the board.
                    Tank {
                        index: 0
                        col: 0; row: 0; cw: 2; ch: 2
                        glyph: "\ue322"
                        title: "CPU"
                        level: Services.SysMon.cpuPercent / 100
                        reading: Math.round(Services.SysMon.cpuPercent) + "%"
                    }
                    // The NIC: small, off in a corner, like the real one.
                    Tank {
                        index: 1
                        col: 0; row: 2; cw: 2; ch: 1
                        glyph: "\ue894"
                        title: "Network"
                        // Throughput has no ceiling of its own, so it is read
                        // against 5 MB/s: near empty at rest, full on a real
                        // download.
                        level: Math.min(1, (Services.SysMon.netRxKBs + Services.SysMon.netTxKBs) / 5000)
                        reading: {
                            const kb = Services.SysMon.netRxKBs + Services.SysMon.netTxKBs
                            return kb >= 1024 ? (kb / 1024).toFixed(1) + " MB/s"
                                              : Math.round(kb) + " KB/s"
                        }
                        sub: "\u2193 " + Math.round(Services.SysMon.netRxKBs)
                             + "   \u2191 " + Math.round(Services.SysMon.netTxKBs) + " KB/s"
                    }
                    // The DIMM: one tall thin stick standing in its slot.
                    Tank {
                        index: 2
                        col: 2; row: 0; cw: 1; ch: 3
                        glyph: "\ue30d"
                        title: "RAM"
                        level: Services.SysMon.ramTotalMB > 0
                            ? Services.SysMon.ramUsedMB / Services.SysMon.ramTotalMB : 0
                        reading: Services.SysMon.ramTotalMB > 0
                            ? Math.round(Services.SysMon.ramUsedMB / Services.SysMon.ramTotalMB * 100) + "%" : "--"
                        sub: (Services.SysMon.ramUsedMB / 1024).toFixed(1) + "G"
                    }
                    // The card: long, and the second biggest thing here.
                    Tank {
                        index: 3
                        col: 3; row: 0; cw: 3; ch: 2
                        glyph: "\ue30a"
                        title: "GPU"
                        level: Services.SysMon.gpuPercent / 100
                        reading: Math.round(Services.SysMon.gpuPercent) + "%"
                        sub: Services.SysMon.dgpuAwake ? "Discrete" : "Integrated"
                    }
                    // The drive: a wide flat slab under the card.
                    Tank {
                        index: 4
                        col: 3; row: 2; cw: 3; ch: 1
                        glyph: "\ue1db"
                        title: "Storage"
                        level: Services.SysMon.diskPercent / 100
                        reading: Services.SysMon.diskPercent + "%"
                        sub: Math.round(Services.SysMon.diskUsedGB) + " / "
                             + Math.round(Services.SysMon.diskTotalGB) + " GB"
                        // Disk filling up is the one thing here that is
                        // actually going wrong.
                        alarm: Services.SysMon.diskPercent >= 90
                    }
                    // The two probes: read against 100 degrees, turning at 80.
                    Tank {
                        index: 5
                        col: 6; row: 0; cw: 1; ch: 3
                        glyph: "\ue1ff"
                        title: "CPU"
                        level: Services.SysMon.cpuTemp / 100
                        reading: Services.SysMon.cpuTemp > 0
                            ? Services.SysMon.cpuTemp.toFixed(0) + "\u00b0" : "--"
                        alarm: Services.SysMon.cpuTemp >= 80
                    }
                    Tank {
                        index: 6
                        col: 7; row: 0; cw: 1; ch: 3
                        glyph: "\ue1ff"
                        title: "GPU"
                        level: Services.SysMon.gpuTemp / 100
                        reading: Services.SysMon.gpuTemp > 0
                            ? Services.SysMon.gpuTemp.toFixed(0) + "\u00b0" : "--"
                        alarm: Services.SysMon.gpuTemp >= 80
                    }
                }
            }
        }
    }
}
