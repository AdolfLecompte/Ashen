import Quickshell
import Quickshell.Wayland
import QtQuick

import "root:/services" as Services

// One hidden peek per screen edge the bar is NOT on: rest the pointer there and
// a row of icon-only chips glues to that edge. The tools' panels grow out of it.
Scope {
    id: root


    // A chip that hands itself over to the panel it opens: while that panel is
    // up the chip steps aside, so the card reads as the chip unfolded.
    component UtilChip: CtlChip {
        id: uc
        // Its own panel is open. Each chip watches its own, never the pill's:
        // keyed on "any panel from this edge", opening the clipboard would
        // have made the process chip vanish too.
        property bool open: false
        property bool takenOver: false
        // A chip that OPENS something steps aside while that thing is up --
        // the panel grew out of its rect and has to read as the chip
        // unfolded. A chip that merely toggles a mode has nothing to hand
        // over to, and disappearing when switched on just looks broken.
        property bool handsOver: true
        // Reported continuously under this name, so a panel opened by keybind
        // knows where to grow from without anyone having clicked first.
        property string chipId: ""
        // Capsules, fully round on the ends: the two circles at either end are
        // the drawer and the pin, and the shape is what tells them apart.
        radius: Math.min(width, height) / 2
        active: uc.open
        // Opacity, not visible: hidden would drop it from the Grid and shove
        // its neighbours sideways mid-animation.
        opacity: (takenOver && Services.Prefs.panelStyle === "morph") ? 0.0 : 1.0
        Behavior on opacity { NumberAnimation { duration: Services.Sizes.msMicro } }

        onOpenChanged: {
            if (!handsOver) return
            if (open) { handBack.stop(); handOver.restart() }
            else { handOver.stop(); handBack.restart() }
        }
        // The panel waits for its window to actually be on screen before it
        // starts to grow, so the chip waits the same beat before standing
        // down -- otherwise the pill goes blank and only THEN does the card
        // appear.
        Timer {
            id: handOver
            interval: Services.Sizes.panelArmMs
            onTriggered: uc.takenOver = true
        }
        // Coming back it is free a little before the card is all the way in,
        // so the two meet rather than the chip waiting on an empty pill.
        Timer {
            id: handBack
            interval: Services.Sizes.panelCloseMs - 40
            onTriggered: uc.takenOver = false
        }

        // mapToItem has no change signal, so every event that can move the
        // chip has to say so; the timer is a backstop, not the source.
        function report() {
            if (uc.chipId === "" || !uc.parent) return
            const t = uc.trigRef
            if (!t) return
            Services.AppState.setUtilChip(t.edge, uc.chipId,
                t.chipCX(uc), t.chipCY(uc), uc.width, uc.height)
        }
        property var trigRef: null
        onXChanged: report()
        onYChanged: report()
        onWidthChanged: report()
        onHeightChanged: report()
        Component.onCompleted: report()
        Timer { interval: 2000; running: true; repeat: true; onTriggered: uc.report() }
    }

    // Reactive: re-filters whenever the bar moves to another edge.
    readonly property var edges: {
        Services.Sizes.barPosition
        return ["top", "bottom", "left", "right"].filter(e => e !== Services.Sizes.barPosition)
    }

    Variants {
        model: root.edges

        PanelWindow {
            id: trig
            property string modelData
            readonly property string edge: modelData
            readonly property bool vertical: edge === "left" || edge === "right"

            screen: Services.Screens.active
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            anchors {
                top: edge !== "bottom"
                bottom: edge !== "top"
                left: edge !== "right"
                right: edge !== "left"
            }
            implicitWidth: vertical ? 62 : 0
            implicitHeight: vertical ? 0 : 62

            property bool revealed: false
            onRevealedChanged: if (!revealed) hideTimer.stop()

            // A panel opened from THIS edge's pill. While one is up the pill
            // stays out: it is what the panel grew from and climbs back into.
            readonly property bool panelOpen:
                (Services.AppState.processVisible
                 && Services.AppState.processSourceEdge === trig.edge)
                || (Services.AppState.clipboardVisible
                    && Services.AppState.clipboardSourceEdge === trig.edge)
                || (Services.AppState.utilitiesVisible
                    && Services.AppState.utilitiesSourceEdge === trig.edge)
                || (Services.AppState.settingsVisible
                    && Services.AppState.settingsSourceEdge === trig.edge)

            onPanelOpenChanged: {
                if (panelOpen) { hideTimer.stop(); trig.revealed = true }
                else hideTimer.restart()
            }

            // Where a chip sits ON SCREEN. mapToGlobal returns window-local
            // coordinates on a layer surface, so the window's own origin has to
            // be added; and the pill's SETTLED position is reported, never where
            // it happens to be mid-reveal.
            readonly property real slideFix: {
                if (!pill) return 0
                if (trig.edge === "bottom") return trig.height - (pill.y + pill.height)
                if (trig.edge === "top") return -pill.y
                if (trig.edge === "left") return -pill.x
                return trig.width - (pill.x + pill.width)
            }

            function chipCX(item) {
                const p = item.mapToItem(null, 0, 0)
                const x0 = trig.edge === "right" ? trig.screen.width - trig.width : 0
                const fix = trig.vertical ? trig.slideFix : 0
                return x0 + p.x + item.width / 2 + fix
            }
            function chipCY(item) {
                const p = item.mapToItem(null, 0, 0)
                const y0 = trig.edge === "bottom" ? trig.screen.height - trig.height : 0
                const fix = trig.vertical ? 0 : trig.slideFix
                return y0 + p.y + item.height / 2 + fix
            }

            mask: Region {
                item: strip
                Region { item: pill }
            }

            Timer {
                id: peekTimer
                interval: 1000
                onTriggered: { trig.revealed = true; hideTimer.restart() }
            }
            readonly property bool pinned: Services.AppState.utilityPinnedEdge === trig.edge

            Timer {
                id: hideTimer
                interval: 1600
                onTriggered: if (!trig.panelOpen && !trig.pinned) trig.revealed = false
            }

            onPinnedChanged: {
                if (pinned) { hideTimer.stop(); trig.revealed = true }
                else hideTimer.restart()
            }

            // The sliver that arms the reveal.
            Item {
                id: strip
                anchors {
                    top: trig.edge === "top" ? parent.top : undefined
                    bottom: trig.edge === "bottom" ? parent.bottom : undefined
                    left: trig.edge === "left" ? parent.left : undefined
                    right: trig.edge === "right" ? parent.right : undefined
                    horizontalCenter: trig.vertical ? undefined : parent.horizontalCenter
                    verticalCenter: trig.vertical ? parent.verticalCenter : undefined
                }
                // Exactly as long as the pill it arms: a sliver that reached
                // past the capsule would arm the reveal from air where nothing
                // is ever going to appear.
                readonly property int len: pill.reserveLen
                width: trig.vertical ? 8 : len
                height: trig.vertical ? len : 8

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.NoButton
                    onEntered: { hideTimer.stop(); if (!trig.revealed) peekTimer.restart() }
                    onExited: { peekTimer.stop(); if (trig.revealed) hideTimer.restart() }
                }
            }

            // The glued capsule, icon chips only -- no labels, so it reads the
            // same off any of the three edges it can land on.
            Rectangle {
                id: pill
                anchors {
                    top: trig.edge === "top" ? parent.top : undefined
                    bottom: trig.edge === "bottom" ? parent.bottom : undefined
                    left: trig.edge === "left" ? parent.left : undefined
                    right: trig.edge === "right" ? parent.right : undefined
                    horizontalCenter: trig.vertical ? undefined : parent.horizontalCenter
                    verticalCenter: trig.vertical ? parent.verticalCenter : undefined
                    topMargin: trig.edge === "top" ? (trig.revealed ? 0 : -48) : undefined
                    bottomMargin: trig.edge === "bottom" ? (trig.revealed ? 0 : -48) : undefined
                    leftMargin: trig.edge === "left" ? (trig.revealed ? 0 : -48) : undefined
                    rightMargin: trig.edge === "right" ? (trig.revealed ? 0 : -48) : undefined
                }
                // Fixed, generous length -- a dock, not a cramped strip. The
                // chip spacing below spreads whatever lives in it across the
                // whole thing rather than leaving it clumped in the middle.
                readonly property int reserveLen: Services.Sizes.utilPillLen
                readonly property int thick: Services.Sizes.utilPillThick
                width: trig.vertical ? thick : reserveLen
                height: trig.vertical ? reserveLen : thick
                // Corners touching the screen edge stay square: there is
                // nothing behind a curve there, only a gap.
                radius: Services.Sizes.pillR
                readonly property real outR: radius * 1.6
                topLeftRadius: trig.edge === "top" || trig.edge === "left" ? 0 : outR
                topRightRadius: trig.edge === "top" || trig.edge === "right" ? 0 : outR
                bottomLeftRadius: trig.edge === "bottom" || trig.edge === "left" ? 0 : outR
                bottomRightRadius: trig.edge === "bottom" || trig.edge === "right" ? 0 : outR
                color: Services.Colors.surfacePill
                border.color: Services.Colors.ghostAlpha(0.2)
                border.width: 0

                Behavior on anchors.topMargin { NumberAnimation { duration: Services.Sizes.msStandard; easing.type: Services.Sizes.easeOut } }
                Behavior on anchors.bottomMargin { NumberAnimation { duration: Services.Sizes.msStandard; easing.type: Services.Sizes.easeOut } }
                Behavior on anchors.leftMargin { NumberAnimation { duration: Services.Sizes.msStandard; easing.type: Services.Sizes.easeOut } }
                Behavior on anchors.rightMargin { NumberAnimation { duration: Services.Sizes.msStandard; easing.type: Services.Sizes.easeOut } }

                // Declared before the chips so it sits UNDER them: NoButton
                // waives clicks, not hover tracking.
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.NoButton
                    onEntered: hideTimer.stop()
                    onExited: if (trig.revealed) hideTimer.restart()
                }

                Grid {
                    id: chips
                    anchors.centerIn: parent
                    // The two circles keep their diameter; the tools share
                    // what is left, so the pill is always filled.
                    readonly property int tools: Services.Pills.tools.length
                    readonly property int count: tools + 2
                    readonly property int toolCount: Math.max(1, tools)
                    // Derived from the pill's own thickness, not Sizes.innerH:
                    // the chips have to shrink with it or they burst the
                    // capsule they sit in.
                    readonly property int circleSize: pill.thick - 10
                    readonly property int chipGap: Services.Sizes.btnGap
                    readonly property int chipLen:
                        (pill.reserveLen - 16 - (toolCount + 1) * chipGap - 2 * circleSize) / toolCount
                    columns: trig.vertical ? 1 : count
                    spacing: chipGap

                    // Keeps the pill out instead of letting it retract. A ring,
                    // which is what the pill is doing: holding a shape open.
                    // It was a bare filled circle, indistinguishable from the
                    // drawer at the other end until you had clicked one.
                    UtilChip {
                        id: pinChip
                        glyph: "\ue836"
                        handsOver: false
                        size: chips.circleSize
                        width: chips.circleSize
                        height: chips.circleSize
                        open: trig.pinned
                        onTriggered: Services.AppState.utilityPinnedEdge =
                            trig.pinned ? "" : trig.edge
                    }

                    // The tools, fixed and in this order. They are not bar
                    // pills and nothing moves in or out of here.
                    Repeater {
                        model: Services.Pills.tools

                        delegate: UtilChip {
                            id: toolChip
                            required property var modelData
                            readonly property string flag: Services.Pills.opens(modelData)
                            chipId: modelData
                            trigRef: trig
                            glyph: Services.Pills.glyph(modelData)
                            size: chips.circleSize
                            width: trig.vertical ? chips.circleSize : chips.chipLen
                            height: trig.vertical ? chips.chipLen : chips.circleSize
                            // Its own panel, on THIS edge: three copies of the
                            // pill exist and only the one clicked is the one
                            // the panel should hang off.
                            open: Services.AppState.overlayOpen(toolChip.flag)
                                  && Services.AppState.chipEdgeOf(modelData) === trig.edge
                            // A readout has nothing to open, so it does not
                            // stand down for anything.
                            handsOver: toolChip.flag !== ""
                            onTriggered: {
                                if (toolChip.flag === "") return
                                Services.AppState.setChipRect(modelData,
                                    trig.chipCX(toolChip), trig.chipCY(toolChip),
                                    toolChip.width, toolChip.height, trig.edge)
                                Services.AppState.toggleOverlay(toolChip.flag)
                            }
                        }
                    }

                    // The drawer: everything the launcher used to hide behind
                    // ">". A circle, and the only one on the pill.
                    UtilChip {
                        id: drawerChip
                        glyph: "\ue5cc"
                        size: chips.circleSize
                        width: chips.circleSize
                        height: chips.circleSize
                        open: Services.AppState.utilitiesVisible
                              && Services.AppState.utilitiesSourceEdge === trig.edge
                        onTriggered: {
                            Services.AppState.utilitiesPillCX = trig.chipCX(drawerChip)
                            Services.AppState.utilitiesPillCY = trig.chipCY(drawerChip)
                            Services.AppState.utilitiesPillW = drawerChip.width
                            Services.AppState.utilitiesPillH = drawerChip.height
                            Services.AppState.utilitiesSourceEdge = trig.edge
                            Services.AppState.utilitiesVisible = !Services.AppState.utilitiesVisible
                        }
                    }
                }
            }
        }
    }
}
