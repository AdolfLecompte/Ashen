import QtQuick
import "root:/services" as Services

// Small round -/+ stepper button, used by the night-light temp and time rows.
Rectangle {
    id: sb
    property string glyph
    signal clicked()
    width: 28; height: 28; radius: 8
    color: sbHover.containsMouse ? Services.Colors.ghostAlpha(0.25) : Services.Colors.ghostAlpha(0.12)
    Behavior on color { ColorAnimation { duration: 120 } }
    Text {
        anchors.centerIn: parent
        text: sb.glyph
        font.family: "Material Symbols Rounded"
        font.pixelSize: 18
        color: Services.Colors.snow
    }
    MouseArea {
        id: sbHover
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: sb.clicked()
    }
}
