import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import "root:/services" as Services

PanelWindow {
    id: root
    anchors { top: true; left: true; right: true; bottom: true }
    screen: Services.Screens.active
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    // stays mapped through the close animation, so the exit plays in reverse
    readonly property bool shown: Services.AppState.usbVisible
    visible: shown || closeDelay.running
    onShownChanged: if (!shown) closeDelay.restart()
    Timer { id: closeDelay; interval: 300 }

    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    MouseArea {
        anchors.fill: parent
        z: -1
        onClicked: Services.AppState.usbVisible = false
    }

    Rectangle {
        width: 360
        // Follows its pill along the bar, and the bar around the screen
        x: Services.Sizes.panelX(parent.width, width, Services.AppState.usbPillCenterX)
        y: Services.Sizes.panelY(parent.height, height, Services.AppState.usbPillCenterY)
        radius: 14
        height: Math.min(panelCol.implicitHeight + 28, root.height - 80)
        color: Services.Colors.surfaceAlpha(0.95)
        border.color: Services.Colors.ghostAlpha(0.2)
        border.width: 0
        clip: true

        id: card
        // Origin-anchored open: grows out of its bar pill + fades, smooth settle.
        property real openAmt: Services.AppState.usbVisible ? 1.0 : 0.0
        Behavior on openAmt { NumberAnimation { duration: 300; easing.type: Easing.OutQuint } }

        opacity: Services.AppState.usbVisible ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

        transform: Scale {
            origin.x: Services.Sizes.originX(card.x, card.width, Services.AppState.usbPillCenterX)
            origin.y: Services.Sizes.originY(card.y, card.height, Services.AppState.usbPillCenterY)
            xScale: 0.55 + 0.45 * card.openAmt
            yScale: 0.55 + 0.45 * card.openAmt
        }

        MouseArea { anchors.fill: parent; onClicked: {} }

        Column {
            id: panelCol
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 14
            spacing: 10

            RowLayout {
                width: parent.width
                Text {
                    text: "\ue1e0"
                    color: Services.Colors.ghost
                    font.pixelSize: 18
                    font.family: "Material Symbols Rounded"
                }
                Text {
                    text: "USB Devices"
                    color: Services.Colors.snow
                    font.pixelSize: 14
                    font.bold: true
                    font.family: "JetBrainsMono NF"
                    Layout.fillWidth: true
                    leftPadding: 8
                }
            }

            Text {
                visible: Services.USB.devices.length === 0
                text: "No USB devices connected"
                color: Services.Colors.ash
                font.pixelSize: 11
                font.family: "JetBrainsMono NF"
                topPadding: 20
                bottomPadding: 20
                anchors.horizontalCenter: parent.horizontalCenter
            }

            Repeater {
                model: Services.USB.devices
                delegate: Rectangle {
                    required property var modelData
                    width: panelCol.width
                    height: 66
                    radius: 10
                    color: Services.Colors.ghostAlpha(0.08)

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 10

                        Rectangle {
                            width: 36; height: 36
                            radius: 9
                            color: Services.Colors.ghostAlpha(0.15)
                            Text {
                                anchors.centerIn: parent
                                text: "\ue1e0"
                                color: Services.Colors.ghost
                                font.pixelSize: 18
                                font.family: "Material Symbols Rounded"
                            }
                        }

                        Column {
                            Layout.fillWidth: true
                            spacing: 2
                            Text {
                                text: modelData.label
                                color: Services.Colors.snow
                                font.pixelSize: 13
                                font.bold: true
                                font.family: "JetBrainsMono NF"
                                elide: Text.ElideRight
                                width: parent.width
                            }
                            Text {
                                text: modelData.size + (modelData.mountpoint ? " · " + modelData.mountpoint : " · Not mounted")
                                color: Services.Colors.mist
                                font.pixelSize: 10
                                font.family: "JetBrainsMono NF"
                                elide: Text.ElideRight
                                width: parent.width
                            }
                        }

                        Rectangle {
                            width: mountLabel.implicitWidth + 16
                            height: 28
                            radius: 8
                            color: modelData.mountpoint ? Services.Colors.ghostAlpha(0.15) : Services.Colors.ghost
                            Text {
                                id: mountLabel
                                anchors.centerIn: parent
                                text: modelData.mountpoint ? "Unmount" : "Mount"
                                color: modelData.mountpoint ? Services.Colors.snow : Services.Colors.abyss
                                font.pixelSize: 11
                                font.family: "JetBrainsMono NF"
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (modelData.mountpoint) Services.USB.unmount(modelData.path)
                                    else Services.USB.mount(modelData.path)
                                }
                            }
                        }

                        Rectangle {
                            width: 28; height: 28; radius: 8
                            color: "transparent"
                            Text {
                                anchors.centerIn: parent
                                text: "\ue8fb"
                                color: Services.Colors.ash
                                font.pixelSize: 16
                                font.family: "Material Symbols Rounded"
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                hoverEnabled: true
                                onEntered: parent.color = Services.Colors.ghostAlpha(0.15)
                                onExited: parent.color = "transparent"
                                onClicked: Services.USB.eject(modelData.parentName)
                            }
                        }
                    }
                }
            }

            Item { height: 4 }
        }
    }
}
