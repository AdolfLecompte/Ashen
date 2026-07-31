import QtQuick

import "root:/services" as Services

Rectangle {
    id: root
    // Hidden from Settings > Bar > Pills
    visible: Services.Prefs.pillVisible("notifications")
    // The bar's one hover language, from Sizes: grow under the pointer, give
    // a little under the click.
    scale: Services.Sizes.hoverScale(hover.containsMouse, hover.pressed)
    Behavior on scale { NumberAnimation { duration: Services.Sizes.pillHoverMs; easing.type: Easing.OutCubic } }
    readonly property int pillH: Services.Sizes.pillH
    readonly property bool open: Services.AppState.notificationsVisible
    readonly property bool dnd: Services.AppState.doNotDisturb

    width: pillH; height: pillH
    radius: Services.Sizes.pillR
    // Whole containment pill fills with the accent while the panel is open, the
    // same inversion every other active pill uses (see RecordingPill /
    // LocksPill). No inner box, and no hover tint on the plate.
    color: open ? Services.Colors.ghost
                : Services.Colors.surfacePill
    gradient: Services.Prefs.useGradients && (open) ? Services.Colors.accentGradient : null
    border.width: 0
    Behavior on color { ColorAnimation { duration: 300 } }

    PillCenter { key: "notification" }

    Text {
        id: bell
        anchors.centerIn: parent
        // Bell while normal, notifications_off glyph while Do Not Disturb.
        text: root.dnd ? "\uE7F6" : "\uE7F4"
        // Dark only on the accent fill. The hover plate is a surface tone, so
        // the glyph lifts to snow on it the same way it does at rest.
        color: root.open ? Services.Colors.onColor(Services.Colors.ghost)
             : hover.containsMouse ? Services.Colors.snow : Services.Colors.mist
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

    // How many landed since the rail was last closed. Hidden while the rail is
    // open: the list itself is the answer, and the count is about to be zero.
    Rectangle {
        id: badge
        readonly property int count: Services.Notifications.unreadCount
        visible: count > 0 && !root.open
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.rightMargin: 3
        anchors.topMargin: 3
        width: Math.max(14, badgeTxt.implicitWidth + 8)
        height: 14
        radius: 7
        color: Services.Colors.ghost
        gradient: Services.Prefs.useGradients ? Services.Colors.accentGradient : null

        Text {
            id: badgeTxt
            anchors.centerIn: parent
            text: badge.count > 9 ? "9+" : badge.count
            // Never a fixed dark: with a light accent from matugen the digits
            // have to flip. See Colors.onColor.
            color: Services.Colors.onColor(Services.Colors.ghost)
            font.pixelSize: 9
            font.bold: true
            font.family: "JetBrainsMono NF"
        }

        // Pops in rather than blinking, and only when the count actually moves.
        scale: 1.0
        onCountChanged: if (badge.count > 0) badgePop.restart()
        NumberAnimation {
            id: badgePop
            target: badge; property: "scale"
            from: 0.6; to: 1.0; duration: 220; easing.type: Easing.OutQuint
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
