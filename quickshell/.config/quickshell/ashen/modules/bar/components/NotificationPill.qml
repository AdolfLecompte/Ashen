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
    // same inversion every other active pill uses (see RecordingPill / LocksPill).
    // No inner box.
    color: open ? Services.Colors.ghost
                : (hover.containsMouse ? Services.Colors.ghostAlpha(0.45)
                                       : Services.Colors.surfaceAlpha(0.82))
    gradient: Services.Prefs.useGradients && (open) ? Services.Colors.accentGradient : null
    border.width: 0
    Behavior on color { ColorAnimation { duration: 300 } }

    PillCenter { key: "notification" }

    Text {
        id: bell
        anchors.centerIn: parent
        // Bell while normal, notifications_off glyph while Do Not Disturb.
        text: root.dnd ? "\uE7F6" : "\uE7F4"
        // Dark only on the solid accent fill; over the hover tint it lifts to
        // snow instead — abyss on a 45 % wash was a smudge, not a glyph.
        color: root.open ? Services.Colors.abyss
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

    MouseArea {
        id: hover
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        hoverEnabled: true
        onClicked: Services.AppState.notificationsVisible = !Services.AppState.notificationsVisible
    }
}
