import Quickshell
import QtQuick

import "root:/services" as Services

// A tool that lives on the bar instead of on the utility pill: process,
// settings, clipboard. One component for all of them -- what it is comes from
// the pill catalogue, and its panel grows out of it exactly as it would out of
// a chip on the utility pill.
Rectangle {
    id: root
    // Which pill in Pills.qml this is.
    property string pillKey: ""
    readonly property string flag: Services.Pills.opens(root.pillKey)

    visible: Services.Prefs.pillVisible(root.pillKey)
    readonly property bool active: Services.AppState.overlayOpen(root.flag)

    scale: Services.Sizes.hoverScale(hover.containsMouse, hover.pressed)
    Behavior on scale { NumberAnimation { duration: Services.Sizes.pillHoverMs; easing.type: Services.Sizes.easeOut } }

    width: Services.Sizes.pillH; height: Services.Sizes.pillH
    radius: Services.Sizes.pillR
    color: active ? Services.Colors.ghost : Services.Colors.surfacePill
    gradient: Services.Prefs.useGradients && active ? Services.Colors.accentGradient : null
    border.width: 0
    Behavior on color { ColorAnimation { duration: Services.Sizes.msStandard } }

    // Same reporter every bar pill uses, so the panel reads one set of
    // numbers whichever place its chip lives in.
    PillCenter { key: root.pillKey }
    // "" for the edge means "hang off the bar", wherever the bar is.
    Component.onCompleted: Services.AppState.setChipEdge(root.pillKey, "")

    Text {
        anchors.centerIn: parent
        text: Services.Pills.glyph(root.pillKey)
        color: root.active ? Services.Colors.onColor(Services.Colors.ghost)
             : hover.containsMouse ? Services.Colors.snow : Services.Colors.mist
        font.pixelSize: 20
        font.family: "Material Symbols Rounded"
        Behavior on color { ColorAnimation { duration: Services.Sizes.msStandard } }
    }

    MouseArea {
        id: hover
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        hoverEnabled: true
        onClicked: {
            root.report()
            Services.AppState.toggleOverlay(root.flag)
        }
    }
}
