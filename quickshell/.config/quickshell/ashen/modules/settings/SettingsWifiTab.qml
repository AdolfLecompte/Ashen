import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "root:/services" as Services

Item {
    id: tab
    anchors.fill: parent

    property bool wifiEnabled: true
    property var networks: []
    property var knownNetworks: []
    property string connectingTo: ""
    property string password: ""
    property bool showPassword: false
    property bool showConnectDialog: false

    function refreshNetworks() {
        scanProc.running = true
        knownProc.running = true
    }

    Component.onCompleted: refreshNetworks()

    Process {
        id: scanProc
        command: ["nmcli", "-t", "-f", "active,ssid,signal,security", "dev", "wifi"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                let lines = text.trim().split("\n").filter(l => l.length > 0)
                let nets = []
                for (let line of lines) {
                    let parts = line.split(":")
                    if (parts.length >= 3 && parts[1].length > 0) {
                        nets.push({
                            active: parts[0] === "yes",
                            ssid: parts[1],
                            signal: parseInt(parts[2]) || 0,
                            secure: parts[3] !== "" && parts[3] !== "--",
                        })
                    }
                }
                nets.sort((a, b) => b.active - a.active || b.signal - a.signal)
                let unique = []
                let seen = new Set()
                for (let n of nets) {
                    if (!seen.has(n.ssid)) {
                        seen.add(n.ssid)
                        unique.push(n)
                    }
                }
                tab.networks = unique
            }
        }
    }

    Process {
        id: knownProc
        command: ["nmcli", "-t", "-f", "name", "connection", "show"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                tab.knownNetworks = text.trim().split("\n").filter(l => l.length > 0)
            }
        }
    }

    Timer {
        interval: 15000
        running: true
        repeat: true
        onTriggered: tab.refreshNetworks()
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 28
        spacing: 14
        visible: !tab.showConnectDialog

        Text {
            text: "Wi-Fi"
            color: Services.Colors.snow
            font.pixelSize: 20
            font.bold: true
            font.family: "JetBrainsMono NF"
        }

        RowLayout {
            Layout.fillWidth: true
            Text {
                text: "Wireless"
                color: Services.Colors.mist
                font.pixelSize: 11
                font.family: "JetBrainsMono NF"
                Layout.fillWidth: true
            }
            Rectangle {
                width: 28; height: 28; radius: 8
                color: "transparent"
                Text {
                    anchors.centerIn: parent
                    text: ""
                    color: Services.Colors.ghost
                    font.pixelSize: 16
                    font.family: "Material Symbols Rounded"
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onEntered: parent.color = Services.Colors.ghostAlpha(0.15)
                    onExited: parent.color = "transparent"
                    onClicked: tab.refreshNetworks()
                }
            }
            Rectangle {
                width: 52; height: 28; radius: 14
                color: tab.wifiEnabled ? Services.Colors.ghost : Services.Colors.ghostAlpha(0.25)
                Behavior on color { ColorAnimation { duration: 200 } }
                Rectangle {
                    width: 20; height: 20; radius: 10
                    color: Services.Colors.snow
                    anchors.verticalCenter: parent.verticalCenter
                    x: tab.wifiEnabled ? parent.width - width - 4 : 4
                    Behavior on x { NumberAnimation { duration: 200 } }
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        tab.wifiEnabled = !tab.wifiEnabled
                        Quickshell.execDetached(["sh", "-c", tab.wifiEnabled ? "nmcli radio wifi on" : "nmcli radio wifi off"])
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: Services.Network.wifiSsid !== "" ? 64 : 0
            visible: Services.Network.wifiSsid !== ""
            radius: 8
            color: Services.Colors.ghostAlpha(0.2)
            border.color: Services.Colors.ghost
            border.width: 1
            RowLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 10
                Text { text: ""; color: Services.Colors.ghost; font.pixelSize: 22; font.family: "Material Symbols Rounded" }
                Column {
                    Layout.fillWidth: true
                    spacing: 2
                    Text { text: Services.Network.wifiSsid; color: Services.Colors.snow; font.pixelSize: 14; font.family: "JetBrainsMono NF"; font.bold: true }
                    Text { text: "Connected"; color: Services.Colors.ghost; font.pixelSize: 11; font.family: "JetBrainsMono NF" }
                }
                Text { text: ""; color: Services.Colors.ghost; font.pixelSize: 22; font.family: "Material Symbols Rounded" }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4
            visible: tab.networks.filter(n => !n.active && tab.knownNetworks.includes(n.ssid)).length > 0
            Text { text: "Known Networks"; color: Services.Colors.mist; font.pixelSize: 10; font.family: "JetBrainsMono NF"; leftPadding: 4 }
            Rectangle {
                Layout.fillWidth: true
                height: Math.min(knownList.contentHeight, 3 * 54)
                color: "transparent"
                clip: true
                ListView {
                    id: knownList
                    anchors.fill: parent
                    model: tab.networks.filter(n => !n.active && tab.knownNetworks.includes(n.ssid))
                    spacing: 2
                    clip: true
                    ScrollBar.vertical: ScrollBar { policy: knownList.contentHeight > knownList.height ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff; width: 4 }
                    delegate: Rectangle {
                        required property var modelData
                        width: knownList.width
                        height: 54
                        radius: 8
                        color: "transparent"
                        Behavior on color { ColorAnimation { duration: 150 } }
                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 10
                            Text { text: ""; color: Services.Colors.mist; font.pixelSize: 20; font.family: "Material Symbols Rounded" }
                            Column {
                                Layout.fillWidth: true
                                spacing: 2
                                Text { text: modelData.ssid; color: Services.Colors.snow; font.pixelSize: 13; font.family: "JetBrainsMono NF"; elide: Text.ElideRight; width: parent.width }
                                Text { text: modelData.signal + "% signal"; color: Services.Colors.ash; font.pixelSize: 10; font.family: "JetBrainsMono NF" }
                            }
                            Text { visible: modelData.secure; text: ""; color: Services.Colors.ash; font.pixelSize: 14; font.family: "Material Symbols Rounded" }
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            hoverEnabled: true
                            onEntered: parent.color = Services.Colors.ghostAlpha(0.1)
                            onExited: parent.color = "transparent"
                            onClicked: {
                                Quickshell.execDetached(["sh", "-c", "nmcli dev wifi connect \"" + modelData.ssid + "\""])
                            }
                        }
                    }
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 4
            Text { text: "Available Networks"; color: Services.Colors.mist; font.pixelSize: 10; font.family: "JetBrainsMono NF"; leftPadding: 4 }
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: "transparent"
                clip: true
                ListView {
                    id: availList
                    anchors.fill: parent
                    model: tab.networks.filter(n => !n.active && !tab.knownNetworks.includes(n.ssid))
                    spacing: 2
                    clip: true
                    ScrollBar.vertical: ScrollBar { policy: availList.contentHeight > availList.height ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff; width: 4 }
                    delegate: Rectangle {
                        required property var modelData
                        width: availList.width
                        height: 54
                        radius: 8
                        color: "transparent"
                        Behavior on color { ColorAnimation { duration: 150 } }
                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 10
                            Text { text: ""; color: Services.Colors.mist; font.pixelSize: 20; font.family: "Material Symbols Rounded" }
                            Column {
                                Layout.fillWidth: true
                                spacing: 2
                                Text { text: modelData.ssid; color: Services.Colors.snow; font.pixelSize: 13; font.family: "JetBrainsMono NF"; elide: Text.ElideRight; width: parent.width }
                                Text { text: modelData.signal + "% signal"; color: Services.Colors.ash; font.pixelSize: 10; font.family: "JetBrainsMono NF" }
                            }
                            Text { visible: modelData.secure; text: ""; color: Services.Colors.ash; font.pixelSize: 14; font.family: "Material Symbols Rounded" }
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            hoverEnabled: true
                            onEntered: parent.color = Services.Colors.ghostAlpha(0.1)
                            onExited: parent.color = "transparent"
                            onClicked: {
                                tab.connectingTo = modelData.ssid
                                tab.password = ""
                                tab.showPassword = false
                                tab.showConnectDialog = true
                            }
                        }
                    }
                }
            }
        }
    }

    // Dialogo de conexion (overlay dentro del propio tab)
    Rectangle {
        anchors.centerIn: parent
        width: 360
        height: connectCol.implicitHeight + 32
        radius: 14
        color: Services.Colors.surfaceAlpha(0.98)
        border.color: Services.Colors.ghostAlpha(0.2)
        border.width: 1
        visible: tab.showConnectDialog

        Column {
            id: connectCol
            anchors.centerIn: parent
            width: parent.width - 32
            spacing: 16

            RowLayout {
                width: parent.width
                Text { text: ""; color: Services.Colors.ghost; font.pixelSize: 22; font.family: "Material Symbols Rounded" }
                Column {
                    Layout.fillWidth: true
                    spacing: 2
                    Text { text: "Connect to Network"; color: Services.Colors.mist; font.pixelSize: 11; font.family: "JetBrainsMono NF" }
                    Text { text: tab.connectingTo; color: Services.Colors.snow; font.pixelSize: 15; font.family: "JetBrainsMono NF"; font.bold: true }
                }
                Rectangle {
                    width: 28; height: 28; radius: 8; color: "transparent"
                    Text { anchors.centerIn: parent; text: "\u2715"; color: Services.Colors.mist; font.pixelSize: 14 }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        onEntered: parent.color = Services.Colors.ghostAlpha(0.15)
                        onExited: parent.color = "transparent"
                        onClicked: tab.showConnectDialog = false
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: 48
                radius: 8
                color: Services.Colors.ghostAlpha(0.1)
                border.color: passInput.activeFocus ? Services.Colors.ghost : Services.Colors.ghostAlpha(0.3)
                border.width: 1
                Behavior on border.color { ColorAnimation { duration: 150 } }
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 8
                    spacing: 8
                    Text { text: ""; color: Services.Colors.ghost; font.pixelSize: 16; font.family: "Material Symbols Rounded" }
                    Item {
                        Layout.fillWidth: true
                        height: 30
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Password"
                            color: Services.Colors.ash
                            font.pixelSize: 14
                            font.family: "JetBrainsMono NF"
                            visible: passInput.text.length === 0
                        }
                        TextInput {
                            id: passInput
                            anchors.fill: parent
                            text: tab.password
                            echoMode: tab.showPassword ? TextInput.Normal : TextInput.Password
                            color: Services.Colors.snow
                            font.pixelSize: 14
                            font.family: "JetBrainsMono NF"
                            verticalAlignment: TextInput.AlignVCenter
                            onTextChanged: tab.password = text
                            Keys.onReturnPressed: connectBtn.connect()
                        }
                    }
                    Rectangle {
                        width: 32; height: 32; radius: 6; color: "transparent"
                        Text {
                            anchors.centerIn: parent
                            text: tab.showPassword ? "" : ""
                            color: Services.Colors.mist
                            font.pixelSize: 18
                            font.family: "Material Symbols Rounded"
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            hoverEnabled: true
                            onEntered: parent.color = Services.Colors.ghostAlpha(0.15)
                            onExited: parent.color = "transparent"
                            onClicked: tab.showPassword = !tab.showPassword
                        }
                    }
                }
            }

            RowLayout {
                width: parent.width
                spacing: 8
                Rectangle {
                    Layout.fillWidth: true
                    height: 40; radius: 8
                    color: Services.Colors.ghostAlpha(0.15)
                    Text { anchors.centerIn: parent; text: "Cancel"; color: Services.Colors.snow; font.pixelSize: 13; font.family: "JetBrainsMono NF" }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        onEntered: parent.color = Services.Colors.ghostAlpha(0.25)
                        onExited: parent.color = Services.Colors.ghostAlpha(0.15)
                        onClicked: tab.showConnectDialog = false
                    }
                }
                Rectangle {
                    id: connectBtn
                    Layout.fillWidth: true
                    height: 40; radius: 8
                    color: Services.Colors.ghost
                    function connect() {
                        let cmd = tab.password.length > 0
                            ? "nmcli dev wifi connect \"" + tab.connectingTo + "\" password \"" + tab.password + "\""
                            : "nmcli dev wifi connect \"" + tab.connectingTo + "\""
                        Quickshell.execDetached(["sh", "-c", cmd])
                        tab.showConnectDialog = false
                    }
                    Text { anchors.centerIn: parent; text: "Connect"; color: Services.Colors.abyss; font.pixelSize: 13; font.family: "JetBrainsMono NF"; font.bold: true }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        onEntered: parent.color = Services.Colors.shade
                        onExited: parent.color = Services.Colors.ghost
                        onClicked: connectBtn.connect()
                    }
                }
            }
        }
    }
}
