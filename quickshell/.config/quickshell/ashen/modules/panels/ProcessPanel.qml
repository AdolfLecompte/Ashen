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
        // The chip steps aside for as long as the panel wears its face -- and
        // in "window" style it never does.
        Services.AppState.processTakenOver = shown && card.wearingFace
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

    // The same drop the clock and the system chips open with. Its pill is a
    // chip on the utility trigger, so the edge is read live from the pill
    // rather than written at click time: a keybind never clicks.
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

        // A board of cards, each saying its own kind of thing: a history worth
        // drawing, a proportion of something fixed, readings in rings, a vessel.
        // Seven identical liquid boxes made this panel read as a spreadsheet.
        readonly property int cell: 116
        readonly property int gap: 12
        readonly property int pad: 22
        function span(n) { return n * cell + (n - 1) * gap }
        openW: span(8) + pad * 2
        openH: span(3) + pad * 2 + 40
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

                // Every card on the board: its place on the grid, its name in
                // the corner, and its own beat in the arrival.
                component Card: Rectangle {
                    id: cd
                    property string glyph: ""
                    property string name: ""
                    property int index: 0
                    property int col: 0
                    property int row: 0
                    property int cw: 1
                    property int ch: 1
                    // What a card puts in its top-right: a part number, a
                    // percentage, whatever it is the name does not say.
                    property string note: ""
                    // Where a card's own content can start.
                    readonly property int headH: 40
                    readonly property int inset: 14

                    x: col * (card.cell + card.gap)
                    y: row * (card.cell + card.gap)
                    width: card.span(cw)
                    height: card.span(ch)
                    radius: Services.Sizes.cardLgR
                    // Opaque: a translucent plate took its colour from whatever
                    // wallpaper happened to be behind the panel.
                    color: Services.Colors.tint(Services.Colors.surface,
                                                Services.Colors.ghost, 0.07)
                    clip: true
                    opacity: bodyRoot.stage(index)
                    transform: Translate { y: (1 - bodyRoot.stage(cd.index)) * 12 }

                    Row {
                        id: cdHead
                        x: cd.inset
                        y: cd.inset
                        spacing: 8
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: cd.glyph
                            color: Services.Colors.mist
                            font.pixelSize: 16
                            font.family: "Material Symbols Rounded"
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: cd.name
                            color: Services.Colors.mist
                            font.pixelSize: Services.Sizes.fsCaption
                            font.bold: true
                            font.letterSpacing: 1.4
                            font.family: "JetBrainsMono NF"
                        }
                    }
                    Text {
                        anchors.right: parent.right
                        anchors.rightMargin: cd.inset
                        anchors.verticalCenter: cdHead.verticalCenter
                        width: Math.min(implicitWidth, cd.width - cdHead.width - cd.inset * 3)
                        horizontalAlignment: Text.AlignRight
                        text: cd.note
                        visible: cd.note !== ""
                        color: Services.Colors.ash
                        font.pixelSize: Services.Sizes.fsMeta
                        font.family: "JetBrainsMono NF"
                        elide: Text.ElideRight
                    }
                }

                // A proportion of something with a known ceiling: how much of
                // the memory, how much of the drive. A ring would claim these
                // are readings that move; they crawl.
                component Meter: Item {
                    id: mtr
                    property real level: 0
                    property color tone: Services.Colors.ghost
                    property string leftNote: ""
                    property string rightNote: ""
                    height: 22

                    Rectangle {
                        id: track
                        width: parent.width
                        height: 8
                        radius: 4
                        color: Services.Colors.fillLine
                        Rectangle {
                            width: Math.max(height, parent.width * Math.max(0, Math.min(1, mtr.level)))
                            height: parent.height
                            radius: parent.radius
                            color: mtr.tone
                            gradient: Services.Prefs.useGradients
                                ? Services.Colors.accentGradient : null
                            Behavior on width {
                                NumberAnimation { duration: Services.Sizes.msPronounced
                                                  easing.type: Services.Sizes.easeOut }
                            }
                        }
                    }
                    Text {
                        anchors.left: parent.left
                        anchors.top: track.bottom
                        anchors.topMargin: 4
                        text: mtr.leftNote
                        color: Services.Colors.ash
                        font.pixelSize: Services.Sizes.fsCaption
                        font.family: "JetBrainsMono NF"
                    }
                    Text {
                        anchors.right: parent.right
                        anchors.top: track.bottom
                        anchors.topMargin: 4
                        text: mtr.rightNote
                        color: Services.Colors.ash
                        font.pixelSize: Services.Sizes.fsCaption
                        font.family: "JetBrainsMono NF"
                    }
                }

                // The panel says its own name, like every other one.
                Item {
                    id: head
                    x: card.pad
                    y: card.pad - 4
                    width: parent.width - card.pad * 2
                    height: 26
                    opacity: card.contentAmt

                    Text {
                        id: headTitle
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: "System"
                        color: Services.Colors.snow
                        font.pixelSize: Services.Sizes.fsCardTitle
                        font.bold: true
                        font.family: "JetBrainsMono NF"
                    }
                    Rectangle {
                        anchors.left: headTitle.right
                        anchors.leftMargin: 12
                        anchors.right: headUp.left
                        anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        height: 1
                        color: Services.Colors.fillLine
                    }
                    // A pulse rather than a word: the board is live, and it says
                    // so the way the recording pill does.
                    Row {
                        id: headUp
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 6
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 6; height: 6; radius: 3
                            color: Services.Colors.ghost
                            SequentialAnimation on opacity {
                                running: root.shown
                                loops: Animation.Infinite
                                NumberAnimation { to: 0.25; duration: 900; easing.type: Services.Sizes.easeLoop }
                                NumberAnimation { to: 1; duration: 900; easing.type: Services.Sizes.easeLoop }
                            }
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "LIVE"
                            color: Services.Colors.ash
                            font.pixelSize: Services.Sizes.fsCaption
                            font.bold: true
                            font.letterSpacing: 1.4
                            font.family: "JetBrainsMono NF"
                        }
                    }
                }

                Item {
                    x: card.pad
                    y: card.pad + 36
                    width: card.span(8)
                    height: card.span(3)

                    // ── CPU: the one reading with a past worth drawing ──
                    Card {
                        id: cpuCard
                        index: 0
                        col: 0; row: 0; cw: 5; ch: 2
                        glyph: ""
                        name: "CPU USAGE"
                        note: Services.SysMon.cpuModel

                        Text {
                            id: cpuNum
                            x: cpuCard.inset
                            y: cpuCard.headH
                            text: Math.round(Services.SysMon.cpuPercent) + "%"
                            color: Services.Colors.snow
                            font.pixelSize: Services.Sizes.fsHero
                            font.bold: true
                            font.family: "JetBrainsMono NF"
                        }
                        Text {
                            anchors.left: cpuNum.right
                            anchors.leftMargin: 12
                            anchors.baseline: cpuNum.baseline
                            text: Services.SysMon.cpuTemp > 0
                                ? Services.SysMon.cpuTemp.toFixed(0) + "° now"
                                : ""
                            color: Services.Colors.ash
                            font.pixelSize: Services.Sizes.fsMeta
                            font.family: "JetBrainsMono NF"
                        }

                        // The history fills the floor of the card: the line is
                        // the point of this one, not a decoration beside it.
                        Widgets.Trend {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            height: parent.height - cpuCard.headH - 52
                            values: Services.SysMon.cpuHistory
                            maxValue: 100
                            color_: Services.Colors.ghost
                        }
                    }

                    // ── Memory: a proportion of something fixed ──
                    Card {
                        index: 1
                        col: 5; row: 0; cw: 3; ch: 1
                        glyph: ""
                        name: "MEMORY"
                        id: ramCard

                        Text {
                            id: ramNum
                            x: ramCard.inset
                            y: ramCard.headH - 4
                            text: Services.SysMon.ramTotalMB > 0
                                ? Math.round(Services.SysMon.ramUsedMB / Services.SysMon.ramTotalMB * 100) + "%"
                                : "--"
                            color: Services.Colors.snow
                            font.pixelSize: Services.Sizes.fsReadout
                            font.bold: true
                            font.family: "JetBrainsMono NF"
                        }
                        Text {
                            anchors.left: ramNum.right
                            anchors.leftMargin: 10
                            anchors.baseline: ramNum.baseline
                            text: (Services.SysMon.ramUsedMB / 1024).toFixed(1) + " / "
                                  + (Services.SysMon.ramTotalMB / 1024).toFixed(1) + " GB in use"
                            color: Services.Colors.mist
                            font.pixelSize: Services.Sizes.fsMeta
                            font.family: "JetBrainsMono NF"
                        }
                        Meter {
                            x: ramCard.inset
                            width: parent.width - ramCard.inset * 2
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 12
                            level: Services.SysMon.ramTotalMB > 0
                                ? Services.SysMon.ramUsedMB / Services.SysMon.ramTotalMB : 0
                            leftNote: "0"
                            rightNote: Math.round(Services.SysMon.ramTotalMB / 1024) + "GB"
                        }
                    }

                    // ── Thermals: two readings, two rings ──
                    Card {
                        index: 2
                        col: 5; row: 1; cw: 3; ch: 1
                        glyph: ""
                        name: "THERMALS"
                        id: thermCard

                        // Centred, not shoved against the right edge: the
                        // name sits above them, not beside them.
                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.top: parent.top
                            anchors.topMargin: thermCard.headH - 14
                            spacing: 14

                            Widgets.DialGauge {
                                size: 86
                                lw: 8
                                labelSize: 17
                                captionSize: 9
                                glyph: ""
                                // Read against 100 degrees, turning at 80.
                                value: Math.max(0, Math.min(1, Services.SysMon.cpuTemp / 100))
                                label: Services.SysMon.cpuTemp > 0
                                    ? Services.SysMon.cpuTemp.toFixed(0) + "°" : "--"
                                caption: "CPU"
                                armed: root.shown
                                fillColor: Services.SysMon.cpuTemp >= 80
                                    ? Services.Colors.error_ : Services.Colors.ghost
                            }
                            Widgets.DialGauge {
                                size: 86
                                lw: 8
                                labelSize: 17
                                captionSize: 9
                                glyph: ""
                                value: Math.max(0, Math.min(1, Services.SysMon.gpuTemp / 100))
                                label: Services.SysMon.gpuTemp > 0
                                    ? Services.SysMon.gpuTemp.toFixed(0) + "°" : "--"
                                caption: "GPU"
                                armed: root.shown
                                fillColor: Services.SysMon.gpuTemp >= 80
                                    ? Services.Colors.error_ : Services.Colors.ghost
                            }
                        }
                    }

                    // ── GPU: the card that stays a vessel ──
                    Card {
                        index: 3
                        col: 0; row: 2; cw: 3; ch: 1
                        glyph: ""
                        name: "GPU"
                        id: gpuCard

                        readonly property color tone: Services.Colors.ghost
                        readonly property color liquidCol: gpuCard.tone
                        readonly property color wetInk: Services.Colors.onColor(gpuCard.liquidCol)

                        Widgets.LiquidFill {
                            id: gpuLiquid
                            anchors.fill: parent
                            shape: "rect"
                            radius_: gpuCard.radius
                            level: Services.SysMon.gpuPercent / 100
                            waveAmp: 4.5
                            periodMs: 5200
                            running: root.shown
                            color_: gpuCard.liquidCol
                            layer.enabled: true
                        }

                        Item {
                            id: gpuFace
                            anchors.fill: parent

                            Text {
                                id: gpuNum
                                x: gpuCard.inset
                                y: gpuCard.headH - 4
                                text: Math.round(Services.SysMon.gpuPercent) + "%"
                                color: Services.Colors.snow
                                font.pixelSize: Services.Sizes.fsReadout
                                font.bold: true
                                font.family: "JetBrainsMono NF"
                            }
                            Text {
                                anchors.left: gpuNum.right
                                anchors.leftMargin: 10
                                anchors.baseline: gpuNum.baseline
                                text: Services.SysMon.dgpuAwake ? "Discrete" : "Integrated"
                                color: Services.Colors.mist
                                font.pixelSize: Services.Sizes.fsMeta
                                font.family: "JetBrainsMono NF"
                            }
                            Text {
                                x: gpuCard.inset
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: 12
                                text: Services.SysMon.igpuFreq > 0
                                    ? "CLOCK  " + Math.round(Services.SysMon.igpuFreq) + " MHz"
                                    : ""
                                color: Services.Colors.ash
                                font.pixelSize: Services.Sizes.fsCaption
                                font.letterSpacing: 1.2
                                font.family: "JetBrainsMono NF"
                            }
                        }

                        // The words the liquid has reached, re-inked.
                        Widgets.Submerged {
                            anchors.fill: parent
                            source: gpuFace
                            mask: gpuLiquid
                            ink: gpuCard.wetInk
                        }
                    }

                    // ── Network: what is moving right now ──
                    Card {
                        index: 4
                        col: 3; row: 2; cw: 2; ch: 1
                        glyph: ""
                        name: "NETWORK"
                        id: netCard

                        Text {
                            id: netNum
                            x: netCard.inset
                            y: netCard.headH - 4
                            text: {
                                const kb = Services.SysMon.netRxKBs + Services.SysMon.netTxKBs
                                return kb >= 1024 ? (kb / 1024).toFixed(1) + " MB/s"
                                                  : Math.round(kb) + " KB/s"
                            }
                            color: Services.Colors.snow
                            font.pixelSize: Services.Sizes.fsReadout
                            font.bold: true
                            font.family: "JetBrainsMono NF"
                        }
                        Text {
                            x: netCard.inset
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 12
                            text: "↓ " + Math.round(Services.SysMon.netRxKBs)
                                  + "    ↑ " + Math.round(Services.SysMon.netTxKBs) + " KB/s"
                            color: Services.Colors.ash
                            font.pixelSize: Services.Sizes.fsCaption
                            font.family: "JetBrainsMono NF"
                        }
                    }

                    // ── Storage: the other proportion ──
                    Card {
                        index: 5
                        col: 5; row: 2; cw: 3; ch: 1
                        glyph: ""
                        name: "STORAGE"
                        note: Services.SysMon.diskPercent + "%"
                        id: diskCard

                        Meter {
                            x: diskCard.inset
                            width: parent.width - diskCard.inset * 2
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.verticalCenterOffset: 8
                            level: Services.SysMon.diskPercent / 100
                            // A drive filling up is the one thing on this board
                            // that is actually going wrong.
                            tone: Services.SysMon.diskPercent >= 90
                                ? Services.Colors.error_ : Services.Colors.ghost
                            leftNote: Math.round(Services.SysMon.diskUsedGB) + " GB used"
                            rightNote: Math.round(Services.SysMon.diskTotalGB) + " GB"
                        }
                    }
                }
            }
        }
    }
}
