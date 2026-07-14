import QtQuick
import QtQuick.Layouts

import "root:/services" as Services

Rectangle {
    id: root
    readonly property int innerR: 8
    readonly property int innerH: 32
    property bool anyActive: Services.Notifications.lastCapsLock || Services.Notifications.lastNumLock

    height: 44
    radius: 10
    color: Services.Colors.surfaceAlpha(0.82)
    border.color: Services.Colors.ghostAlpha(0.2)
    border.width: 1
    width: anyActive ? (locksRow.width + 16) : 0
    opacity: anyActive ? 1.0 : 0.0
    clip: true
    Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
    Behavior on opacity { NumberAnimation { duration: 150 } }

    Row {
        id: locksRow
        anchors.centerIn: parent
        spacing: 4

        // Caps Lock (only visible while active)
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
                text: "\ue318"
                color: Services.Colors.abyss
                font.pixelSize: 18
                font.bold: true
                font.family: "Material Symbols Rounded"
            }
        }
        // Num Lock (only visible while active)
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
                text: "\ue400"
                color: Services.Colors.abyss
                font.pixelSize: 18
                font.bold: true
                font.family: "Material Symbols Rounded"
            }
        }
    }
}
