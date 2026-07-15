import QtQuick

import "root:/services" as Services

Rectangle {
    id: root
    readonly property int pillH: 44
    readonly property bool open: Services.AppState.notificationsVisible
    readonly property bool dnd: Services.AppState.doNotDisturb

    width: pillH; height: pillH
    radius: 10
    // Whole containment pill fills with the accent while the panel is open, the
    // same inversion every other active pill uses (see RecordingPill / LocksPill).
    // No inner box.
    color: open ? Services.Colors.ghost
                : (hover.containsMouse ? Services.Colors.ghostAlpha(0.3)
                                       : Services.Colors.surfaceAlpha(0.82))
    border.width: 0
    Behavior on color { ColorAnimation { duration: 300 } }

    Text {
        id: bell
        anchors.centerIn: parent
        // Bell while normal, notifications_off glyph while Do Not Disturb.
        text: root.dnd ? "\uE7F6" : "\uE7F4"
        color: (root.open || hover.containsMouse) ? Services.Colors.abyss : Services.Colors.mist
        font.pixelSize: 24
        font.family: "Material Symbols Rounded"
        Behavior on color { ColorAnimation { duration: 200 } }

        // Subtle fade + scale pop whenever the glyph swaps (bell <-> DND).
        transform: Scale {
            id: bellScale
            origin.x: bell.width / 2
            origin.y: bell.height / 2
        }
        onTextChanged: bellSwap.restart()
        ParallelAnimation {
            id: bellSwap
            NumberAnimation { target: bell; property: "opacity"; from: 0.0; to: 1.0; duration: 180; easing.type: Easing.OutCubic }
            NumberAnimation { target: bellScale; property: "xScale"; from: 0.7; to: 1.0; duration: 200; easing.type: Easing.OutCubic }
            NumberAnimation { target: bellScale; property: "yScale"; from: 0.7; to: 1.0; duration: 200; easing.type: Easing.OutCubic }
        }
    }

    MouseArea {
        id: hover
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        hoverEnabled: true
        onClicked: Services.AppState.notificationsVisible = !Services.AppState.notificationsVisible
    }
}
