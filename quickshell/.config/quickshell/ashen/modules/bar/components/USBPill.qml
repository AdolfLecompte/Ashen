import Quickshell
import QtQuick
import QtQuick.Layouts

import "root:/services" as Services

Rectangle {
    id: root
    // Subtle hover grow
    scale: hover.containsMouse ? 1.05 : 1.0
    Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
    readonly property bool anyMounted: {
        for (let d of Services.USB.devices) {
            if (d.mountpoint && d.mountpoint.length > 0) return true
        }
        return false
    }

    readonly property bool vertical: Services.Sizes.barVertical
    readonly property bool present: Services.USB.devices.length > 0

    // Collapses along the bar's own axis: width on a horizontal bar, height on
    // a vertical one, where the pill is icon-only anyway.
    height: root.vertical ? (root.present ? Services.Sizes.pillH : 0) : Services.Sizes.pillH
    radius: Services.Sizes.pillR
    color: root.anyMounted ? Services.Colors.ghost
                           : (hover.containsMouse ? Services.Colors.ghostAlpha(0.3)
                                                  : Services.Colors.surfaceAlpha(0.82))
    gradient: Services.Prefs.useGradients && (root.anyMounted) ? Services.Colors.accentGradient : null
    border.width: 0
    width: root.vertical ? Services.Sizes.pillH : (root.present ? icon.implicitWidth + 24 : 0)
    opacity: root.present ? 1.0 : 0.0
    // Hidden from Settings > Bar > Pills
    visible: Services.Prefs.pillVisible("usb") && (opacity > 0)
    clip: true
    Behavior on color { ColorAnimation { duration: 300 } }
    Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
    Behavior on height { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
    Behavior on opacity { NumberAnimation { duration: 150 } }

    Text {
        id: icon
        anchors.centerIn: parent
        text: "\ue1e0"
        color: (root.anyMounted || hover.containsMouse) ? Services.Colors.abyss : Services.Colors.mist
        font.pixelSize: 22
        font.family: "Material Symbols Rounded"
        Behavior on color { ColorAnimation { duration: 300 } }
    }

    PillCenter { key: "usb" }

    MouseArea {
        id: hover
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        hoverEnabled: true
        onClicked: Services.AppState.usbVisible = !Services.AppState.usbVisible
    }
}
