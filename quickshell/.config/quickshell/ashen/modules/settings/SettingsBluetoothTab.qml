import Quickshell
import Quickshell.Bluetooth
import QtQuick
import QtQuick.Layouts
import "root:/services" as Services
import "root:/modules/settings/components"
import "root:/modules/net" as Net

Item {
    id: tab
    anchors.fill: parent

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
        onTriggered: if (tab.adapter) tab.adapter.discovering = false
    }

    // Bluetooth.defaultAdapter arrives asynchronously over DBus: it is still null
    // when the tab is created, so it has to be retried once it shows up.
    onAdapterChanged: if (adapter) Qt.callLater(startScan)
    Component.onCompleted: Qt.callLater(startScan)
    Component.onDestruction: {
        scanTimer.stop()
        if (adapter && adapter.discovering) adapter.discovering = false
    }

    Connections {
        target: tab.adapter
        function onEnabledChanged() {
            if (tab.adapter && tab.adapter.enabled) Qt.callLater(tab.startScan)
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 28
        spacing: 14

        RowLayout {
            Layout.fillWidth: true
            Text {
                visible: false   // the drawer header carries the section name
                text: "Bluetooth"
                color: Services.Colors.snow
                font.pixelSize: 20
                font.bold: true
                font.family: "JetBrainsMono NF"
                Layout.fillWidth: true
            }
            Rectangle {
                width: 28; height: 28; radius: 8
                color: "transparent"
                Text {
                    anchors.centerIn: parent
                    text: ""
                    color: tab.adapter && tab.adapter.discovering ? Services.Colors.ghost : Services.Colors.mist
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
                    onClicked: tab.startScan()
                }
            }
            Toggle {
                checked: tab.adapter !== null && tab.adapter.enabled
                enabled: tab.adapter !== null
                onToggled: if (tab.adapter) tab.adapter.enabled = !tab.adapter.enabled
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: Services.Network.btDevice !== "" ? 64 : 0
            visible: Services.Network.btDevice !== ""
            radius: 8
            // Filled, not outlined: the accent border read as a glow and
            // nothing else in the shell outlines a selection.
            color: Services.Colors.ghostAlpha(0.2)
            border.width: 0
            RowLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 10
                Text { text: ""; color: Services.Colors.ghost; font.pixelSize: 22; font.family: "Material Symbols Rounded" }
                Column {
                    Layout.fillWidth: true
                    spacing: 2
                    Text { text: Services.Network.btDevice; color: Services.Colors.snow; font.pixelSize: 14; font.family: "JetBrainsMono NF"; font.bold: true }
                    Text { text: "Connected"; color: Services.Colors.ghost; font.pixelSize: 11; font.family: "JetBrainsMono NF" }
                }
                Text { text: ""; color: Services.Colors.ghost; font.pixelSize: 22; font.family: "Material Symbols Rounded" }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 4
            visible: tab.adapter && tab.adapter.devices.values.length > 0
            Text {
                text: tab.adapter && tab.adapter.discovering ? "Scanning..." : "Devices"
                color: Services.Colors.mist
                font.pixelSize: 10
                font.family: "JetBrainsMono NF"
                leftPadding: 4
            }
            Repeater {
                model: tab.adapter ? tab.adapter.devices.values : []
                delegate: Net.BtDeviceRow {
                    required property var modelData
                    Layout.fillWidth: true
                    device: modelData
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 60
            radius: 8
            color: Services.Colors.ghostAlpha(0.08)
            visible: !tab.adapter || tab.adapter.devices.values.length === 0
            RowLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 10
                Text {
                    text: tab.adapter && tab.adapter.discovering ? "" : ""
                    color: Services.Colors.ash
                    font.pixelSize: 22
                    font.family: "Material Symbols Rounded"
                }
                Text {
                    text: tab.adapter && tab.adapter.discovering ? "Scanning..." : (tab.adapter ? "No devices found" : "No adapter")
                    color: Services.Colors.ash
                    font.pixelSize: 13
                    font.family: "JetBrainsMono NF"
                    Layout.fillWidth: true
                }
            }
        }

        Item { Layout.fillHeight: true }
    }
}
