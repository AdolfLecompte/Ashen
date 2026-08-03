import QtQuick

import "root:/services" as Services

Rectangle {
    id: root
    // Hidden from Settings > Bar > Pills
    visible: Services.Prefs.pillVisible("launcher")
    // The bar's one hover language, from Sizes: grow under the pointer, give
    // a little under the click.
    scale: Services.Sizes.hoverScale(hover.containsMouse, hover.pressed)
    Behavior on scale { NumberAnimation { duration: Services.Sizes.pillHoverMs; easing.type: Services.Sizes.easeOut } }
    readonly property int pillH: Services.Sizes.pillH
    readonly property bool active: Services.AppState.launcherVisible

    width: pillH; height: pillH
    radius: Services.Sizes.pillR
    // Fills with the accent while open, the same inversion every other toggle
    // pill uses (see NotificationPill / RecordingPill). No hover tint: the
    // plate is the pill itself, and it answers the pointer by growing.
    color: active ? Services.Colors.ghost
                  : Services.Colors.surfacePill
    gradient: Services.Prefs.useGradients && (active) ? Services.Colors.accentGradient : null
    border.width: 0
    Behavior on color { ColorAnimation { duration: Services.Sizes.msStandard } }

    Text {
        anchors.centerIn: parent
        text: "\uE9B0"
        // Dark only on the accent fill. The hover plate is a surface tone, so
        // the glyph lifts to snow on it the same way it does at rest.
        color: root.active ? Services.Colors.onColor(Services.Colors.ghost)
             : hover.containsMouse ? Services.Colors.snow : Services.Colors.ghost
        font.pixelSize: 22
        font.family: "Material Symbols Rounded"
        Behavior on color { ColorAnimation { duration: Services.Sizes.msStandard } }
    }

    MouseArea {
        id: hover
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        hoverEnabled: true
        onClicked: Services.AppState.launcherVisible = !Services.AppState.launcherVisible
    }
}
