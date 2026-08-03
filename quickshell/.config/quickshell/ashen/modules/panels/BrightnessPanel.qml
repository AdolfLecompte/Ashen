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
    Widgets.PanelHost {
        id: card
        shown: Services.AppState.brightnessVisible
        pillCX: Services.AppState.brightnessPillCenterX
        pillCY: Services.AppState.brightnessPillCenterY
        pillActive: Services.Brightness.level > 0
        pillGlyph: Services.AppState.pillGlyph("brightness")
        pillLabel: Services.AppState.pillLabel("brightness")
        pillW: Services.AppState.brightnessPillW
        pillH: Services.AppState.brightnessPillH
        openW: 460
        // Dial + gap + slider + margins, and the slider's knob is 18 tall on a
        // 10 px track, so it needs the 4 px either side that the track does not
        // ask for -- without them the card clipped it.
        openH: 32 + 120
        cardRadius: 16

        pillKey: "brightness"
        restSide: "left"

        body: Component {
            Item {
                readonly property Item glyphTarget: dial.glyphItem
                readonly property Item labelTarget: dial.labelItem

                // The same head as sound, minus everything sound needs and
                // this does not: one screen, one level, nothing to pick.
                Item {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 16
                    height: 120
                    opacity: card.contentAmt

                    Widgets.DialGauge {
                        id: dial
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        size: 120
                        lw: 10
                        // Off the slider, not the service: Brightness polls
                        // every 1.5 s and the dial would trail the bar.
                        value: brightBar.shown
                        easeMs: brightBar.dragging ? 0 : 220
                        glyph: Services.AppState.pillGlyph("brightness")
                        label: Math.round(dial.frac * 100) + "%"
                        glyphSize: 18
                        labelSize: 22
                        captionSize: 0
                        hideGlyph: card.morphingGlyph
                        hideLabel: card.morphingLabel
                    }

                    Column {
                        anchors.left: dial.right
                        anchors.leftMargin: 16
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 8

                        Text {
                            text: "Brightness"
                            color: Services.Colors.snow
                            font.pixelSize: Services.Sizes.fsBody
                            font.bold: true
                            font.family: "JetBrainsMono NF"
                        }

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
        }
    }
}
