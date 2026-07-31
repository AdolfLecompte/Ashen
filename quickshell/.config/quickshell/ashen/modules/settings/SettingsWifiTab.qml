import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "root:/services" as Services
import "root:/modules/settings/components"
import "root:/modules/net" as Net

Item {
    id: tab
    anchors.fill: parent

    property var networks: []
    property var knownNetworks: []
    property string connectingTo: ""

    // Saved networks currently in range (not the active one).
    readonly property var knownRows: tab.networks.filter(n => !n.active && tab.knownNetworks.includes(n.ssid))

    property string password: ""
    property bool showPassword: false
    property bool showConnectDialog: false

    function refreshNetworks() {
        scanProc.running = true
        knownProc.running = true
    }

    // Forget a network by SSID. A NetworkManager profile name isn't always the
    // SSID: on duplicates NM makes "SSID 1", "SSID 2"…, so `connection delete id
    // <ssid>` fails silently for those. We resolve SSID→profile by walking the
    // wifi profiles and deleting every match. SSID passed as $1 (argv, not
    // interpolated) to avoid shell injection.
    function forgetSsid(ssid) {
        forgetProc.ssid = ssid
        forgetProc.running = true
    }

    Process {
        id: forgetProc
        property string ssid: ""
        running: false
        command: ["sh", "-c",
            'nmcli -t -f NAME,TYPE connection show | while IFS=: read -r n t; do [ "$t" = 802-11-wireless ] || continue; s=$(nmcli -g 802-11-wireless.ssid connection show "$n"); [ "$s" = "$1" ] && nmcli connection delete "$n"; done',
            "_", ssid]
        onExited: tab.refreshNetworks()
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
        // Emit each saved wifi profile's SSID (not the profile name, which may be
        // "SSID 1"), so known/available classification compares SSID against SSID.
        command: ["sh", "-c",
            'nmcli -t -f NAME,TYPE connection show | while IFS=: read -r n t; do [ "$t" = 802-11-wireless ] || continue; nmcli -g 802-11-wireless.ssid connection show "$n"; done']
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

    // After a radio toggle, re-poll once nmcli has actually flipped the radio, so
    // the optimistic state is confirmed (or corrected) and, on turn-on, networks
    // reappear without waiting for the 15s scan.
    Timer {
        id: wifiSettleTimer
        interval: 1500
        onTriggered: { Services.Network.refresh(); tab.refreshNetworks() }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 28
        spacing: 14
        visible: !tab.showConnectDialog

        Text {
            visible: false   // the drawer header carries the section name
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
                    onClicked: tab.refreshNetworks()
                }
            }
            Toggle {
                checked: Services.Network.wifiEnabled
                onToggled: {
                    let turnOn = !Services.Network.wifiEnabled
                    // Optimistic: flip the pill/panel and empty the list NOW so
                    // there's no ~6s lag waiting for the service's 10s poll.
                    Services.Network.wifiEnabled = turnOn
                    if (!turnOn) {
                        tab.networks = []
                        Services.Network.wifiSsid = ""
                        Services.Network.wifiSignal = 0
                    }
                    Quickshell.execDetached(["sh", "-c", turnOn ? "nmcli radio wifi on" : "nmcli radio wifi off"])
                    wifiSettleTimer.restart()   // reconcile with reality shortly
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: Services.Network.wifiSsid !== "" ? 64 : 0
            visible: Services.Network.wifiSsid !== ""
            radius: 8
            // Filled, not outlined: the accent border read as a glow and
            // nothing else in the shell outlines a selection.
            color: Services.Colors.ghostAlpha(0.2)
            border.width: 0
            RowLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 10
                Text { text: ""; color: Services.Colors.ghost; font.pixelSize: 22; font.family: "Material Symbols Rounded" }
                Column {
                    Layout.fillWidth: true
                    spacing: 2
                    Text { text: Services.Network.wifiSsid; color: Services.Colors.snow; font.pixelSize: 14; font.family: "JetBrainsMono NF"; font.bold: true }
                    Text { text: "Connected"; color: Services.Colors.ghost; font.pixelSize: 11; font.family: "JetBrainsMono NF" }
                }
                // Forget the current network
                Rectangle {
                    Layout.preferredWidth: 34
                    Layout.preferredHeight: 34
                    radius: 8
                    color: "transparent"
                    Text {
                        anchors.centerIn: parent
                        text: "\ue5cd"
                        color: Services.Colors.ash
                        font.pixelSize: 18
                        font.family: "Material Symbols Rounded"
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        onEntered: parent.color = Services.Colors.ghostAlpha(0.18)
                        onExited: parent.color = "transparent"
                        onClicked: tab.forgetSsid(Services.Network.wifiSsid)
                    }
                }
                Text { text: ""; color: Services.Colors.ghost; font.pixelSize: 22; font.family: "Material Symbols Rounded" }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4
            visible: tab.knownRows.length > 0
            Text { text: "Known Networks"; color: Services.Colors.mist; font.pixelSize: 10; font.family: "JetBrainsMono NF"; leftPadding: 4 }
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(knownList.contentHeight, 3 * 54)
                color: "transparent"
                clip: true
                ListView {
                    id: knownList
                    anchors.fill: parent
                    model: tab.knownRows
                    spacing: 2
                    clip: true
                    ScrollBar.vertical: ScrollBar { policy: knownList.contentHeight > knownList.height ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff; width: 4 }
                    delegate: Net.WifiNetworkRow {
                        required property var modelData
                        width: knownList.width
                        net: modelData
                        known: true
                        onActivate: Quickshell.execDetached(["nmcli", "dev", "wifi", "connect", modelData.ssid])
                        onForget: tab.forgetSsid(modelData.ssid)
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
                    delegate: Net.WifiNetworkRow {
                        required property var modelData
                        width: availList.width
                        net: modelData
                        known: false
                        onActivate: {
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

    // Connection dialog (overlay inside the tab itself)
    Rectangle {
        anchors.centerIn: parent
        width: 360
        height: connectCol.implicitHeight + 32
        radius: 14
        color: Services.Colors.surfacePanel
        border.color: Services.Colors.ghostAlpha(0.2)
        border.width: 0
        visible: tab.showConnectDialog

        Column {
            id: connectCol
            anchors.centerIn: parent
            width: parent.width - 32
            spacing: 16

            RowLayout {
                width: parent.width
                Text { text: ""; color: Services.Colors.ghost; font.pixelSize: 22; font.family: "Material Symbols Rounded" }
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
                    Text { text: ""; color: Services.Colors.ghost; font.pixelSize: 16; font.family: "Material Symbols Rounded" }
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
                            text: tab.showPassword ? "" : ""
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
                    gradient: Services.Prefs.useGradients ? Services.Colors.accentGradient : null
                    function connect() {
                        // argv, not a shell string: an SSID or password holding a
                        // quote would otherwise close it and run the rest as shell.
                        let cmd = ["nmcli", "dev", "wifi", "connect", tab.connectingTo]
                        if (tab.password.length > 0)
                            cmd.push("password", tab.password)
                        Quickshell.execDetached(cmd)
                        tab.showConnectDialog = false
                    }
                    // Hover keeps the accent and just lifts it with a white veil.
                    Rectangle {
                        anchors.fill: parent
                        radius: parent.radius
                        color: Services.Colors.snowAlpha(0.16)
                        opacity: connectMouse.containsMouse ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: 150 } }
                    }
                    Text { anchors.centerIn: parent; text: "Connect"; color: Services.Colors.abyss; font.pixelSize: 13; font.family: "JetBrainsMono NF"; font.bold: true }
                    MouseArea {
                        id: connectMouse
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        onClicked: connectBtn.connect()
                    }
                }
            }
        }
    }
}
