import QtQuick

import "root:/services" as Services

Rectangle {
    id: root
    property bool capsActive: Services.Notifications.lastCapsLock
    property bool numActive: Services.Notifications.lastNumLock
    property bool anyActive: capsActive || numActive

    height: 44
    radius: 10
    // Whole containment pill fills with the accent when a lock is on, the same
    // inversion every other active pill uses (see RecordingPill). No inner pills.
    color: Services.Colors.ghost
    border.width: 0
    width: anyActive ? (locksRow.width + 20) : 0
    opacity: anyActive ? 1.0 : 0.0
    clip: true
    Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
    Behavior on opacity { NumberAnimation { duration: 150 } }

    Row {
        id: locksRow
        anchors.centerIn: parent
        spacing: 10

        // Caps Lock (only present while active)
        Text {
            visible: root.capsActive
            text: "\ue318"
            color: Services.Colors.abyss
            font.pixelSize: 24
            font.bold: true
            font.family: "Material Symbols Rounded"
            anchors.verticalCenter: parent.verticalCenter
        }
        // Num Lock (only present while active)
        Text {
            visible: root.numActive
            text: "\uf2af"
            color: Services.Colors.abyss
            font.pixelSize: 24
            font.bold: true
            font.family: "Material Symbols Rounded"
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}
