import QtQuick
import "root:/services" as Services

// On/off switch. Reports the tap and leaves the flip to the caller, so the
// state always lives in the service that owns it.
Rectangle {
    id: sw
    property bool checked: false
    signal toggled()
    width: 52; height: 28; radius: 14
    color: checked ? Services.Colors.ghost : Services.Colors.ghostAlpha(0.25)
    gradient: Services.Prefs.useGradients && checked ? Services.Colors.accentGradient : null
    Behavior on color { ColorAnimation { duration: Services.Sizes.msStandard } }
    Rectangle {
        width: 20; height: 20; radius: 10
        // Reads whichever background it is standing on: the accent when the
        // switch is on, the panel behind the track when it is off. A fixed
        // tone disappeared into the accent on a light palette.
        color: sw.checked ? Services.Colors.accentBody : Services.Colors.surfaceBody
        Behavior on color { ColorAnimation { duration: Services.Sizes.msStandard } }
        anchors.verticalCenter: parent.verticalCenter
        x: sw.checked ? parent.width - width - 4 : 4
        Behavior on x { NumberAnimation { duration: Services.Sizes.msStandard } }
    }
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: sw.toggled()
    }
}
