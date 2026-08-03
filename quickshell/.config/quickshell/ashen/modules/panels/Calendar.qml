import Quickshell
import QtQuick
import "root:/services" as Services
import "root:/modules/widgets" as Widgets

// The clock pill's panel, built the same way the media one is: the pill does
// not open a card next to itself, it BECOMES the card. See MediaPanel for the
// long version of why each driver exists — this file is that pattern applied
// to Widgets.ClockCard, whose shared pieces are the time, the date, the
// weather glyph and the temperature.
PanelWindow {
    id: root
    anchors { top: true; left: true; right: true; bottom: true }
    screen: Services.Screens.active
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    readonly property bool shown: Services.AppState.calendarVisible
    visible: shown || closeDelay.running

    // A layer surface is not presented on the frame it is asked for, so hold
    // the pill until the surface has actually landed, then run.
    onShownChanged: {
        if (shown) {
            arm.restart()
        } else {
            arm.stop()
            Services.AppState.clockMorphing = false
            openAnim.stop()
            closeAnim.start()
            closeDelay.restart()
        }
    }
    Timer {
        id: arm
        interval: 200
        onTriggered: {
            Services.AppState.clockMorphing = true
            closeAnim.stop()
            // The style may have changed since it last closed.
            card.restDrivers()
            openAnim.start()
        }
    }
    Timer { id: closeDelay; interval: 560 }

    readonly property bool opening: Services.AppState.clockMorphing

    // Card size comes from the shared item, so widening a column there widens
    // the panel here and the two can never disagree.
    readonly property real openW: panelRef.contentW + panelRef.pad * 2
    readonly property real openH: panelRef.contentH + panelRef.pad * 2
    readonly property real pillW: Math.max(1, Services.AppState.clockPillW)
    readonly property real pillH: Math.max(1, Services.AppState.clockPillH)
    readonly property real pillCX: Services.AppState.clockPillCenterX
    readonly property real pillCY: Services.AppState.clockPillCenterY

    MouseArea {
        anchors.fill: parent
        z: -1
        onClicked: Services.AppState.calendarVisible = false
    }

    FocusScope {
        anchors.fill: parent
        focus: root.shown
        Keys.onEscapePressed: Services.AppState.calendarVisible = false
    }

    // The goo bridge tying the drop to the bar until it pinches off
    Widgets.GooNeck {
        active: !Services.Sizes.barVertical
        pillCX: root.pillCX
        pillW: root.pillW
        fromBelow: Services.Sizes.barPosition === "bottom"
        barEdge: Services.Sizes.barPosition === "bottom"
            ? parent.height - Services.Sizes.barH : Services.Sizes.barH
        cardEdge: Services.Sizes.barPosition === "bottom"
            ? card.y + card.height : card.y
        cardHalfW: card.width / 2
        pinch: Math.max(0, Math.min(1, card.fall / 0.55))
        fillColor: Services.Colors.surfacePanel
    }

    Rectangle {
        id: card

        readonly property real openX: Services.Sizes.panelX(parent.width, root.openW, root.pillCX)
        readonly property real openY: Services.Sizes.panelY(parent.height, root.openH, root.pillCY)

        visible: root.opening || closeDelay.running

        function lerp(a, b, t) { return a + (b - a) * t }
        function mix(c1, c2, t) {
            return Qt.rgba(c1.r + (c2.r - c1.r) * t,
                           c1.g + (c2.g - c1.g) * t,
                           c1.b + (c2.b - c1.b) * t,
                           c1.a + (c2.a - c1.a) * t)
        }

        // "Window" style: the drivers land on 1 at once and only the opacity
        // moves, so the card appears where it would have dropped without
        // becoming the pill first. The morph timings below are untouched.
        readonly property bool plain: Services.Prefs.panelStyle === "plain"
        property real plainFade: 0


        // Where the drivers rest while it is closed. In "window" they stay
        // landed -- the card never becomes the pill -- but in "transform" they
        // have to be back at zero or the drop has nowhere to fall from. The
        // style can change between one opening and the next, so this is
        // applied on the way in rather than assumed.
        function restDrivers() {
            const v = card.plain ? 1 : 0
            card.fall = v; card.stretch = v; card.spread = v; card.morph = v
            card.contentAmt = card.plain ? 1 : 0
            card.plainFade = 0
        }
        onPlainChanged: if (!root.shown) card.restDrivers()

        property real fall: 0
        property real stretch: 0
        property real spread: 0
        property real morph: 0
        property real contentAmt: 0

        ParallelAnimation {
            id: openAnim
            NumberAnimation {
                target: card; property: "plainFade"; to: 1
                duration: card.plain ? 260 : 0; easing.type: Services.Sizes.easeOut
            }
            NumberAnimation {
                target: card; property: "fall"; to: 1
                duration: card.plain ? 0 : 460; easing.type: Services.Sizes.easeOut
            }
            NumberAnimation {
                target: card; property: "stretch"; to: 1
                duration: card.plain ? 0 : 360; easing.type: Services.Sizes.easeOut
            }
            NumberAnimation {
                target: card; property: "spread"; to: 1
                duration: card.plain ? 0 : 560; easing.type: Easing.OutBack; easing.overshoot: Services.Sizes.overshoot
            }
            // Box first, contents after
            SequentialAnimation {
                PauseAnimation { duration: card.plain ? 0 : 200 }
                NumberAnimation {
                    target: card; property: "morph"; to: 1
                    duration: card.plain ? 0 : 340; easing.type: Services.Sizes.easeOut
                }
            }
            SequentialAnimation {
                PauseAnimation { duration: card.plain ? 0 : 380 }
                NumberAnimation { target: card; property: "contentAmt"; to: 1; duration: card.plain ? 0 : 200 }
            }
        }

        ParallelAnimation {
            id: closeAnim
            NumberAnimation {
                target: card; property: "plainFade"; to: 0
                duration: card.plain ? 200 : 0; easing.type: Services.Sizes.easeIn
            }
            NumberAnimation { target: card; property: "contentAmt"; to: 0; duration: card.plain ? 0 : 90 }
            SequentialAnimation {
                PauseAnimation { duration: card.plain ? 0 : 40 }
                NumberAnimation {
                    target: card; property: "morph"; to: card.plain ? 1 : 0
                    duration: card.plain ? 0 : 260; easing.type: Services.Sizes.easeInOut
                }
            }
            SequentialAnimation {
                PauseAnimation { duration: card.plain ? 0 : 160 }
                ParallelAnimation {
                    NumberAnimation {
                        target: card; property: "fall"; to: card.plain ? 1 : 0
                        duration: card.plain ? 0 : 340; easing.type: Services.Sizes.easeInOut
                    }
                    NumberAnimation {
                        target: card; property: "stretch"; to: card.plain ? 1 : 0
                        duration: card.plain ? 0 : 300; easing.type: Services.Sizes.easeInOut
                    }
                    NumberAnimation {
                        target: card; property: "spread"; to: card.plain ? 1 : 0
                        duration: card.plain ? 0 : 300; easing.type: Services.Sizes.easeInOut
                    }
                }
            }
        }

        width: root.pillW + (root.openW - root.pillW) * spread
        height: (root.pillH + (root.openH - root.pillH) * stretch)
                * (card.plain ? 0.06 + 0.94 * card.plainFade : 1)
        x: root.pillCX + (openX + root.openW / 2 - root.pillCX) * fall - width / 2
        y: card.plain ? openY
           : root.pillCY + (openY + root.openH / 2 - root.pillCY) * fall - height / 2

        opacity: card.plain ? card.plainFade : 1
        radius: Services.Sizes.pillR + (20 - Services.Sizes.pillR) * Math.min(1, spread)
        color: Services.Colors.surfacePanel
        clip: true

        MouseArea { anchors.fill: parent; onClicked: {} }

        // ── Reference layout A: the pill ────────────────────────────────
        // A structural copy of Clock.qml's row, laid out but never drawn, so
        // the flying pieces start exactly where the real pill has them.
        // Centred because the pill is its row plus 20 px either side.
        Row {
            id: pillRef
            opacity: 0
            anchors.centerIn: parent
            spacing: 16

            Column {
                id: refStack
                spacing: 1
                Text {
                    id: refTime
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: panelRef.timeText
                    font.pixelSize: 15
                    font.bold: true
                    font.family: "JetBrainsMono NF"
                }
                Text {
                    id: refDate
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Qt.formatDateTime(panelRef.now, "ddd, MMM d")
                    font.pixelSize: 10
                    font.bold: true
                    font.family: "JetBrainsMono NF"
                }
            }

            Row {
                id: refWx
                spacing: 4
                anchors.verticalCenter: parent.verticalCenter
                Text {
                    id: refIcon
                    anchors.verticalCenter: parent.verticalCenter
                    text: Services.Weather.icon
                    font.pixelSize: 22
                    font.family: "Material Symbols Rounded"
                }
                Text {
                    id: refTemp
                    anchors.verticalCenter: parent.verticalCenter
                    text: Services.Weather.temp
                    font.pixelSize: 13
                    font.bold: true
                    font.family: "JetBrainsMono NF"
                }
            }
        }

        // ── Reference layout B: the card ────────────────────────────────
        Widgets.ClockCard {
            id: panelRef
            anchors.centerIn: parent
            ghostShared: true
            extrasOpacity: card.contentAmt
        }

        // ── The shared pieces ───────────────────────────────────────────
        // Each is drawn once, at its final size, and scaled down to the pill's
        // size — stepping font.pixelSize instead would reflow the glyphs in
        // integer jumps and read as a stutter. Positioned by centre so the
        // scaling never drags the item sideways.

        Text {
            id: flyTime
            readonly property real s: card.lerp(15 / panelRef.clockPx, 1, card.morph)
            text: panelRef.timeText
            color: Services.Colors.snow
            font.pixelSize: panelRef.clockPx
            font.bold: true
            font.family: "JetBrainsMono NF"
            x: card.lerp(pillRef.x + refStack.x + refTime.x + refTime.width / 2,
                         panelRef.x + panelRef.timeCX, card.morph) - width / 2
            y: card.lerp(pillRef.y + refStack.y + refTime.y + refTime.height / 2,
                         panelRef.y + panelRef.timeCY, card.morph) - height / 2
            transform: Scale {
                origin.x: flyTime.width / 2
                origin.y: flyTime.height / 2
                xScale: flyTime.s
                yScale: flyTime.s
            }
        }

        // Only 10 -> 13 px: three integer steps, small enough to grow the font
        // directly without the scaling dance.
        Text {
            id: flyDate
            text: card.morph < 0.5
                ? Qt.formatDateTime(panelRef.now, "ddd, MMM d")
                : panelRef.dateText
            color: Services.Colors.mist
            font.pixelSize: card.lerp(10, 13, card.morph)
            font.bold: true
            font.family: "JetBrainsMono NF"
            x: card.lerp(pillRef.x + refStack.x + refDate.x + refDate.width / 2,
                         panelRef.x + panelRef.dateCX, card.morph) - width / 2
            y: card.lerp(pillRef.y + refStack.y + refDate.y + refDate.height / 2,
                         panelRef.y + panelRef.dateCY, card.morph) - height / 2
        }

        Text {
            id: flyIcon
            readonly property real s: card.lerp(22 / 48, 1, card.morph)
            text: Services.Weather.icon
            color: Services.Colors.neutral
            font.pixelSize: 48
            font.family: "Material Symbols Rounded"
            x: card.lerp(pillRef.x + refWx.x + refIcon.x + refIcon.width / 2,
                         panelRef.x + panelRef.wIconCX, card.morph) - width / 2
            y: card.lerp(pillRef.y + refWx.y + refIcon.y + refIcon.height / 2,
                         panelRef.y + panelRef.wIconCY, card.morph) - height / 2
            transform: Scale {
                origin.x: flyIcon.width / 2
                origin.y: flyIcon.height / 2
                xScale: flyIcon.s
                yScale: flyIcon.s
            }
        }

        Text {
            id: flyTemp
            readonly property real s: card.lerp(13 / 30, 1, card.morph)
            text: Services.Weather.temp
            // Dim in the bar, bright in the card: it is the headline number
            // there and only a footnote here.
            color: card.mix(Services.Colors.mist, Services.Colors.snow, card.morph)
            font.pixelSize: 30
            font.bold: true
            font.family: "JetBrainsMono NF"
            x: card.lerp(pillRef.x + refWx.x + refTemp.x + refTemp.width / 2,
                         panelRef.x + panelRef.wTempCX, card.morph) - width / 2
            y: card.lerp(pillRef.y + refWx.y + refTemp.y + refTemp.height / 2,
                         panelRef.y + panelRef.wTempCY, card.morph) - height / 2
            transform: Scale {
                origin.x: flyTemp.width / 2
                origin.y: flyTemp.height / 2
                xScale: flyTemp.s
                yScale: flyTemp.s
            }
        }
    }
}
