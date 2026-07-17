import QtQuick
import QtQuick.Layouts

import "root:/services" as Services

Rectangle {
    id: root
    readonly property int innerR: 8
    readonly property int innerH: 32

    height: 44
    radius: 10
    color: Services.Colors.surfaceAlpha(0.82)
    border.color: Services.Colors.ghostAlpha(0.2)
    border.width: 0
    width: sysRow.width + 16

    Row {
        id: sysRow
        anchors.centerIn: parent
        spacing: 4

        // Keyboard layout: read-only. Switching lives in Settings > System.
        Rectangle {
            height: root.innerH
            radius: root.innerR
            width: kbInner.width + 16
            color: Services.Colors.ghostAlpha(0.2)

            Row {
                id: kbInner
                anchors.centerIn: parent
                spacing: 5
                Text {
                    text: "\uE312"
                    color: Services.Colors.mist
                    font.pixelSize: 18
                    font.family: "Material Symbols Rounded"
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text: Services.Keyboard.label
                    color: Services.Colors.snow
                    font.pixelSize: 12
                    font.family: "JetBrainsMono NF"
                    font.bold: true
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }
        
        // Wifi
        Rectangle {
            height: root.innerH
            radius: root.innerR
            width: wifiInner.width + 16
            color: Services.Network.online ? Services.Colors.ghost
                                           : (wifiHover.containsMouse ? Services.Colors.ghostAlpha(0.4) : Services.Colors.ghostAlpha(0.2))
            Behavior on color { ColorAnimation { duration: 300 } }

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

            Row {
                id: wifiInner
                anchors.centerIn: parent
                spacing: 5
                Text {
                    text: Services.Network.wifiSsid !== "" ? (Services.Network.wifiSignal >= 75 ? "" : Services.Network.wifiSignal >= 50 ? "" : Services.Network.wifiSignal >= 25 ? "" : "") : (Services.Network.ethConnection !== "" ? "" : "")
                    color: (Services.Network.online || wifiHover.containsMouse) ? Services.Colors.abyss : Services.Colors.ash
                    font.pixelSize: 18
                    font.family: "Material Symbols Rounded"
                    anchors.verticalCenter: parent.verticalCenter
                    Behavior on color { ColorAnimation { duration: 200 } }
                }
                Text {
                    text: Services.Network.wifiSsid !== "" ? Services.Network.wifiSsid : (Services.Network.ethConnection !== "" ? Services.Network.ethConnection : "Off")
                    color: (Services.Network.online || wifiHover.containsMouse) ? Services.Colors.abyss : Services.Colors.ash
                    font.pixelSize: 12
                    font.family: "JetBrainsMono NF"
                    font.bold: true
                    anchors.verticalCenter: parent.verticalCenter
                    Behavior on color { ColorAnimation { duration: 200 } }
                }
            }
        }

        // Bluetooth
        Rectangle {
            height: root.innerH
            radius: root.innerR
            width: btInner.width + 16
            color: Services.Network.btEnabled ? Services.Colors.ghost
                                              : (btHover.containsMouse ? Services.Colors.ghostAlpha(0.4) : Services.Colors.ghostAlpha(0.2))
            Behavior on color { ColorAnimation { duration: 300 } }

            MouseArea {
                id: btHover
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                hoverEnabled: true
                onClicked: Services.AppState.bluetoothVisible = !Services.AppState.bluetoothVisible
            }

            Row {
                id: btInner
                anchors.centerIn: parent
                spacing: 5
                Text {
                    text: Services.Network.btEnabled ? "" : ""
                    color: (Services.Network.btEnabled || btHover.containsMouse) ? Services.Colors.abyss : Services.Colors.ash
                    font.pixelSize: 18
                    font.family: "Material Symbols Rounded"
                    anchors.verticalCenter: parent.verticalCenter
                    Behavior on color { ColorAnimation { duration: 200 } }
                }
                Text {
                    text: Services.Network.btDevice !== "" ? Services.Network.btDevice : (Services.Network.btEnabled ? "On" : "Off")
                    color: (Services.Network.btEnabled || btHover.containsMouse) ? Services.Colors.abyss : Services.Colors.ash
                    font.pixelSize: 12
                    font.family: "JetBrainsMono NF"
                    font.bold: true
                    anchors.verticalCenter: parent.verticalCenter
                    Behavior on color { ColorAnimation { duration: 200 } }
                }
            }
        }

        // Volume
        Rectangle {
            height: root.innerH
            radius: root.innerR
            width: volInner.width + 16
            color: (!Services.Audio.muted && Services.Audio.volume > 0) ? Services.Colors.ghost
                                                                        : (volHover.containsMouse ? Services.Colors.ghostAlpha(0.4) : Services.Colors.ghostAlpha(0.2))
            Behavior on color { ColorAnimation { duration: 300 } }
            MouseArea {
                id: volHover
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                hoverEnabled: true
                onClicked: Services.AppState.volumeVisible = !Services.AppState.volumeVisible
            }
            Timer {
                interval: 400; running: true; repeat: true; triggeredOnStart: true
                onTriggered: {
                    let g = parent.mapToGlobal(0, 0)
                    Services.AppState.volumePillCenterX = g.x + parent.width / 2
                }
            }
            Row {
                id: volInner
                anchors.centerIn: parent
                spacing: 5
                Text {
                    id: volIcon
                    text: Services.Audio.icon(Services.Audio.volume, Services.Audio.muted, Services.Audio.headphones)
                    color: (!Services.Audio.muted && Services.Audio.volume > 0 || volHover.containsMouse) ? Services.Colors.abyss : Services.Colors.ash
                    font.pixelSize: 18
                    font.family: "Material Symbols Rounded"
                    anchors.verticalCenter: parent.verticalCenter
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
                    font.pixelSize: 12
                    font.family: "JetBrainsMono NF"
                    font.bold: true
                    anchors.verticalCenter: parent.verticalCenter
                    Behavior on color { ColorAnimation { duration: 200 } }
                }
            }
        }
        // Brightness
        Rectangle {
            height: root.innerH
            radius: root.innerR
            width: brightInner.width + 16
            color: Services.Brightness.level > 0 ? Services.Colors.ghost
                                                 : (brightHover.containsMouse ? Services.Colors.ghostAlpha(0.4) : Services.Colors.ghostAlpha(0.2))
            Behavior on color { ColorAnimation { duration: 300 } }
            MouseArea {
                id: brightHover
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                hoverEnabled: true
                onClicked: Services.AppState.brightnessVisible = !Services.AppState.brightnessVisible
            }
            Timer {
                interval: 400; running: true; repeat: true; triggeredOnStart: true
                onTriggered: {
                    let g = parent.mapToGlobal(0, 0)
                    Services.AppState.brightnessPillCenterX = g.x + parent.width / 2
                }
            }
            Row {
                id: brightInner
                anchors.centerIn: parent
                spacing: 5
                Text {
                    text: ""
                    color: (Services.Brightness.level > 0 || brightHover.containsMouse) ? Services.Colors.abyss : Services.Colors.ash
                    font.pixelSize: 18
                    font.family: "Material Symbols Rounded"
                    anchors.verticalCenter: parent.verticalCenter
                    Behavior on color { ColorAnimation { duration: 200 } }
                }
                Text {
                    text: Services.Brightness.level + "%"
                    color: (Services.Brightness.level > 0 || brightHover.containsMouse) ? Services.Colors.abyss : Services.Colors.ash
                    font.pixelSize: 12
                    font.family: "JetBrainsMono NF"
                    font.bold: true
                    anchors.verticalCenter: parent.verticalCenter
                    Behavior on color { ColorAnimation { duration: 200 } }
                }
            }
        }

        // Battery
        Rectangle {
            height: root.innerH
            radius: root.innerR
            width: batInner.width + 16
            color: Services.Battery.charging ? Services.Colors.ghost
                                             : (batHover.containsMouse ? Services.Colors.ghostAlpha(0.4) : Services.Colors.ghostAlpha(0.2))
            Behavior on color { ColorAnimation { duration: 300 } }
            MouseArea {
                id: batHover
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                hoverEnabled: true
                onClicked: Services.AppState.batteryVisible = !Services.AppState.batteryVisible
            }
            Timer {
                interval: 400; running: true; repeat: true; triggeredOnStart: true
                onTriggered: {
                    let g = parent.mapToGlobal(0, 0)
                    Services.AppState.batteryPillCenterX = g.x + parent.width / 2
                }
            }
            Row {
                id: batInner
                anchors.centerIn: parent
                spacing: 5
                Text {
                    text: Services.Battery.charging ? "" : Services.Battery.level >= 90 ? "" : Services.Battery.level >= 70 ? "" : Services.Battery.level >= 50 ? "" : Services.Battery.level >= 30 ? "" : Services.Battery.level >= 15 ? "" : ""
                    color: {
                        if (Services.Battery.charging || batHover.containsMouse) return Services.Colors.abyss
                        if (Services.Battery.level >= 20) return Services.Colors.snow
                        return Services.Colors.error_
                    }
                    font.pixelSize: 18
                    font.family: "Material Symbols Rounded"
                    anchors.verticalCenter: parent.verticalCenter
                    Behavior on color { ColorAnimation { duration: 300 } }
                }
                Text {
                    text: Services.Battery.level + "%"
                    color: {
                        if (Services.Battery.charging || batHover.containsMouse) return Services.Colors.abyss
                        if (Services.Battery.level >= 20) return Services.Colors.snow
                        return Services.Colors.error_
                    }
                    font.pixelSize: 12
                    font.family: "JetBrainsMono NF"
                    font.bold: true
                    anchors.verticalCenter: parent.verticalCenter
                    Behavior on color { ColorAnimation { duration: 300 } }
                }
            }
        }
    }
}
