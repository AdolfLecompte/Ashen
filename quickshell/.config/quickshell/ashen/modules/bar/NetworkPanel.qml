import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

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
    visible: Services.AppState.networkVisible

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

    Process {
        id: scanProc
        command: ["nmcli", "-t", "-f", "active,ssid,signal,security", "dev", "wifi"]
        running: Services.AppState.networkVisible
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
                root.networks = unique
            }
        }
    }

    Process {
        id: knownProc
        command: ["nmcli", "-t", "-f", "name", "connection", "show"]
        running: Services.AppState.networkVisible
        stdout: StdioCollector {
            onStreamFinished: {
                root.knownNetworks = text.trim().split("\n").filter(l => l.length > 0)
            }
        }
    }

    Timer {
        interval: 15000
        running: root.visible
        repeat: true
        onTriggered: root.refreshNetworks()
    }

    MouseArea {
        anchors.fill: parent
        z: -1
        onClicked: {
            if (root.showConnectDialog) root.showConnectDialog = false
            else Services.AppState.networkVisible = false
        }
    }

    // Panel principal
    Rectangle {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.topMargin: 64
        width: 420
        radius: 14
        height: Math.min(panelCol.implicitHeight + 28, root.height - 80)
        color: Services.Colors.surfaceAlpha(0.95)
        border.color: Services.Colors.ghostAlpha(0.2)
        border.width: 1
        clip: true
        visible: !root.showConnectDialog

        opacity: Services.AppState.networkVisible && !root.showConnectDialog ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
        transform: Translate {
            x: Services.AppState.networkVisible ? 0 : -24
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

            // Tabs
            Row {
                width: parent.width
                spacing: 8
                topPadding: 4

                Repeater {
                    model: [
                        { id: "wifi",     label: "Wi-Fi",    icon: "" },
                        { id: "ethernet", label: "Ethernet", icon: "" },
                    ]
                    delegate: Rectangle {
                        required property var modelData
                        width: (panelCol.width - 8) / 2
                        height: 36
                        radius: 8
                        color: Services.AppState.networkTab === modelData.id
                            ? Services.Colors.ghost
                            : Services.Colors.ghostAlpha(0.15)
                        Behavior on color { ColorAnimation { duration: 150 } }

                        Row {
                            anchors.centerIn: parent
                            spacing: 6
                            Text {
                                text: modelData.icon
                                color: Services.AppState.networkTab === modelData.id ? Services.Colors.abyss : Services.Colors.snow
                                font.pixelSize: 16
                                font.family: "Material Symbols Rounded"
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                text: modelData.label
                                color: Services.AppState.networkTab === modelData.id ? Services.Colors.abyss : Services.Colors.snow
                                font.pixelSize: 13
                                font.family: "JetBrainsMono NF"
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Services.AppState.networkTab = modelData.id
                        }
                    }
                }
            }

            // Wifi tab
            Column {
                width: parent.width
                spacing: 8
                visible: Services.AppState.networkTab === "wifi"

                RowLayout {
                    width: parent.width
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
                            text: ""
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
                            onClicked: root.refreshNetworks()
                        }
                    }
                    Rectangle {
                        width: 52; height: 28; radius: 14
                        color: root.wifiEnabled ? Services.Colors.ghost : Services.Colors.ghostAlpha(0.25)
                        Behavior on color { ColorAnimation { duration: 200 } }
                        Rectangle {
                            width: 20; height: 20; radius: 10
                            color: Services.Colors.snow
                            anchors.verticalCenter: parent.verticalCenter
                            x: root.wifiEnabled ? parent.width - width - 4 : 4
                            Behavior on x { NumberAnimation { duration: 200 } }
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.wifiEnabled = !root.wifiEnabled
                                Quickshell.execDetached(["sh", "-c", root.wifiEnabled ? "nmcli radio wifi on" : "nmcli radio wifi off"])
                            }
                        }
                    }
                }

                // Red conectada
                Rectangle {
                    width: parent.width
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
                        Text {
                            text: ""
                            color: Services.Colors.ghost
                            font.pixelSize: 22
                            font.family: "Material Symbols Rounded"
                        }
                        Column {
                            Layout.fillWidth: true
                            spacing: 2
                            Text {
                                text: Services.Network.wifiSsid
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

                // Redes conocidas
                Column {
                    width: parent.width
                    spacing: 4
                    visible: root.networks.filter(n => !n.active && root.knownNetworks.includes(n.ssid)).length > 0

                    Text {
                        text: "Known Networks"
                        color: Services.Colors.mist
                        font.pixelSize: 10
                        font.family: "JetBrainsMono NF"
                        leftPadding: 4
                    }

                    Rectangle {
                        width: parent.width
                        height: Math.min(knownList.contentHeight, 4 * 54)
                        color: "transparent"
                        clip: true

                        ListView {
                            id: knownList
                            anchors.fill: parent
                            model: root.networks.filter(n => !n.active && root.knownNetworks.includes(n.ssid))
                            spacing: 2
                            clip: true
                            ScrollBar.vertical: ScrollBar {
                                policy: knownList.contentHeight > knownList.height ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
                                width: 4
                            }
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
                                    Text {
                                        text: modelData.signal >= 75 ? "" : modelData.signal >= 50 ? "" : modelData.signal >= 25 ? "" : ""
                                        color: Services.Colors.mist
                                        font.pixelSize: 20
                                        font.family: "Material Symbols Rounded"
                                    }
                                    Column {
                                        Layout.fillWidth: true
                                        spacing: 2
                                        Text {
                                            text: modelData.ssid
                                            color: Services.Colors.snow
                                            font.pixelSize: 13
                                            font.family: "JetBrainsMono NF"
                                            elide: Text.ElideRight
                                            width: parent.width
                                        }
                                        Text {
                                            text: modelData.signal + "% signal"
                                            color: Services.Colors.ash
                                            font.pixelSize: 10
                                            font.family: "JetBrainsMono NF"
                                        }
                                    }
                                    Text {
                                        visible: modelData.secure
                                        text: ""
                                        color: Services.Colors.ash
                                        font.pixelSize: 14
                                        font.family: "Material Symbols Rounded"
                                    }
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    hoverEnabled: true
                                    onEntered: parent.color = Services.Colors.ghostAlpha(0.1)
                                    onExited: parent.color = "transparent"
                                    onClicked: {
                                        Quickshell.execDetached(["sh", "-c", "nmcli dev wifi connect \"" + modelData.ssid + "\""])
                                        Services.AppState.networkVisible = false
                                    }
                                }
                            }
                        }
                    }
                }

                // Redes disponibles
                Column {
                    width: parent.width
                    spacing: 4

                    Text {
                        text: "Available Networks"
                        color: Services.Colors.mist
                        font.pixelSize: 10
                        font.family: "JetBrainsMono NF"
                        leftPadding: 4
                    }

                    Rectangle {
                        width: parent.width
                        height: Math.min(availList.contentHeight, 4 * 54)
                        color: "transparent"
                        clip: true

                        ListView {
                            id: availList
                            anchors.fill: parent
                            model: root.networks.filter(n => !n.active && !root.knownNetworks.includes(n.ssid))
                            spacing: 2
                            clip: true
                            ScrollBar.vertical: ScrollBar {
                                policy: availList.contentHeight > availList.height ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
                                width: 4
                            }
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
                                    Text {
                                        text: modelData.signal >= 75 ? "" : modelData.signal >= 50 ? "" : modelData.signal >= 25 ? "" : ""
                                        color: Services.Colors.mist
                                        font.pixelSize: 20
                                        font.family: "Material Symbols Rounded"
                                    }
                                    Column {
                                        Layout.fillWidth: true
                                        spacing: 2
                                        Text {
                                            text: modelData.ssid
                                            color: Services.Colors.snow
                                            font.pixelSize: 13
                                            font.family: "JetBrainsMono NF"
                                            elide: Text.ElideRight
                                            width: parent.width
                                        }
                                        Text {
                                            text: modelData.signal + "% signal"
                                            color: Services.Colors.ash
                                            font.pixelSize: 10
                                            font.family: "JetBrainsMono NF"
                                        }
                                    }
                                    Text {
                                        visible: modelData.secure
                                        text: ""
                                        color: Services.Colors.ash
                                        font.pixelSize: 14
                                        font.family: "Material Symbols Rounded"
                                    }
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    hoverEnabled: true
                                    onEntered: parent.color = Services.Colors.ghostAlpha(0.1)
                                    onExited: parent.color = "transparent"
                                    onClicked: {
                                        root.connectingTo = modelData.ssid
                                        root.password = ""
                                        root.showPassword = false
                                        root.showConnectDialog = true
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Ethernet tab
            Column {
                width: parent.width
                spacing: 8
                visible: Services.AppState.networkTab === "ethernet"
                Rectangle {
                    width: parent.width
                    height: 60
                    radius: 8
                    color: Services.Colors.ghostAlpha(0.1)
                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        Text {
                            text: ""
                            color: Services.Colors.ghost
                            font.pixelSize: 22
                            font.family: "Material Symbols Rounded"
                        }
                        Column {
                            Layout.fillWidth: true
                            Text {
                                text: "Ethernet"
                                color: Services.Colors.snow
                                font.pixelSize: 13
                                font.family: "JetBrainsMono NF"
                                font.bold: true
                            }
                            Text {
                                text: "Cable connection"
                                color: Services.Colors.mist
                                font.pixelSize: 10
                                font.family: "JetBrainsMono NF"
                            }
                        }
                    }
                }
            }

            Item { height: 4 }
        }
    }

    // Dialog conexion
    Rectangle {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.topMargin: 64
        width: 380
        height: connectCol.implicitHeight + 32
        radius: 14
        color: Services.Colors.surfaceAlpha(0.98)
        border.color: Services.Colors.ghostAlpha(0.2)
        border.width: 1
        visible: root.showConnectDialog

        opacity: root.showConnectDialog ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
        transform: Translate {
            x: root.showConnectDialog ? 0 : -24
            Behavior on x { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
        }

        MouseArea { anchors.fill: parent; onClicked: {} }

        Column {
            id: connectCol
            anchors.centerIn: parent
            width: parent.width - 32
            spacing: 16

            RowLayout {
                width: parent.width
                Text {
                    text: ""
                    color: Services.Colors.ghost
                    font.pixelSize: 22
                    font.family: "Material Symbols Rounded"
                }
                Column {
                    Layout.fillWidth: true
                    spacing: 2
                    Text {
                        text: "Connect to Network"
                        color: Services.Colors.mist
                        font.pixelSize: 11
                        font.family: "JetBrainsMono NF"
                    }
                    Text {
                        text: root.connectingTo
                        color: Services.Colors.snow
                        font.pixelSize: 15
                        font.family: "JetBrainsMono NF"
                        font.bold: true
                    }
                }
                Rectangle {
                    width: 28; height: 28; radius: 8; color: "transparent"
                    Text {
                        anchors.centerIn: parent
                        text: "✕"
                        color: Services.Colors.mist
                        font.pixelSize: 14
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        onEntered: parent.color = Services.Colors.ghostAlpha(0.15)
                        onExited: parent.color = "transparent"
                        onClicked: root.showConnectDialog = false
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

                    Text {
                        text: ""
                        color: Services.Colors.ghost
                        font.pixelSize: 16
                        font.family: "Material Symbols Rounded"
                    }

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
                            text: root.password
                            echoMode: root.showPassword ? TextInput.Normal : TextInput.Password
                            color: Services.Colors.snow
                            font.pixelSize: 14
                            font.family: "JetBrainsMono NF"
                            verticalAlignment: TextInput.AlignVCenter
                            onTextChanged: root.password = text
                            Keys.onReturnPressed: connectBtn.connect()
                        }
                    }

                    Rectangle {
                        width: 32; height: 32; radius: 6; color: "transparent"
                        Text {
                            anchors.centerIn: parent
                            text: root.showPassword ? "" : ""
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
                            onClicked: root.showPassword = !root.showPassword
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
                    Text {
                        anchors.centerIn: parent
                        text: "Cancel"
                        color: Services.Colors.snow
                        font.pixelSize: 13
                        font.family: "JetBrainsMono NF"
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        onEntered: parent.color = Services.Colors.ghostAlpha(0.25)
                        onExited: parent.color = Services.Colors.ghostAlpha(0.15)
                        onClicked: root.showConnectDialog = false
                    }
                }

                Rectangle {
                    id: connectBtn
                    Layout.fillWidth: true
                    height: 40; radius: 8
                    color: Services.Colors.ghost

                    function connect() {
                        let cmd = root.password.length > 0
                            ? "nmcli dev wifi connect \"" + root.connectingTo + "\" password \"" + root.password + "\""
                            : "nmcli dev wifi connect \"" + root.connectingTo + "\""
                        Quickshell.execDetached(["sh", "-c", cmd])
                        root.showConnectDialog = false
                        Services.AppState.networkVisible = false
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "Connect"
                        color: Services.Colors.abyss
                        font.pixelSize: 13
                        font.family: "JetBrainsMono NF"
                        font.bold: true
                    }
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
