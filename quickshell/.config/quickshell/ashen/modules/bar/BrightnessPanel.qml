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
    Timer { id: closeDelay; interval: 300 }

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

    Rectangle {
        id: card
        width: 300
        height: 78
        // Follows its pill along the bar, and the bar around the screen
        x: Services.Sizes.panelX(parent.width, width, Services.AppState.brightnessPillCenterX)
        y: Services.Sizes.panelY(parent.height, height, Services.AppState.brightnessPillCenterY)
        radius: 16
        color: Services.Colors.surfaceAlpha(0.95)
        border.width: 0

        // Origin-anchored open: grows out of its bar pill + fades, smooth settle.
        property real openAmt: Services.AppState.brightnessVisible ? 1.0 : 0.0
        Behavior on openAmt { NumberAnimation { duration: 300; easing.type: Easing.OutQuint } }

        opacity: Services.AppState.brightnessVisible ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

        transform: Scale {
            origin.x: Services.Sizes.originX(card.x, card.width, Services.AppState.brightnessPillCenterX)
            origin.y: Services.Sizes.originY(card.y, card.height, Services.AppState.brightnessPillCenterY)
            xScale: 0.55 + 0.45 * card.openAmt
            yScale: 0.55 + 0.45 * card.openAmt
        }

        MouseArea { anchors.fill: parent; onClicked: {} }

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
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: Math.round(brightBar.shown * 100) + "%"
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
