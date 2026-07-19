import QtQuick

import "root:/services" as Services

Rectangle {
    id: root
    property bool capsActive: Services.Notifications.lastCapsLock
    property bool numActive: Services.Notifications.lastNumLock
    property bool anyActive: capsActive || numActive

    height: 44
    radius: 10
    // Solid-accent containment pill with dark glyphs, so the locks read clearly.
    // Glyphs sit at a middle size: big enough to fill the pill squarely, not the
    // oversized 24px that dominated the bar.
    color: Services.Colors.ghost
    border.width: 0
    width: anyActive ? (locksRow.width + 18) : 0
    opacity: anyActive ? 1.0 : 0.0
    clip: true
    Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
    Behavior on opacity { NumberAnimation { duration: 150 } }

    Row {
        id: locksRow
        anchors.centerIn: parent
        spacing: 8

        // Caps Lock (only present while active)
        Text {
            visible: root.capsActive
            text: "\ue318"                 // keyboard_capslock
            color: Services.Colors.abyss
            font.pixelSize: 20
            font.bold: true
            font.family: "Material Symbols Rounded"
            anchors.verticalCenter: parent.verticalCenter
        }
        // Num Lock (only present while active)
        Text {
            visible: root.numActive
            text: "\ue400"                 // looks_one
            color: Services.Colors.abyss
            font.pixelSize: 20
            font.bold: true
            font.family: "Material Symbols Rounded"
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}
