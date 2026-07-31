import Quickshell
import QtQuick
import QtQuick.Layouts

import "root:/services" as Services

Rectangle {
    id: root
    // The bar's one hover language, from Sizes: grow under the pointer,
    // give a little under the click.
    scale: Services.Sizes.hoverScale(hover.containsMouse, hover.pressed)
    Behavior on scale { NumberAnimation { duration: Services.Sizes.pillHoverMs; easing.type: Easing.OutCubic } }
    readonly property bool anyMounted: {
        for (let d of Services.USB.devices) {
            if (d.mountpoint && d.mountpoint.length > 0) return true
        }
        return false
    }

    // While its panel is up the pill IS the panel: it steps aside so the drop
    // that grew out of its rect reads as the pill falling open. Same relay the
    // system chips use; without it the panel just appeared next to a pill that
    // was still sitting there.
    property bool takenOver: false
    readonly property bool panelOpen: Services.AppState.usbVisible
    onPanelOpenChanged: {
        if (panelOpen) { handBack.stop(); handOver.restart() }
        else { handOver.stop(); handBack.restart() }
    }
    // Both waits come from Sizes, the same ones the drop itself uses: standing
    // down before the panel's window is on screen left the bar blank with
    // nothing moving anywhere yet.
    Timer {
        id: handOver
        interval: Services.Sizes.panelArmMs
        onTriggered: root.takenOver = true
    }
    Timer {
        id: handBack
        interval: Services.Sizes.panelCloseMs - 40
        onTriggered: root.takenOver = false
    }

    readonly property bool vertical: Services.Sizes.barVertical
    readonly property bool present: Services.USB.devices.length > 0

    // Collapses along the bar's own axis: width on a horizontal bar, height on
    // a vertical one, where the pill is icon-only anyway.
    height: root.vertical ? (root.present ? Services.Sizes.pillH : 0) : Services.Sizes.pillH
    radius: Services.Sizes.pillR
    color: root.anyMounted ? Services.Colors.ghost
                           : Services.Colors.surfacePill
    gradient: Services.Prefs.useGradients && (root.anyMounted) ? Services.Colors.accentGradient : null
    border.width: 0
    width: root.vertical ? Services.Sizes.pillH : (root.present ? icon.implicitWidth + 24 : 0)
    opacity: root.takenOver ? 0.0 : (root.present ? 1.0 : 0.0)
    // Hidden from Settings > Bar > Pills. `visible` keys on the device being
    // there, not on opacity: while the pill is handed over to its panel it is
    // transparent but must keep its slot, or the strip closes the gap and the
    // pills either side jump.
    visible: Services.Prefs.pillVisible("usb")
        && (root.present || root.takenOver || opacity > 0)
    clip: true
    Behavior on color { ColorAnimation { duration: 300 } }
    Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
    Behavior on height { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
    Behavior on opacity { NumberAnimation { duration: 150 } }

    Text {
        id: icon
        anchors.centerIn: parent
        text: "\ue1e0"
        // `abyss` only when the plate is actually solid. On hover the fill is a
        // wash you can see the wallpaper through, and a dark glyph on it came
        // out as a smudge -- the same fault Launcher, Power and Notification
        // were fixed for; this one was missed.
        color: root.anyMounted ? Services.Colors.onColor(Services.Colors.ghost)
             : hover.containsMouse ? Services.Colors.snow
                                   : Services.Colors.mist
        font.pixelSize: 22
        font.family: "Material Symbols Rounded"
        Behavior on color { ColorAnimation { duration: 300 } }
    }

    PillCenter { key: "usb" }

    // The panel falls out of this pill wearing its glyph, so the pill has to
    // say what it is showing. Icon only: the pill has no words to hand over.
    Component.onCompleted: Services.AppState.setPillFace("usb", icon.text, "")

    MouseArea {
        id: hover
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        hoverEnabled: true
        onClicked: Services.AppState.usbVisible = !Services.AppState.usbVisible
    }
}
