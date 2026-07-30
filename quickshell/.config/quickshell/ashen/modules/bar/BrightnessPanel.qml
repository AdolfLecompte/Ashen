import Quickshell
import Quickshell.Io
import QtQuick
import "root:/services" as Services
import "root:/modules/widgets" as Widgets

PanelWindow {
    id: win
    anchors { top: true; left: true; right: true; bottom: true }
    screen: Services.Screens.active
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    // stays mapped through the close animation, so the exit plays in reverse
    readonly property bool shown: Services.AppState.brightnessVisible
    visible: shown || closeDelay.running
    onShownChanged: if (!shown) closeDelay.restart()
    // Mapped until the drop is all the way home; see DropCard.closeMs.
    Timer { id: closeDelay; interval: card.closeMs }

    function setBrightness(ratio) {
        ratio = Math.max(0.02, Math.min(1, ratio))
        let pct = Math.round(ratio * 100)
        Quickshell.execDetached(["sh", "-c", "brightnessctl set " + pct + "%"])
    }

    MouseArea {
        anchors.fill: parent
        z: -1
        onClicked: Services.AppState.brightnessVisible = false
    }

    // Falls out of its chip like a drop, the same opening as the clock.
    Widgets.DropCard {
        id: card
        shown: Services.AppState.brightnessVisible
        pillCX: Services.AppState.brightnessPillCenterX
        pillCY: Services.AppState.brightnessPillCenterY
        pillActive: Services.Brightness.level > 0
        pillGlyph: Services.AppState.pillGlyph("brightness")
        pillLabel: Services.AppState.pillLabel("brightness")
        glyphTarget: hdrGlyph
        labelTarget: hdrValue
        pillW: Services.AppState.brightnessPillW
        pillH: Services.AppState.brightnessPillH
        openW: 300
        openH: 78
        cardRadius: 16

        Column {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 12

            // Header: icon + label + value
            Item {
                width: parent.width
                height: 22

                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8

                    Text {
                        id: hdrGlyph
                        opacity: card.morphingGlyph ? 0 : 1
                        anchors.verticalCenter: parent.verticalCenter
                        text: ""
                        font.family: "Material Symbols Rounded"
                        font.pixelSize: 18
                        color: Services.Colors.ghost
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Brightness"
                        color: Services.Colors.mist
                        font.pixelSize: 12
                        font.family: "JetBrainsMono NF"
                    }
                }

                Text {
                    id: hdrValue
                    opacity: card.morphingLabel ? 0 : 1
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    // Off the chip, not off the slider's smoothed value: while
                    // the bar was easing towards the level the two readings
                    // disagreed by a percent or two and the piece would not fly.
                    text: Services.AppState.pillLabel("brightness")
                    color: Services.Colors.snow
                    font.pixelSize: 14
                    font.bold: true
                    font.family: "JetBrainsMono NF"
                }
            }

            // Slider
            Widgets.SliderTrack {
                id: brightBar
                width: parent.width
                knobSize: 18
                knobBorder: 1
                knobBorderColor: Services.Colors.ghostAlpha(0.45)
                hitMargin: 14
                value: Services.Brightness.level / 100
                onMoved: r => win.setBrightness(r)
            }
        }
    }
}
