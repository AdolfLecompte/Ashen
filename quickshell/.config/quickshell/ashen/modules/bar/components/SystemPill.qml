import QtQuick
import QtQuick.Layouts

import "root:/services" as Services

Rectangle {
    id: root
    // Hidden from Settings > Bar > Pills
    visible: Services.Prefs.pillVisible("system")
    readonly property int innerR: Services.Sizes.innerR
    readonly property int innerH: Services.Sizes.innerH

    readonly property bool vertical: Services.Sizes.barVertical

    height: root.vertical ? sysRow.height + 16 : Services.Sizes.pillH
    radius: Services.Sizes.pillR
    color: Services.Colors.surfaceAlpha(0.82)
    border.color: Services.Colors.ghostAlpha(0.2)
    border.width: 0
    width: root.vertical ? Services.Sizes.pillH : sysRow.width + 16

    BarStrip {
        id: sysRow
        anchors.centerIn: parent
        spacing: 4

        // Keyboard layout: read-only. Switching lives in Settings > System.
        Rectangle {
            radius: root.innerR
            readonly property bool expanded: root.vertical && kbHover.containsMouse
            width: root.vertical ? root.innerH : kbInner.width + 16
            height: root.vertical ? (expanded ? root.innerH + 13 : root.innerH) : root.innerH
            Behavior on height { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
            color: Services.Colors.ghostAlpha(0.2)

            MouseArea {
                id: kbHover
                anchors.fill: parent
                hoverEnabled: true
            }

            BarStrip {
                id: kbInner
                anchors.centerIn: parent
                spacing: root.vertical ? 0 : 5
                Text {
                    text: "\uE312"
                    color: Services.Colors.mist
                    font.pixelSize: 18
                    font.family: "Material Symbols Rounded"
                }
                Text {
                    text: Services.Keyboard.label
                    color: Services.Colors.snow
                    visible: !root.vertical || parent.parent.expanded
                    font.pixelSize: root.vertical ? 9 : 12
                    font.family: "JetBrainsMono NF"
                    font.bold: true
                }
            }
        }
        
        // Wifi
        Rectangle {
            id: wifiPill
            radius: root.innerR
            readonly property bool expanded: root.vertical && (wifiHover.containsMouse || Services.AppState.networkVisible)
            width: root.vertical ? root.innerH : wifiInner.width + 16
            height: root.vertical ? (expanded ? root.innerH + 13 : root.innerH) : root.innerH
            Behavior on height { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
            // Active (bright) whenever the radio is on -- connected or not --
            // mirroring the bluetooth pill, which keys on btEnabled alone.
            readonly property bool active: Services.Network.online || Services.Network.wifiEnabled
            color: active ? Services.Colors.ghost
                          : (wifiHover.containsMouse ? Services.Colors.ghostAlpha(0.4) : Services.Colors.ghostAlpha(0.2))
            gradient: Services.Prefs.useGradients && active ? Services.Colors.accentGradient : null
            Behavior on color { ColorAnimation { duration: 300 } }
            // Subtle hover grow
            scale: wifiHover.containsMouse ? 1.05 : 1.0
            Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

            MouseArea {
                id: wifiHover
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                hoverEnabled: true
                onClicked: {
                    Services.AppState.networkTab = "wifi"
                    Services.AppState.networkVisible = !Services.AppState.networkVisible
                }
            }

            PillCenter { key: "network" }

            BarStrip {
                id: wifiInner
                anchors.centerIn: parent
                spacing: root.vertical ? 0 : 5
                Text {
                    text: Services.Network.wifiSsid !== "" ? (Services.Network.wifiSignal >= 75 ? "\ue1ba" : Services.Network.wifiSignal >= 50 ? "\uebe1" : Services.Network.wifiSignal >= 25 ? "\uebd6" : "\uebe4") : (Services.Network.ethConnection !== "" ? "\ueb2f" : (Services.Network.wifiEnabled ? "\ueb31" : "\ue1da"))
                    color: (wifiPill.active || wifiHover.containsMouse) ? Services.Colors.abyss : Services.Colors.ash
                    font.pixelSize: 18
                    font.family: "Material Symbols Rounded"
                    Behavior on color { ColorAnimation { duration: 200 } }
                }
                Text {
                    text: Services.Network.wifiSsid !== "" ? Services.Network.wifiSsid : (Services.Network.ethConnection !== "" ? Services.Network.ethDevice : (Services.Network.wifiEnabled ? "On" : "Off"))
                    color: (wifiPill.active || wifiHover.containsMouse) ? Services.Colors.abyss : Services.Colors.ash
                    visible: !root.vertical || parent.parent.expanded
                    font.pixelSize: root.vertical ? 9 : 12
                    font.family: "JetBrainsMono NF"
                    font.bold: true
                    Behavior on color { ColorAnimation { duration: 200 } }
                }
            }
        }

        // Bluetooth
        Rectangle {
            radius: root.innerR
            readonly property bool expanded: root.vertical && (btHover.containsMouse || Services.AppState.bluetoothVisible)
            width: root.vertical ? root.innerH : btInner.width + 16
            height: root.vertical ? (expanded ? root.innerH + 13 : root.innerH) : root.innerH
            Behavior on height { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
            color: Services.Network.btEnabled ? Services.Colors.ghost
                                              : (btHover.containsMouse ? Services.Colors.ghostAlpha(0.4) : Services.Colors.ghostAlpha(0.2))
            gradient: Services.Prefs.useGradients && Services.Network.btEnabled ? Services.Colors.accentGradient : null
            Behavior on color { ColorAnimation { duration: 300 } }
            // Subtle hover grow
            scale: btHover.containsMouse ? 1.05 : 1.0
            Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

            MouseArea {
                id: btHover
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                hoverEnabled: true
                onClicked: Services.AppState.bluetoothVisible = !Services.AppState.bluetoothVisible
            }

            PillCenter { key: "bluetooth" }

            BarStrip {
                id: btInner
                anchors.centerIn: parent
                spacing: root.vertical ? 0 : 5
                Text {
                    text: Services.Network.btEnabled ? "" : ""
                    color: (Services.Network.btEnabled || btHover.containsMouse) ? Services.Colors.abyss : Services.Colors.ash
                    font.pixelSize: 18
                    font.family: "Material Symbols Rounded"
                    Behavior on color { ColorAnimation { duration: 200 } }
                }
                Text {
                    text: Services.Network.btDevice !== "" ? Services.Network.btDevice : (Services.Network.btEnabled ? "On" : "Off")
                    color: (Services.Network.btEnabled || btHover.containsMouse) ? Services.Colors.abyss : Services.Colors.ash
                    visible: !root.vertical || parent.parent.expanded
                    font.pixelSize: root.vertical ? 9 : 12
                    font.family: "JetBrainsMono NF"
                    font.bold: true
                    Behavior on color { ColorAnimation { duration: 200 } }
                }
            }
        }

        // Volume
        Rectangle {
            radius: root.innerR
            readonly property bool expanded: root.vertical && (volHover.containsMouse || Services.AppState.volumeVisible)
            width: root.vertical ? root.innerH : volInner.width + 16
            height: root.vertical ? (expanded ? root.innerH + 13 : root.innerH) : root.innerH
            Behavior on height { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
            color: (!Services.Audio.muted && Services.Audio.volume > 0) ? Services.Colors.ghost
                                                                        : (volHover.containsMouse ? Services.Colors.ghostAlpha(0.4) : Services.Colors.ghostAlpha(0.2))
            gradient: Services.Prefs.useGradients && !Services.Audio.muted && Services.Audio.volume > 0 ? Services.Colors.accentGradient : null
            Behavior on color { ColorAnimation { duration: 300 } }
            // Subtle hover grow
            scale: volHover.containsMouse ? 1.05 : 1.0
            Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
            MouseArea {
                id: volHover
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                hoverEnabled: true
                onClicked: Services.AppState.volumeVisible = !Services.AppState.volumeVisible
            }
            PillCenter { key: "volume" }
            BarStrip {
                id: volInner
                anchors.centerIn: parent
                spacing: root.vertical ? 0 : 5
                Text {
                    id: volIcon
                    text: Services.Audio.icon(Services.Audio.volume, Services.Audio.muted, Services.Audio.headphones)
                    color: (!Services.Audio.muted && Services.Audio.volume > 0 || volHover.containsMouse) ? Services.Colors.abyss : Services.Colors.ash
                    font.pixelSize: 18
                    font.family: "Material Symbols Rounded"
                    Behavior on color { ColorAnimation { duration: 200 } }

                    // Subtle fade + scale pop when the glyph swaps (headphones <-> speaker, level buckets).
                    transform: Scale {
                        id: volScale
                        origin.x: volIcon.width / 2
                        origin.y: volIcon.height / 2
                    }
                    onTextChanged: volSwap.restart()
                    ParallelAnimation {
                        id: volSwap
                        NumberAnimation { target: volIcon; property: "opacity"; from: 0.0; to: 1.0; duration: 180; easing.type: Easing.OutCubic }
                        NumberAnimation { target: volScale; property: "xScale"; from: 0.7; to: 1.0; duration: 200; easing.type: Easing.OutCubic }
                        NumberAnimation { target: volScale; property: "yScale"; from: 0.7; to: 1.0; duration: 200; easing.type: Easing.OutCubic }
                    }
                }
                Text {
                    text: Services.Audio.muted ? "Mute" : Services.Audio.volume + "%"
                    color: (!Services.Audio.muted && Services.Audio.volume > 0 || volHover.containsMouse) ? Services.Colors.abyss : Services.Colors.ash
                    visible: !root.vertical || parent.parent.expanded
                    font.pixelSize: root.vertical ? 9 : 12
                    font.family: "JetBrainsMono NF"
                    font.bold: true
                    Behavior on color { ColorAnimation { duration: 200 } }
                }
            }
        }
        // Brightness
        Rectangle {
            radius: root.innerR
            readonly property bool expanded: root.vertical && (brightHover.containsMouse || Services.AppState.brightnessVisible)
            width: root.vertical ? root.innerH : brightInner.width + 16
            height: root.vertical ? (expanded ? root.innerH + 13 : root.innerH) : root.innerH
            Behavior on height { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
            color: Services.Brightness.level > 0 ? Services.Colors.ghost
                                                 : (brightHover.containsMouse ? Services.Colors.ghostAlpha(0.4) : Services.Colors.ghostAlpha(0.2))
            gradient: Services.Prefs.useGradients && Services.Brightness.level > 0 ? Services.Colors.accentGradient : null
            Behavior on color { ColorAnimation { duration: 300 } }
            // Subtle hover grow
            scale: brightHover.containsMouse ? 1.05 : 1.0
            Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
            MouseArea {
                id: brightHover
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                hoverEnabled: true
                onClicked: Services.AppState.brightnessVisible = !Services.AppState.brightnessVisible
            }
            PillCenter { key: "brightness" }
            BarStrip {
                id: brightInner
                anchors.centerIn: parent
                spacing: root.vertical ? 0 : 5
                Text {
                    text: ""
                    color: (Services.Brightness.level > 0 || brightHover.containsMouse) ? Services.Colors.abyss : Services.Colors.ash
                    font.pixelSize: 18
                    font.family: "Material Symbols Rounded"
                    Behavior on color { ColorAnimation { duration: 200 } }
                }
                Text {
                    text: Services.Brightness.level + "%"
                    color: (Services.Brightness.level > 0 || brightHover.containsMouse) ? Services.Colors.abyss : Services.Colors.ash
                    visible: !root.vertical || parent.parent.expanded
                    font.pixelSize: root.vertical ? 9 : 12
                    font.family: "JetBrainsMono NF"
                    font.bold: true
                    Behavior on color { ColorAnimation { duration: 200 } }
                }
            }
        }

        // Battery
        Rectangle {
            radius: root.innerR
            readonly property bool expanded: root.vertical && (batHover.containsMouse || Services.AppState.batteryVisible)
            width: root.vertical ? root.innerH : batInner.width + 16
            height: root.vertical ? (expanded ? root.innerH + 13 : root.innerH) : root.innerH
            Behavior on height { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
            color: Services.Battery.charging ? Services.Colors.ghost
                                             : (batHover.containsMouse ? Services.Colors.ghostAlpha(0.4) : Services.Colors.ghostAlpha(0.2))
            gradient: Services.Prefs.useGradients && Services.Battery.charging ? Services.Colors.accentGradient : null
            Behavior on color { ColorAnimation { duration: 300 } }
            // Subtle hover grow
            scale: batHover.containsMouse ? 1.05 : 1.0
            Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
            MouseArea {
                id: batHover
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                hoverEnabled: true
                onClicked: Services.AppState.batteryVisible = !Services.AppState.batteryVisible
            }
            PillCenter { key: "battery" }
            BarStrip {
                id: batInner
                anchors.centerIn: parent
                spacing: root.vertical ? 0 : 5
                Text {
                    text: Services.Battery.charging ? "" : Services.Battery.level >= 90 ? "" : Services.Battery.level >= 70 ? "" : Services.Battery.level >= 50 ? "" : Services.Battery.level >= 30 ? "" : Services.Battery.level >= 15 ? "" : ""
                    color: {
                        if (Services.Battery.charging || batHover.containsMouse) return Services.Colors.abyss
                        if (Services.Battery.level >= 20) return Services.Colors.snow
                        return Services.Colors.error_
                    }
                    font.pixelSize: 18
                    font.family: "Material Symbols Rounded"
                    Behavior on color { ColorAnimation { duration: 300 } }
                }
                Text {
                    text: Services.Battery.level + "%"
                    color: {
                        if (Services.Battery.charging || batHover.containsMouse) return Services.Colors.abyss
                        if (Services.Battery.level >= 20) return Services.Colors.snow
                        return Services.Colors.error_
                    }
                    visible: !root.vertical || parent.parent.expanded
                    font.pixelSize: root.vertical ? 9 : 12
                    font.family: "JetBrainsMono NF"
                    font.bold: true
                    Behavior on color { ColorAnimation { duration: 300 } }
                }
            }
        }
    }
}
