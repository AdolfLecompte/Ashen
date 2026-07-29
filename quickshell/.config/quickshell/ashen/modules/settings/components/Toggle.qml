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
    Behavior on color { ColorAnimation { duration: 200 } }
    Rectangle {
        width: 20; height: 20; radius: 10
        color: Services.Colors.snow
        anchors.verticalCenter: parent.verticalCenter
        x: sw.checked ? parent.width - width - 4 : 4
        Behavior on x { NumberAnimation { duration: 200 } }
    }
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: sw.toggled()
    }
}
