import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import "root:/services" as Services
import "root:/modules/net" as Net
import "root:/modules/widgets" as Widgets

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
    readonly property bool shown: Services.AppState.networkVisible
    visible: shown || closeDelay.running
    onShownChanged: if (!shown) closeDelay.restart()
    // Mapped until the drop is all the way home; see DropCard.closeMs.
    Timer { id: closeDelay; interval: netCard.closeMs }

    WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

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
        ethProc.running = true
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

    // Every wired port on the machine, live or not: `dev status` is the only
    // place that lists sockets that have nothing plugged into them.
    property var ethPorts: []
    Process {
        id: ethProc
        command: ["nmcli", "-t", "-e", "no", "-f", "TYPE,DEVICE,STATE,CONNECTION", "dev", "status"]
        running: Services.AppState.networkVisible
        stdout: StdioCollector {
            onStreamFinished: {
                const out = []
                for (const line of text.split("\n")) {
                    const f = line.split(":")
                    if (f.length < 4 || f[0] !== "ethernet")
                        continue
                    const state = f[2]
                    out.push({
                        dev: f[1],
                        state: state === "unavailable" ? "No cable" : state,
                        conn: f.slice(3).join(":").trim() || f[1],
                        up: state.startsWith("connected")
                    })
                }
                root.ethPorts = out
            }
        }
    }

    Process {
        id: knownProc
        // Each saved wifi profile's SSID, not its profile name: NetworkManager
        // calls the second profile for a network "SSID 1", so comparing names
        // against SSIDs said nothing was known and the ring came up empty.
        // Settings resolves it the same way.
        command: ["sh", "-c",
            'nmcli -t -f NAME,TYPE connection show | while IFS=: read -r n t; do [ "$t" = 802-11-wireless ] || continue; nmcli -g 802-11-wireless.ssid connection show "$n"; done']
        running: Services.AppState.networkVisible
        stdout: StdioCollector {
            onStreamFinished: {
                root.knownNetworks = text.trim().split("\n").filter(l => l.length > 0)
            }
        }
    }

    Timer {
        interval: 15000
        running: root.shown
        repeat: true
        onTriggered: root.refreshNetworks()
    }

    // While a connection is landing the 10 s service poll is too slow to end
    // the swap on the ring, so this chases it for a few seconds.
    // Lets the wire to the stranger draw before the dialog covers the card.
    Timer {
        id: askDelay
        interval: 340
        onTriggered: root.showConnectDialog = true
    }

    Timer {
        id: settleTimer
        interval: 1200
        repeat: true
        triggeredOnStart: true
        property int ticks: 0
        onRunningChanged: if (running) ticks = 0
        onTriggered: {
            Services.Network.refresh()
            root.refreshNetworks()
            if (++ticks >= 12) stop()
        }
    }

    MouseArea {
        anchors.fill: parent
        z: -1
        onClicked: {
            if (root.showConnectDialog) {
                root.showConnectDialog = false
                graph.disarm()
            } else Services.AppState.networkVisible = false
        }
    }

    // Main panel — falls out of the network chip like a drop, the same opening
    // the clock and the media pill use.
    Widgets.DropCard {
        id: netCard
        shown: Services.AppState.networkVisible
        pillCX: Services.AppState.networkPillCenterX
        pillCY: Services.AppState.networkPillCenterY
        pillActive: Services.Network.online || Services.Network.wifiEnabled
        pillGlyph: Services.AppState.pillGlyph("network")
        pillLabel: Services.AppState.pillLabel("network")
        // The chip's icon and network name fly into the hub of the ring: same
        // glyph, same name, so the panel reads as the chip opened up.
        glyphTarget: Services.AppState.networkTab === "wifi" ? graph.hubGlyphItem
                                                             : ethGraph.hubGlyphItem
        labelTarget: Services.AppState.networkTab === "wifi" ? graph.hubLabelItem
                                                             : ethGraph.hubLabelItem
        pillW: Services.AppState.networkPillW
        pillH: Services.AppState.networkPillH
        openW: 680
        openH: Math.min(panelCol.implicitHeight + 28, root.height - 80)

        Column {
            id: panelCol
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 14
            spacing: 10

            // Tabs
            // Tabs. One track, one plate that slides between them, same as the
            // workspace strip: which one is live reads off where the plate is,
            // not off two colours changing at once.
            Item {
                width: parent.width
                height: 40
                readonly property real cell: (width - 8) / 2

                Rectangle {
                    id: tabTrack
                    anchors.fill: parent
                    radius: 10
                    color: Services.Colors.ghostAlpha(0.12)
                }

                Rectangle {
                    id: tabSlider
                    height: parent.height - 8
                    y: 4
                    x: (Services.AppState.networkTab === "ethernet" ? parent.cell + 8 : 0) + 4
                    width: parent.cell - 8
                    radius: 8
                    color: Services.Colors.ghost
                    gradient: Services.Prefs.useGradients ? Services.Colors.accentGradient : null
                    Behavior on x { SmoothedAnimation { duration: 260 } }
                }

                Row {
                    anchors.fill: parent
                    spacing: 8

                    Repeater {
                        model: [
                            { id: "wifi",     label: "Wi-Fi",    icon: "\ue1ba" },
                            { id: "ethernet", label: "Ethernet", icon: "\ue8be" },
                        ]
                        delegate: Item {
                            required property var modelData
                            readonly property bool on: Services.AppState.networkTab === modelData.id
                            width: (parent.width - 8) / 2
                            height: parent.height

                            Row {
                                anchors.centerIn: parent
                                spacing: 6
                                Text {
                                    text: modelData.icon
                                    color: parent.parent.on ? Services.Colors.abyss : Services.Colors.snow
                                    font.pixelSize: 16
                                    font.family: "Material Symbols Rounded"
                                    anchors.verticalCenter: parent.verticalCenter
                                    Behavior on color { ColorAnimation { duration: 200 } }
                                }
                                Text {
                                    text: modelData.label
                                    color: parent.parent.on ? Services.Colors.abyss : Services.Colors.snow
                                    font.pixelSize: 13
                                    font.family: "JetBrainsMono NF"
                                    anchors.verticalCenter: parent.verticalCenter
                                    Behavior on color { ColorAnimation { duration: 200 } }
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
            }

            // Both tabs live in one box that resizes between them, and they
            // cross-fade rather than swapping on the spot. Flipping `visible`
            // put the whole of one side on screen in the frame the other left,
            // and the card's height went with it in the same frame.
            Item {
                id: tabBody
                width: parent.width
                clip: true
                readonly property Item live: Services.AppState.networkTab === "wifi"
                    ? wifiCol : ethCol
                height: tabBody.live.implicitHeight
                Behavior on height { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }

                // Wifi tab
                Column {
                    id: wifiCol
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    spacing: 8
                    opacity: Services.AppState.networkTab === "wifi" ? 1 : 0
                    visible: opacity > 0.01
                    Behavior on opacity { NumberAnimation { duration: 170 } }

                    RowLayout {
                        width: parent.width
                        Text {
                            text: "Wireless"
                            color: Services.Colors.mist
                            font.pixelSize: 11
                            font.family: "JetBrainsMono NF"
                            Layout.fillWidth: true
                        }
                        // No refresh icon here: the scan chip in the ring is
                        // the one place a scan is started from.
                        Rectangle {
                            width: 52; height: 28; radius: 14
                            color: root.wifiEnabled ? Services.Colors.ghost : Services.Colors.ghostAlpha(0.25)
                            gradient: Services.Prefs.useGradients && (root.wifiEnabled) ? Services.Colors.accentGradient : null
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

                    // ── The ring ───────────────────────────────────────
                    // What you are on in the middle, every network you have saved
                    // and can see around it. Strangers stay in the list below: the
                    // ring must not recompose itself every time the radio scans.
                    Widgets.NodeGraph {
                        id: graph
                        width: parent.width
                        // Fixed. The ring keeps its room whether six networks are
                        // in range or none: a card that shrinks to fit whatever the
                        // radio happens to see reads as cut off, and the wires to
                        // the top and bottom slots had nowhere to run.
                        height: 360
                        // Radio off folds the ring into the hub instead of blanking it.
                        live: root.wifiEnabled
                        handOverGlyph: netCard.morphingGlyph
                        handOverLabel: netCard.morphingLabel

                        readonly property var knownInRange: root.networks.filter(
                            n => !n.active && root.knownNetworks.includes(n.ssid))

                        function wifiGlyph(sig) {
                            return sig >= 75 ? "\ue1ba" : sig >= 50 ? "\uebe1"
                                 : sig >= 25 ? "\uebd6" : "\uebe4"
                        }

                        hubActive: Services.Network.wifiSsid !== ""
                        // Disconnected, the hub has to say exactly what the chip on
                        // the bar says, or there is nothing for the chip's icon and
                        // word to fly onto. Connected they already agreed, which is
                        // why Wi-Fi was the one that worked.
                        hubGlyph: Services.Network.wifiSsid !== ""
                            ? graph.wifiGlyph(Services.Network.wifiSignal)
                            : (Services.Network.wifiEnabled ? "\ueb31" : "\ue1da")
                        hubLabel: Services.Network.wifiSsid !== ""
                            ? Services.Network.wifiSsid
                            : (Services.Network.wifiEnabled ? "Searching" : "Disabled")
                        hubSub: Services.Network.wifiSsid !== ""
                            ? Services.Network.wifiSignal + "%" : ""
                        emptyHint: !root.wifiEnabled ? "Wi-Fi is off"
                            : graph.scanMode ? "Nothing in range"
                            : "No saved network in range"

                        // The scan chip keeps the last slot for good. Pressing it
                        // takes the middle and the ring fills with strangers.
                        scanEnabled: true
                        scanGlyph: "\ue8b6"
                        scanLabel: "Scan"
                        scanSub: graph.scanMode
                            ? (graph.strangers.length + " nearby") : "Nearby"
                        // Six slots, and the six worth having are the six you can
                        // actually reach — so the ring is picked by signal. It is
                        // then laid out by name, because signal jitters on every
                        // scan and sorting by it made the slots reshuffle under
                        // your finger. Anything past six lives in Settings, which
                        // keeps the plain lists.
                        readonly property var strangers: root.networks.filter(
                            n => !n.active && !root.knownNetworks.includes(n.ssid))
                            .slice().sort((a, b) => b.signal - a.signal)
                            .slice(0, 6)
                            .sort((a, b) => a.ssid.localeCompare(b.ssid))
                        scanNodes: graph.strangers.map(n => ({
                            id: n.ssid,
                            glyph: graph.wifiGlyph(n.signal),
                            label: n.ssid,
                            sub: n.signal + "%",
                            active: false
                        }))
                        onScanActivated: root.refreshNetworks()
                        // Nothing is agreed with a stranger yet, so this only asks:
                        // the wire is strung to it and the password panel follows a
                        // beat later, so you see which one you picked before the
                        // card is replaced.
                        onScanNodeActivated: function(id) {
                            root.connectingTo = id
                            root.password = ""
                            root.showPassword = false
                            askDelay.restart()
                        }
                        onScanClosed: root.refreshNetworks()

                        nodes: graph.knownInRange.map(n => ({
                            id: n.ssid,
                            glyph: graph.wifiGlyph(n.signal),
                            label: n.ssid,
                            sub: n.signal + "%",
                            active: false
                        }))

                        // `nmcli dev wifi connect SSID` was the bug: for a network
                        // you already have a profile for it tries to build a second
                        // one, gets asked for a password it was never given, and
                        // fails — and the panel had already closed itself, so
                        // nothing ever said so. Bring the saved profile up by name
                        // instead (NetworkManager calls it "SSID 1"), and only fall
                        // back to a fresh connect when there is no profile. The
                        // panel stays open now: the swap on the ring is the report.
                        onNodeActivated: function(id) {
                            Quickshell.execDetached(["sh", "-c",
                                'ssid="$1"; prof=$(nmcli -t -f NAME,TYPE connection show | while IFS=: read -r n t; do [ "$t" = 802-11-wireless ] || continue; s=$(nmcli -g 802-11-wireless.ssid connection show "$n"); if [ "$s" = "$ssid" ]; then printf %s "$n"; break; fi; done); if [ -n "$prof" ]; then nmcli connection up id "$prof"; else nmcli device wifi connect "$ssid"; fi',
                                "sh", id])
                            settleTimer.start()
                        }
                        // Clicking what you are connected to drops it. Forgetting a
                        // network lives in Settings, which keeps the plain lists.
                        onHubActivated: {
                            if (Services.Network.wifiSsid !== "")
                                Quickshell.execDetached(["sh", "-c",
                                    'dev=$(nmcli -t -e no -f TYPE,DEVICE dev status | grep "^wifi:" | cut -d: -f2 | head -1); [ -n "$dev" ] && nmcli device disconnect "$dev"'])
                            settleTimer.start()
                        }
                    }


                    // The password lives in the card, not in a second one on top of
                    // it: a stranger you are joining is still on the ring behind
                    // this, wired to the middle, and covering that up to ask for
                    // eight characters threw the whole picture away.
                    Rectangle {
                        id: askRow
                        width: parent.width
                        radius: 10
                        color: Services.Colors.ghostAlpha(0.12)
                        clip: true
                        height: root.showConnectDialog ? 92 : 0
                        opacity: root.showConnectDialog ? 1 : 0
                        Behavior on height { NumberAnimation { duration: 240; easing.type: Easing.OutQuint } }
                        Behavior on opacity { NumberAnimation { duration: 160 } }

                        function join() {
                            // argv, not a shell string: an SSID or password holding
                            // a quote would otherwise close it and run the rest.
                            let cmd = ["nmcli", "dev", "wifi", "connect", root.connectingTo]
                            if (root.password.length > 0)
                                cmd.push("password", root.password)
                            Quickshell.execDetached(cmd)
                            root.showConnectDialog = false
                            // Back to the connection view: what you just joined
                            // belongs in the middle, and the card stays up for it.
                            graph.exitScan()
                            settleTimer.start()
                        }
                        function cancel() {
                            root.showConnectDialog = false
                            graph.disarm()
                        }

                        Column {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 8

                            Text {
                                text: "Password for " + root.connectingTo
                                color: Services.Colors.mist
                                font.pixelSize: 11
                                font.family: "JetBrainsMono NF"
                            }

                            RowLayout {
                                width: parent.width
                                spacing: 8

                                Rectangle {
                                    Layout.fillWidth: true
                                    height: 36
                                    radius: 8
                                    color: Services.Colors.ghostAlpha(0.12)
                                    border.color: passInput.activeFocus
                                        ? Services.Colors.ghost : Services.Colors.ghostAlpha(0.3)
                                    border.width: 1
                                    Behavior on border.color { ColorAnimation { duration: 150 } }

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 10
                                        anchors.rightMargin: 6
                                        spacing: 8

                                        Item {
                                            Layout.fillWidth: true
                                            height: 26
                                            Text {
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: "Password"
                                                color: Services.Colors.ash
                                                font.pixelSize: 13
                                                font.family: "JetBrainsMono NF"
                                                visible: passInput.text.length === 0
                                            }
                                            TextInput {
                                                id: passInput
                                                anchors.fill: parent
                                                text: root.password
                                                echoMode: root.showPassword ? TextInput.Normal : TextInput.Password
                                                color: Services.Colors.snow
                                                font.pixelSize: 13
                                                font.family: "JetBrainsMono NF"
                                                verticalAlignment: TextInput.AlignVCenter
                                                onTextChanged: root.password = text
                                                Keys.onReturnPressed: askRow.join()
                                                Keys.onEscapePressed: askRow.cancel()
                                                // Opens ready to type: it was asked
                                                // for, nobody wants to click it too.
                                                focus: root.showConnectDialog
                                            }
                                        }
                                        Text {
                                            text: root.showPassword ? "\ue8f5" : "\ue8f4"
                                            color: Services.Colors.mist
                                            font.pixelSize: 16
                                            font.family: "Material Symbols Rounded"
                                            MouseArea {
                                                anchors.fill: parent
                                                anchors.margins: -6
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: root.showPassword = !root.showPassword
                                            }
                                        }
                                    }
                                }

                                Rectangle {
                                    Layout.preferredWidth: 84
                                    height: 36; radius: 8
                                    color: Services.Colors.ghostAlpha(0.18)
                                    Text {
                                        anchors.centerIn: parent
                                        text: "Cancel"
                                        color: Services.Colors.snow
                                        font.pixelSize: 12
                                        font.family: "JetBrainsMono NF"
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        hoverEnabled: true
                                        onEntered: parent.color = Services.Colors.ghostAlpha(0.3)
                                        onExited: parent.color = Services.Colors.ghostAlpha(0.18)
                                        onClicked: askRow.cancel()
                                    }
                                }

                                Rectangle {
                                    Layout.preferredWidth: 92
                                    height: 36; radius: 8
                                    color: Services.Colors.ghost
                                    gradient: Services.Prefs.useGradients ? Services.Colors.accentGradient : null
                                    Rectangle {
                                        anchors.fill: parent
                                        radius: parent.radius
                                        color: Services.Colors.snowAlpha(0.16)
                                        opacity: joinMouse.containsMouse ? 1 : 0
                                        Behavior on opacity { NumberAnimation { duration: 150 } }
                                    }
                                    Text {
                                        anchors.centerIn: parent
                                        text: "Join"
                                        color: Services.Colors.abyss
                                        font.pixelSize: 12
                                        font.bold: true
                                        font.family: "JetBrainsMono NF"
                                    }
                                    MouseArea {
                                        id: joinMouse
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        hoverEnabled: true
                                        onClicked: askRow.join()
                                    }
                                }
                            }
                        }
                    }
                }

                // Ethernet tab — same graph, wired ports instead of networks. A
                // machine with a dock or a USB adapter has more than one, and the
                // ring is exactly the right shape for "which socket is live".
                Column {
                    id: ethCol
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    spacing: 8
                    opacity: Services.AppState.networkTab === "ethernet" ? 1 : 0
                    visible: opacity > 0.01
                    Behavior on opacity { NumberAnimation { duration: 170 } }

                    // Wi-Fi has a radio to switch and this has none, so this side was a
                    // whole row shorter and the card jumped by that much on every tab.
                    // Rather than a switch that does nothing, the row carries what there
                    // is to say about the wired side, and both tabs now measure the same.
                    RowLayout {
                        width: parent.width
                        height: 28
                        Text {
                            text: "Wired"
                            color: Services.Colors.mist
                            font.pixelSize: 11
                            font.family: "JetBrainsMono NF"
                            Layout.fillWidth: true
                        }
                        Text {
                            text: root.ethPorts.length === 0
                                ? "No port"
                                : root.ethPorts.length + (root.ethPorts.length === 1 ? " port" : " ports")
                            color: Services.Colors.ash
                            font.pixelSize: 11
                            font.family: "JetBrainsMono NF"
                        }
                    }

                    Widgets.NodeGraph {
                        id: ethGraph
                        width: parent.width
                        height: 360

                        handOverGlyph: netCard.morphingGlyph
                        handOverLabel: netCard.morphingLabel
                        readonly property var ports: root.ethPorts
                        readonly property var linked: ethGraph.ports.find(p => p.up) || null

                        hubActive: ethGraph.linked !== null
                        // The chip wears `lan` and the interface name when the
                        // cable is what is carrying you, so the hub wears them
                        // too and the piece has somewhere to land; it was showing
                        // `settings_ethernet` and the profile name, which are both
                        // different strings. The profile moves to the sub-line.
                        hubGlyph: "\ueb2f"
                        hubLabel: ethGraph.linked ? ethGraph.linked.dev : "No cable"
                        hubSub: ethGraph.linked ? ethGraph.linked.conn : ""
                        emptyHint: ethGraph.ports.length === 0
                            ? "No wired port on this machine" : "Nothing else plugged in"

                        // The live one is already the middle, so it does not take a
                        // slot as well; the rest are the sockets you could use.
                        nodes: ethGraph.ports.filter(p => !p.up).map(p => ({
                            id: p.dev,
                            glyph: "\ue8be",
                            label: p.dev,
                            sub: p.state,
                            active: false
                        }))

                        onNodeActivated: function(id) {
                            Quickshell.execDetached(["nmcli", "device", "connect", id])
                            root.refreshNetworks()
                            settleTimer.start()
                        }
                        onHubActivated: {
                            if (ethGraph.linked)
                                Quickshell.execDetached(["nmcli", "device", "disconnect",
                                                         ethGraph.linked.dev])
                            settleTimer.start()
                        }
                    }
                }
            }

            Item { height: 4 }
        }
    }

}
