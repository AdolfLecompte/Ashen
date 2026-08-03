import Quickshell
import QtQuick

import "root:/services" as Services

Rectangle {
    id: root
    // Hidden from Settings > Bar > Pills
    visible: Services.Prefs.pillVisible("power")
    // The bar's one hover language, from Sizes: grow under the pointer, give
    // a little under the click.
    scale: Services.Sizes.hoverScale(hover.containsMouse, hover.pressed)
    Behavior on scale { NumberAnimation { duration: Services.Sizes.pillHoverMs; easing.type: Services.Sizes.easeOut } }
    readonly property bool active: Services.AppState.powerMenuVisible

    PillCenter { key: "power" }

    width: Services.Sizes.pillH; height: Services.Sizes.pillH
    radius: Services.Sizes.pillR
    // Declarative fill (no imperative color assignment, which would clobber the
    // binding). Fills accent while the power menu is open; the plate does not
    // react to hover -- a top-level pill answers by growing, not by lighting.
    color: active ? Services.Colors.ghost
                  : Services.Colors.surfacePill
    gradient: Services.Prefs.useGradients && (active) ? Services.Colors.accentGradient : null
    border.width: 0
    Behavior on color { ColorAnimation { duration: Services.Sizes.msStandard } }

    Text {
        anchors.centerIn: parent
        text: ""
        // Dark only on the accent fill. The hover plate is a surface tone, so
        // the glyph lifts to snow on it the same way it does at rest.
        color: root.active ? Services.Colors.accentText
             : hover.containsMouse ? Services.Colors.snow : Services.Colors.mist
        font.pixelSize: 22
        font.family: "Material Symbols Rounded"
        Behavior on color { ColorAnimation { duration: Services.Sizes.msStandard } }
    }

    MouseArea {
        id: hover
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        hoverEnabled: true
        onClicked: Services.AppState.powerMenuVisible = !Services.AppState.powerMenuVisible
    }
}
