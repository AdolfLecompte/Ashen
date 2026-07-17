import Quickshell
import Quickshell.Bluetooth
import QtQuick
import QtQuick.Layouts

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
    readonly property bool shown: Services.AppState.bluetoothVisible
    visible: shown || closeDelay.running
    Timer { id: closeDelay; interval: 300 }

    property var adapter: Bluetooth.defaultAdapter

    function startScan() {
        if (adapter && adapter.enabled && !adapter.discovering) {
            adapter.discovering = true
            scanTimer.restart()
        }
    }

    Timer {
        id: scanTimer
        interval: 15000
        onTriggered: if (root.adapter) root.adapter.discovering = false
    }

    onShownChanged: {
        if (shown) Qt.callLater(startScan)
        else {
            closeDelay.restart()
            if (adapter && adapter.discovering) {
                scanTimer.stop()
                adapter.discovering = false
            }
        }
    }

    // Bluetooth.defaultAdapter arrives asynchronously over DBus: if the panel is
    // already open when it shows up, the scan has to start right then.
    onAdapterChanged: if (adapter && shown) Qt.callLater(startScan)

    Connections {
        target: root.adapter
        function onEnabledChanged() {
            if (root.adapter && root.adapter.enabled) {
                Qt.callLater(root.startScan)
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        z: -1
        onClicked: Services.AppState.bluetoothVisible = false
    }

    Rectangle {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 64
        anchors.rightMargin: 12
        width: 340
        radius: 14
        height: Math.min(panelCol.implicitHeight + 28, root.height - 80)
        color: Services.Colors.surfaceAlpha(0.95)
        border.color: Services.Colors.ghostAlpha(0.2)
        border.width: 0
        clip: true

        opacity: Services.AppState.bluetoothVisible ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
        transform: Translate {
            x: Services.AppState.bluetoothVisible ? 0 : -24
            Behavior on x { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
        }

        MouseArea { anchors.fill: parent; onClicked: {} }

        Column {
            id: panelCol
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 14
            spacing: 10

            // Header
            RowLayout {
                width: parent.width

                Text {
                    text: ""
                    color: Services.Colors.ghost
                    font.pixelSize: 20
                    font.family: "Material Symbols Rounded"
                }
                Text {
                    text: "Bluetooth"
                    color: Services.Colors.snow
                    font.pixelSize: 14
                    font.family: "JetBrainsMono NF"
                    font.bold: true
                    Layout.fillWidth: true
                    leftPadding: 8
                }

                Rectangle {
                    width: 28; height: 28; radius: 8; color: "transparent"
                    Text {
                        anchors.centerIn: parent
                        text: ""
                        color: root.adapter && root.adapter.discovering ? Services.Colors.ghost : Services.Colors.mist
                        font.pixelSize: 16
                        font.family: "Material Symbols Rounded"
                        Behavior on color { ColorAnimation { duration: 200 } }
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        onEntered: parent.color = Services.Colors.ghostAlpha(0.15)
                        onExited: parent.color = "transparent"
                        onClicked: root.startScan()
                    }
                }

                Rectangle {
                    width: 52; height: 28; radius: 14
                    color: (root.adapter && root.adapter.enabled) ? Services.Colors.ghost : Services.Colors.ghostAlpha(0.25)
                    Behavior on color { ColorAnimation { duration: 200 } }

                    Rectangle {
                        width: 20; height: 20; radius: 10
                        color: Services.Colors.snow
                        anchors.verticalCenter: parent.verticalCenter
                        x: (root.adapter && root.adapter.enabled) ? parent.width - width - 4 : 4
                        Behavior on x { NumberAnimation { duration: 200 } }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        enabled: root.adapter !== null
                        onClicked: {
                            if (root.adapter) root.adapter.enabled = !root.adapter.enabled
                        }
                    }
                }
            }

            // Connected device
            Rectangle {
                width: parent.width
                height: Services.Network.btDevice !== "" ? 64 : 0
                visible: Services.Network.btDevice !== ""
                radius: 8
                color: Services.Colors.ghostAlpha(0.2)
                border.color: Services.Colors.ghost
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 10
                    Text {
                        text: ""
                        color: Services.Colors.ghost
                        font.pixelSize: 22
                        font.family: "Material Symbols Rounded"
                    }
                    Column {
                        Layout.fillWidth: true
                        spacing: 2
                        Text {
                            text: Services.Network.btDevice
                            color: Services.Colors.snow
                            font.pixelSize: 14
                            font.family: "JetBrainsMono NF"
                            font.bold: true
                        }
                        Text {
                            text: "Connected"
                            color: Services.Colors.ghost
                            font.pixelSize: 11
                            font.family: "JetBrainsMono NF"
                        }
                    }
                    Text {
                        text: ""
                        color: Services.Colors.ghost
                        font.pixelSize: 22
                        font.family: "Material Symbols Rounded"
                    }
                }
            }

            // Device list
            Column {
                width: parent.width
                spacing: 4
                visible: root.adapter && root.adapter.devices.values.length > 0

                Text {
                    text: root.adapter && root.adapter.discovering ? "Scanning..." : "Devices"
                    color: Services.Colors.mist
                    font.pixelSize: 10
                    font.family: "JetBrainsMono NF"
                    leftPadding: 4
                }

                Repeater {
                    model: root.adapter ? root.adapter.devices.values : []
                    delegate: Rectangle {
                        required property var modelData
                        width: panelCol.width
                        height: 54
                        radius: 8
                        color: modelData.connected ? Services.Colors.ghostAlpha(0.2) : "transparent"
                        Behavior on color { ColorAnimation { duration: 150 } }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 10

                            Text {
                                text: modelData.connected ? "" : ""
                                color: modelData.connected ? Services.Colors.ghost : Services.Colors.mist
                                font.pixelSize: 20
                                font.family: "Material Symbols Rounded"
                            }
                            Column {
                                Layout.fillWidth: true
                                spacing: 2
                                Text {
                                    text: modelData.name
                                    color: modelData.connected ? Services.Colors.snow : Services.Colors.mist
                                    font.pixelSize: 13
                                    font.family: "JetBrainsMono NF"
                                    font.bold: modelData.connected
                                    elide: Text.ElideRight
                                    width: parent.width
                                }
                                Text {
                                    text: modelData.pairing ? "Pairing..."
                                        : modelData.connected ? "Connected"
                                        : modelData.paired ? "Paired"
                                        : "Available"
                                    color: modelData.connected ? Services.Colors.ghost : Services.Colors.ash
                                    font.pixelSize: 10
                                    font.family: "JetBrainsMono NF"
                                }
                            }
                            Text {
                                visible: modelData.connected
                                text: ""
                                color: Services.Colors.ghost
                                font.pixelSize: 18
                                font.family: "Material Symbols Rounded"
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            hoverEnabled: true
                            enabled: !modelData.pairing
                            onEntered: if (!modelData.connected) parent.color = Services.Colors.ghostAlpha(0.1)
                            onExited: if (!modelData.connected) parent.color = "transparent"
                            onClicked: {
                                if (modelData.connected) {
                                    modelData.disconnect()
                                } else if (modelData.paired) {
                                    modelData.connect()
                                } else {
                                    // BlueZ rejects connect() without prior bonding
                                    modelData.trusted = true
                                    modelData.pair()
                                }
                            }
                        }
                    }
                }
            }

            // No devices
            Rectangle {
                width: parent.width
                height: 60
                radius: 8
                color: Services.Colors.ghostAlpha(0.08)
                visible: !root.adapter || root.adapter.devices.values.length === 0

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 10
                    Text {
                        text: root.adapter && root.adapter.discovering ? "" : ""
                        color: Services.Colors.ash
                        font.pixelSize: 22
                        font.family: "Material Symbols Rounded"
                    }
                    Text {
                        text: root.adapter && root.adapter.discovering ? "Scanning..." : (root.adapter ? "No devices found" : "No adapter")
                        color: Services.Colors.ash
                        font.pixelSize: 13
                        font.family: "JetBrainsMono NF"
                        Layout.fillWidth: true
                    }
                }
            }

            Item { height: 4 }
        }
    }
}
