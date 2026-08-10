import QtQuick

import "root:/services" as Services

// The system pill is a strip of chips and nothing else. Each one is a
// SystemChip: what it shows and what a click does live here, how it looks
// and behaves lives there.
Rectangle {
    id: root
    // Hidden from Settings > Bar > Pills
    visible: Services.Prefs.pillVisible("system")

    readonly property bool vertical: Services.Sizes.barVertical

    height: root.vertical ? sysRow.height + 16 : Services.Sizes.pillH
    radius: Services.Sizes.pillR
    color: Services.Colors.surfacePill
    border.color: Services.Colors.fillRest
    border.width: 0
    width: root.vertical ? Services.Sizes.pillH : sysRow.width + 16

    BarStrip {
        id: sysRow
        anchors.centerIn: parent
        spacing: 4

        // Keyboard layout: read-only. Switching lives in Settings > System.
        SystemChip {
            interactive: false
            glyph: "\uE312"
            label: Services.Keyboard.label
            idleColor: Services.Colors.snow
        }

        SystemChip {
            pillKey: "network"
            // A network name is whatever the router was called, so this one
            // gets a width band; the readings below do not need one.
            minLabelW: 46
            maxLabelW: 108
            // Lit whenever the radio is on, connected or not — the bluetooth
            // chip keys on its radio alone and these two have to agree.
            active: Services.Network.online || Services.Network.wifiEnabled
            open: Services.AppState.networkVisible
            glyph: Services.Network.wifiSsid !== "" ? (Services.Network.wifiSignal >= 75 ? "\ue1ba" : Services.Network.wifiSignal >= 50 ? "\uebe1" : Services.Network.wifiSignal >= 25 ? "\uebd6" : "\uebe4") : (Services.Network.ethConnection !== "" ? "\ueb2f" : (Services.Network.wifiEnabled ? "\ueb31" : "\ue1da"))
            // These say what the radio is DOING; "On"/"Off" only repeated what the
            // fill already shows. With the radio simply on, NetworkManager sweeps every
            // so often, so "Searching" is the intent, not a live state.
            label: Services.Network.wifiSsid !== "" ? Services.Network.wifiSsid
                 : (Services.Network.ethConnection !== "" ? Services.Network.ethDevice
                 : (Services.Network.wifiEnabled ? "Searching" : "Disabled"))
            onActivated: {
                Services.AppState.networkTab = "wifi"
                Services.AppState.networkVisible = !Services.AppState.networkVisible
            }
        }

        SystemChip {
            pillKey: "bluetooth"
            minLabelW: 46
            maxLabelW: 108
            active: Services.Network.btEnabled
            open: Services.AppState.bluetoothVisible
            // Connected wears the linked mark, a live radio with nothing on it
            // the plain one, off the struck-through one. There was no connected
            // glyph before, so a paired headset and an idle adapter looked
            // exactly the same on the bar.
            glyph: Services.Network.btDevice !== "" ? "\ue1a8"
                 : (Services.Network.btEnabled ? "\ue1a7" : "\ue1a9")
            label: Services.Network.btDevice !== "" ? Services.Network.btDevice
                 : (Services.Network.btEnabled ? "Scanning" : "Disabled")
            onActivated: Services.AppState.bluetoothVisible = !Services.AppState.bluetoothVisible
        }

        SystemChip {
            pillKey: "volume"
            active: !Services.Audio.muted && Services.Audio.volume > 0
            open: Services.AppState.volumeVisible
            glyph: Services.Audio.icon(Services.Audio.volume, Services.Audio.muted, Services.Audio.headphones)
            label: Services.Audio.muted ? "Mute" : Services.Audio.volume + "%"
            onActivated: Services.AppState.volumeVisible = !Services.AppState.volumeVisible
        }

        SystemChip {
            pillKey: "battery"
            active: Services.Battery.charging
            open: Services.AppState.batteryVisible
            glyph: Services.Battery.charging ? "" : Services.Battery.level >= 90 ? "" : Services.Battery.level >= 70 ? "" : Services.Battery.level >= 50 ? "" : Services.Battery.level >= 30 ? "" : Services.Battery.level >= 15 ? "" : ""
            label: Services.Battery.level + "%"
            // Below a fifth it stops being a reading and starts being a warning.
            idleColor: Services.Battery.level >= 20 ? Services.Colors.snow
                                                    : Services.Colors.error_
            onActivated: Services.AppState.batteryVisible = !Services.AppState.batteryVisible
        }
    }
}
