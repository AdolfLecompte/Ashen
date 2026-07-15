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
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.rightMargin: 16
        spacing: 12
        opacity: Services.AppState.powerMenuVisible ? 1.0 : 0.0
        visible: Services.AppState.powerMenuVisible || opacity > 0
        Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

        transform: Translate {
            x: Services.AppState.powerMenuVisible ? 0 : 24
            Behavior on x { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
        }

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
                color: Services.Colors.surfaceAlpha(0.95)
                border.color: Services.Colors.ghostAlpha(0.2)
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
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onEntered: parent.color = Services.Colors.ghostAlpha(0.2)
                    onExited: parent.color = Services.Colors.surfaceAlpha(0.95)
                    onClicked: {
                        Services.AppState.powerMenuVisible = false
                        Quickshell.execDetached(["sh", "-c", modelData.cmd])
                    }
                }
            }
        }
    }
}
