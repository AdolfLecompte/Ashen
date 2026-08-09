import Quickshell
import QtQuick
import "root:/services" as Services
import "root:/modules/widgets" as Widgets

// The clock pill's panel: the pill does not open a card next to itself, it
// BECOMES the card. The blob and its drivers live in Widgets.MorphCard;
// this file is that engine applied to Widgets.ClockCard.
PanelWindow {
    id: root
    anchors { top: true; left: true; right: true; bottom: true }
    screen: Services.Screens.active
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    readonly property bool shown: Services.AppState.calendarVisible
    visible: shown || card.closing

    // The pill stands aside while its panel is wearing its face.
    Binding {
        target: Services.AppState
        property: "clockMorphing"
        // Not `morphing`: in "window" style the card never wears the pill's
        // face, and the pill must stay where it is.
        value: card.wearingFace
    }

    // Card size comes from the shared item, so widening a column there widens
    // the panel here and the two can never disagree.
    readonly property real openW: panelRef.contentW + panelRef.pad * 2
    readonly property real openH: panelRef.contentH + panelRef.pad * 2

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

    Widgets.MorphCard {
        id: card
        anchors.fill: parent

        shown: root.shown
        pillW: Math.max(1, Services.AppState.clockPillW)
        pillH: Math.max(1, Services.AppState.clockPillH)
        pillCX: Services.AppState.clockPillCenterX
        pillCY: Services.AppState.clockPillCenterY
        openW: root.openW
        openH: root.openH

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
        // Each is drawn once at its final size and scaled down to the pill's --
        // stepping font.pixelSize would reflow the glyphs in integer jumps.
        // Positioned by centre, so the scaling never drags the item sideways.

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
