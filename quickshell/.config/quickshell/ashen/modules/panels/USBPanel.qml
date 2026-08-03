import Quickshell
import Quickshell.Wayland
import Quickshell.Io
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
    // stays mapped through the close animation, so the exit plays in reverse
    readonly property bool shown: Services.AppState.usbVisible
    visible: shown || closeDelay.running
    onShownChanged: if (!shown) closeDelay.restart()
    // Mapped until the drop is all the way home; see DropCard.closeMs.
    Timer { id: closeDelay; interval: card.closeMs }

    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    MouseArea {
        anchors.fill: parent
        z: -1
        onClicked: Services.AppState.usbVisible = false
    }

    // Falls out of the USB pill like a drop, same as the rest of the bar.
    Widgets.PanelHost {
        id: card
        shown: Services.AppState.usbVisible
        pillCX: Services.AppState.usbPillCenterX
        pillCY: Services.AppState.usbPillCenterY
        pillW: Services.AppState.usbPillW
        pillH: Services.AppState.usbPillH
        pillActive: false
        // Standalone bar pill, not a system chip: its plate is the pill surface.
        pillColor: Services.Colors.surfacePill
        pillGlyph: Services.AppState.pillGlyph("usb")
        // The pill's icon lands on the panel's header icon: same glyph, moved.
        openW: 360
        openH: Math.min((card.bodyItem ? card.bodyItem.contentH : 0) + 28, root.height - 80)
        cardRadius: 14

        pillKey: "usb"
        restSide: "right"

        body: Component {
            Item {
                // The host sizes the card off this.
                readonly property real contentH: panelCol.implicitHeight
                readonly property Item glyphTarget: hdrGlyph

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
                            id: hdrGlyph
                            opacity: card.morphingGlyph ? 0 : 1
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
    }
}
