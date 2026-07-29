import Quickshell
import Quickshell.Io
import QtQuick
import "root:/services" as Services

PanelWindow {
    id: root

    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }
    screen: Services.Screens.active

    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    // stays mapped through the close animation, so the exit plays in reverse
    readonly property bool shown: Services.AppState.powerMenuVisible
    visible: shown || closeDelay.running
    onShownChanged: if (!shown) closeDelay.restart()
    Timer { id: closeDelay; interval: 300 }

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.55)
        opacity: Services.AppState.powerMenuVisible ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 250 } }
        MouseArea {
            anchors.fill: parent
            onClicked: Services.AppState.powerMenuVisible = false
        }
    }

    Column {
        // Follows the power pill: end of the bar, whichever edge that is
        anchors.verticalCenter: parent.verticalCenter
        x: Services.Sizes.barPosition === "left"
           ? Math.max(16, Services.Sizes.marginLeft)
           : parent.width - width - Math.max(16, Services.Sizes.marginRight)
        spacing: 12
        id: powerCol
        opacity: Services.AppState.powerMenuVisible ? 1.0 : 0.0
        visible: Services.AppState.powerMenuVisible || opacity > 0
        // Origin-anchored open: grows out of the right edge (power pill) + fades.
        property real openAmt: Services.AppState.powerMenuVisible ? 1.0 : 0.0
        Behavior on openAmt { NumberAnimation { duration: 300; easing.type: Easing.OutQuint } }
        Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
        transformOrigin: Item.Right
        scale: 0.7 + 0.3 * powerCol.openAmt

        Repeater {
            model: [
                { icon: "",    cmd: "qs ipc -c ashen call lockscreen lock", accent: false },
                { icon: "",   cmd: "systemctl poweroff",                   accent: true  },
                { icon: "", cmd: "systemctl suspend",                    accent: false },
                { icon: "", cmd: "systemctl reboot",                     accent: false },
            ]
            delegate: Rectangle {
                required property var modelData
                width: 90; height: 90
                radius: 14
                // Declarative hover (no imperative parent.color assignment, which
                // clobbers the binding and makes the highlight stick/flicker).
                // Both states stay opaque: crossfading to a translucent ghost tint
                // let the dark overlay show through mid-animation, reading as a jump.
                color: hover.containsMouse ? Services.Colors.elevated : Services.Colors.surfaceAlpha(0.95)
                border.width: 0
                Behavior on color { ColorAnimation { duration: 150 } }

                Text {
                    anchors.centerIn: parent
                    text: modelData.icon
                    color: modelData.accent ? Services.Colors.error_ : Services.Colors.ghost
                    font.pixelSize: 44
                    font.family: "Material Symbols Rounded"
                }

                MouseArea {
                    id: hover
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onClicked: {
                        Services.AppState.powerMenuVisible = false
                        Quickshell.execDetached(["sh", "-c", modelData.cmd])
                    }
                }
            }
        }
    }
}
