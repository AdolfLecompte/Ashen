import Quickshell
import Quickshell.Bluetooth
import QtQuick
import QtQuick.Layouts

import "root:/services" as Services
import "root:/modules/widgets" as Widgets
import "root:/modules/net" as Net

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
    readonly property bool shown: Services.AppState.bluetoothVisible
    visible: shown || closeDelay.running
    // Mapped until the drop is all the way home; see DropCard.closeMs.
    Timer { id: closeDelay; interval: btCard.closeMs }

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

    // Falls out of the bluetooth chip like a drop, same as the network card.
    Widgets.PanelHost {
        id: btCard
        shown: Services.AppState.bluetoothVisible
        pillCX: Services.AppState.bluetoothPillCenterX
        pillCY: Services.AppState.bluetoothPillCenterY
        pillActive: Services.Network.btEnabled
        pillGlyph: Services.AppState.pillGlyph("bluetooth")
        pillLabel: Services.AppState.pillLabel("bluetooth")
        pillW: Services.AppState.bluetoothPillW
        pillH: Services.AppState.bluetoothPillH
        openW: 680
        openH: Math.min((btCard.bodyItem ? btCard.bodyItem.contentH : 0) + 28, root.height - 80)

        pillKey: "bluetooth"
        restSide: "center"

        body: Component {
            Item {
                // The host sizes the card off this.
                readonly property real contentH: panelCol.implicitHeight
                readonly property Item glyphTarget: graph.hubGlyphItem
                readonly property Item labelTarget: graph.hubLabelItem

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

                        // No refresh icon up here: the scan button at the foot of
                        // the card is the only place a scan starts from. Two
                        // buttons doing the same thing just made you wonder how
                        // they differed.
                        Rectangle {
                            width: 52; height: 28; radius: 14
                            color: (root.adapter && root.adapter.enabled) ? Services.Colors.ghost : Services.Colors.ghostAlpha(0.25)
                            gradient: Services.Prefs.useGradients && ((root.adapter && root.adapter.enabled)) ? Services.Colors.accentGradient : null
                            Behavior on color { ColorAnimation { duration: Services.Sizes.msStandard } }

                            Rectangle {
                                width: 20; height: 20; radius: 10
                                color: Services.Colors.snow
                                anchors.verticalCenter: parent.verticalCenter
                                x: (root.adapter && root.adapter.enabled) ? parent.width - width - 4 : 4
                                Behavior on x { NumberAnimation { duration: Services.Sizes.msStandard } }
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

                    // ── The ring ────────────────────────────────────────────
                    // Connected in the middle, everything paired orbiting it. Strangers live
                    // in the scan list below, so the slots stay put.
                    Widgets.NodeGraph {
                        id: graph
                        width: parent.width
                        // Fixed. The ring keeps its room whether six networks are
                        // in range or none: a card that shrinks to fit whatever the
                        // radio happens to see reads as cut off, and the wires to
                        // the top and bottom slots had nowhere to run.
                        height: 360
                        // Radio off folds the ring into the hub instead of blanking it.
                        live: root.adapter !== null && root.adapter.enabled
                        handOverGlyph: btCard.morphingGlyph
                        handOverLabel: btCard.morphingLabel

                        readonly property var known: root.adapter
                            ? root.adapter.devices.values.filter(d => d.paired || d.bonded || d.connected)
                            : []
                        readonly property var linked: graph.known.find(d => d.connected) || null

                        hubActive: graph.linked !== null
                        // With nothing paired the hub has to wear the chip's face,
                        // or its icon and word have nowhere to land. It was showing
                        // the struck-through icon and "Not connected" while the bar
                        // said the plain one and "Scanning": two different pieces.
                        hubGlyph: graph.linked ? "\ue1a8"
                                : (Services.Network.btEnabled ? "\ue1a7" : "\ue1a9")
                        // Connected, prefer the exact string the chip is showing — the
                        // graph's own name for the device usually matches it but is not
                        // the same source, and a piece only flies on an exact match.
                        hubLabel: graph.linked
                                ? (Services.Network.btDevice !== "" ? Services.Network.btDevice
                                                                    : graph.linked.name)
                                : (Services.Network.btEnabled ? "Scanning" : "Disabled")
                        hubSub: graph.linked
                            ? (graph.linked.batteryAvailable
                                ? Math.round(graph.linked.battery * 100) + "%" : "Connected")
                            : ""
                        emptyHint: !(root.adapter && root.adapter.enabled) ? "Bluetooth is off"
                            : graph.scanMode ? "Nothing in range"
                            : "No paired devices yet \u2014 press Scan"

                        // Same scan chip as Wi-Fi, in the same slot: press it and the
                        // ring fills with everything the radio can see. Strangers get
                        // no wire — nothing is paired with them yet.
                        scanEnabled: true
                        scanGlyph: "\ue8b6"
                        scanLabel: "Scan"
                        scanSub: graph.scanMode
                            ? (root.adapter && root.adapter.discovering
                                ? "Scanning\u2026" : graph.strangers.length + " nearby")
                            : "Nearby"
                        readonly property var strangers: root.adapter
                            ? root.adapter.devices.values
                                .filter(d => !(d.paired || d.bonded || d.trusted || d.connected))
                                .slice().sort((a, b) => String(a.name).localeCompare(String(b.name)))
                            : []
                        scanNodes: graph.strangers.slice(0, 6).map(d => ({
                            id: d.address,
                            glyph: "\ue1a8",
                            label: d.name,
                            sub: d.pairing ? "Pairing\u2026" : "",
                            active: false
                        }))
                        onScanActivated: root.startScan()
                        onScanNodeActivated: function(id) {
                            const d = graph.strangers.find(x => x.address === id)
                            if (!d) return
                            // BlueZ rejects connect() without prior bonding
                            d.trusted = true
                            d.pair()
                        }
                        onScanClosed: if (root.adapter && root.adapter.discovering) {
                            scanTimer.stop()
                            root.adapter.discovering = false
                        }

                        // The hub is already the connected one, so it does not get a
                        // slot as well.
                        nodes: graph.known.filter(d => !d.connected).map(d => ({
                            id: d.address,
                            glyph: "\ue1a8",
                            label: d.name,
                            sub: d.paired || d.bonded ? "Paired" : "",
                            active: false
                        }))

                        onNodeActivated: function(id) {
                            const d = graph.known.find(x => x.address === id)
                            if (d) d.connect()
                        }
                        onHubActivated: if (graph.linked) graph.linked.disconnect()
                    }

                    // Whatever the ring could not hold — six slots is its limit by
                    // design. Only up while you are actually looking, and the scan chip
                    // in the ring is the one place a scan is started from.
                    Column {
                        width: parent.width
                        spacing: 4
                        visible: graph.scanMode && overflowList.count > 0

                        Text {
                            text: "More devices"
                            color: Services.Colors.mist
                            font.pixelSize: 10
                            font.family: "JetBrainsMono NF"
                            leftPadding: 4
                        }

                        ListView {
                            id: overflowList
                            width: parent.width
                            model: graph.strangers.slice(6)
                            // Three rows, not four: past that the list makes the card
                            // taller than it is wide and the landscape shape is lost.
                            height: Math.min(count, 3) * 46 + Math.max(Math.min(count, 3) - 1, 0) * 4
                            spacing: 4
                            clip: true
                            boundsBehavior: Flickable.StopAtBounds
                            Behavior on height { NumberAnimation { duration: Services.Sizes.msStandard; easing.type: Services.Sizes.easeOut } }

                            delegate: Net.BtDeviceRow {
                                required property var modelData
                                width: overflowList.width
                                device: modelData
                            }
                        }
                    }

                    Item { height: 4 }
                }
            }
        }
    }
}
