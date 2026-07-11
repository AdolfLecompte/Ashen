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
    border.width: 1
    width: sysRow.width + 16

    Row {
        id: sysRow
        anchors.centerIn: parent
        spacing: 4

        // Caps Lock (solo visible si esta activo)
        Rectangle {
            visible: Services.Notifications.lastCapsLock
            width: visible ? root.innerH : 0
            height: root.innerH
            radius: root.innerR
            color: Services.Colors.ghost
            clip: true
            Behavior on width { NumberAnimation { duration: 200 } }
            Text {
                anchors.centerIn: parent
                text: "A"
                color: Services.Colors.abyss
                font.pixelSize: 14
                font.bold: true
                font.family: "JetBrainsMono NF"
            }
        }
        // Num Lock (solo visible si esta activo)
        Rectangle {
            visible: Services.Notifications.lastNumLock
            width: visible ? root.innerH : 0
            height: root.innerH
            radius: root.innerR
            color: Services.Colors.ghost
            clip: true
            Behavior on width { NumberAnimation { duration: 200 } }
            Text {
                anchors.centerIn: parent
                text: "1"
                color: Services.Colors.abyss
                font.pixelSize: 14
                font.bold: true
                font.family: "JetBrainsMono NF"
            }
        }
        // Notificaciones
        Rectangle {
            width: root.innerH; height: root.innerH
            radius: root.innerR
            color: Services.AppState.notificationsVisible ? Services.Colors.ghost : Services.Colors.ghostAlpha(0.2)
            Behavior on color { ColorAnimation { duration: 300 } }
            Text {
                anchors.centerIn: parent
                text: ""
                color: Services.AppState.notificationsVisible ? Services.Colors.abyss : Services.Colors.mist
                font.pixelSize: 18
                font.family: "Material Symbols Rounded"
                Behavior on color { ColorAnimation { duration: 200 } }
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: Services.AppState.notificationsVisible = !Services.AppState.notificationsVisible
            }
        }
        
        // Wifi
        Rectangle {
            height: root.innerH
            radius: root.innerR
            width: wifiInner.width + 16
            color: Services.Network.wifiSsid !== "" ? Services.Colors.ghost : Services.Colors.ghostAlpha(0.2)
            Behavior on color { ColorAnimation { duration: 300 } }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
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
                    text: Services.Network.wifiSsid !== "" ? "" : ""
                    color: Services.Network.wifiSsid !== "" ? Services.Colors.abyss : Services.Colors.ash
                    font.pixelSize: 18
                    font.family: "Material Symbols Rounded"
                    anchors.verticalCenter: parent.verticalCenter
                    Behavior on color { ColorAnimation { duration: 200 } }
                }
                Text {
                    text: Services.Network.wifiSsid !== "" ? Services.Network.wifiSsid : "Off"
                    color: Services.Network.wifiSsid !== "" ? Services.Colors.abyss : Services.Colors.ash
                    font.pixelSize: 12
                    font.family: "JetBrainsMono NF"
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
            color: Services.Network.btEnabled ? Services.Colors.ghost : Services.Colors.ghostAlpha(0.2)
            Behavior on color { ColorAnimation { duration: 300 } }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: Services.AppState.bluetoothVisible = !Services.AppState.bluetoothVisible
            }

            Row {
                id: btInner
                anchors.centerIn: parent
                spacing: 5
                Text {
                    text: Services.Network.btEnabled ? "" : ""
                    color: Services.Network.btEnabled ? Services.Colors.abyss : Services.Colors.ash
                    font.pixelSize: 18
                    font.family: "Material Symbols Rounded"
                    anchors.verticalCenter: parent.verticalCenter
                    Behavior on color { ColorAnimation { duration: 200 } }
                }
                Text {
                    text: Services.Network.btDevice !== "" ? Services.Network.btDevice : (Services.Network.btEnabled ? "On" : "Off")
                    color: Services.Network.btEnabled ? Services.Colors.abyss : Services.Colors.ash
                    font.pixelSize: 12
                    font.family: "JetBrainsMono NF"
                    anchors.verticalCenter: parent.verticalCenter
                    Behavior on color { ColorAnimation { duration: 200 } }
                }
            }
        }

        // Volumen
        Rectangle {
            height: root.innerH
            radius: root.innerR
            width: volInner.width + 16
            color: Services.Audio.volume > 0 ? Services.Colors.ghost : Services.Colors.ghostAlpha(0.2)
            Behavior on color { ColorAnimation { duration: 300 } }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
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
                    text: Services.Audio.volume === 0 ? "" : Services.Audio.volume < 66 ? "" : ""
                    color: Services.Audio.volume > 0 ? Services.Colors.abyss : Services.Colors.ash
                    font.pixelSize: 18
                    font.family: "Material Symbols Rounded"
                    anchors.verticalCenter: parent.verticalCenter
                    Behavior on color { ColorAnimation { duration: 200 } }
                }
                Text {
                    text: Services.Audio.volume + "%"
                    color: Services.Audio.volume > 0 ? Services.Colors.abyss : Services.Colors.ash
                    font.pixelSize: 12
                    font.family: "JetBrainsMono NF"
                    anchors.verticalCenter: parent.verticalCenter
                    Behavior on color { ColorAnimation { duration: 200 } }
                }
            }
        }
        // Brillo
        Rectangle {
            height: root.innerH
            radius: root.innerR
            width: brightInner.width + 16
            color: Services.Brightness.level > 0 ? Services.Colors.ghost : Services.Colors.ghostAlpha(0.2)
            Behavior on color { ColorAnimation { duration: 300 } }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
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
                    color: Services.Brightness.level > 0 ? Services.Colors.abyss : Services.Colors.ash
                    font.pixelSize: 18
                    font.family: "Material Symbols Rounded"
                    anchors.verticalCenter: parent.verticalCenter
                    Behavior on color { ColorAnimation { duration: 200 } }
                }
                Text {
                    text: Services.Brightness.level + "%"
                    color: Services.Brightness.level > 0 ? Services.Colors.abyss : Services.Colors.ash
                    font.pixelSize: 12
                    font.family: "JetBrainsMono NF"
                    anchors.verticalCenter: parent.verticalCenter
                    Behavior on color { ColorAnimation { duration: 200 } }
                }
            }
        }

        // Bateria
        Rectangle {
            height: root.innerH
            radius: root.innerR
            width: batInner.width + 16
            color: Services.Battery.charging ? Services.Colors.ghost : Services.Colors.ghostAlpha(0.2)
            Behavior on color { ColorAnimation { duration: 300 } }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
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
                        if (Services.Battery.charging) return Services.Colors.abyss
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
                        if (Services.Battery.charging) return Services.Colors.abyss
                        if (Services.Battery.level >= 20) return Services.Colors.snow
                        return Services.Colors.error_
                    }
                    font.pixelSize: 12
                    font.family: "JetBrainsMono NF"
                    anchors.verticalCenter: parent.verticalCenter
                    Behavior on color { ColorAnimation { duration: 300 } }
                }
            }
        }
    }
}
