import QtQuick

import "root:/services" as Services

Rectangle {
    id: root
    // Hidden from Settings > Bar > Pills
    visible: Services.Prefs.pillVisible("launcher")
    // The bar's one hover language, from Sizes: grow under the pointer, give
    // a little under the click.
    scale: Services.Sizes.hoverScale(hover.containsMouse, hover.pressed)
    Behavior on scale { NumberAnimation { duration: Services.Sizes.pillHoverMs; easing.type: Easing.OutCubic } }
    readonly property int pillH: Services.Sizes.pillH
    readonly property bool active: Services.AppState.launcherVisible

    width: pillH; height: pillH
    radius: Services.Sizes.pillR
    // Fills with the accent while open, ghost tint on hover, the same inversion
    // every other toggle pill uses (see NotificationPill / RecordingPill).
    color: active ? Services.Colors.ghost
                  : (hover.containsMouse ? Services.Colors.ghostAlpha(0.45)
                                         : Services.Colors.surfaceAlpha(0.82))
    gradient: Services.Prefs.useGradients && (active) ? Services.Colors.accentGradient : null
    border.width: 0
    Behavior on color { ColorAnimation { duration: 200 } }

    Text {
        anchors.centerIn: parent
        text: "\uE9B0"
        // Dark only on the solid accent fill; over the hover tint it lifts to
        // snow instead — abyss on a 45 % wash was a smudge, not a glyph.
        color: root.active ? Services.Colors.abyss
             : hover.containsMouse ? Services.Colors.snow : Services.Colors.ghost
        font.pixelSize: 22
        font.family: "Material Symbols Rounded"
        Behavior on color { ColorAnimation { duration: 200 } }
    }

    MouseArea {
        id: hover
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        hoverEnabled: true
        onClicked: Services.AppState.launcherVisible = !Services.AppState.launcherVisible
    }
}
