import QtQuick

import "root:/services" as Services

Rectangle {
    id: root
    readonly property int pillH: 44
    readonly property bool open: Services.AppState.notificationsVisible

    width: pillH; height: pillH
    radius: 10
    color: Services.Colors.surfaceAlpha(0.82)
    border.color: Services.Colors.ghostAlpha(0.2)
    border.width: 1

    Rectangle {
        anchors.centerIn: parent
        width: 32; height: 32
        radius: 8
        color: root.open ? Services.Colors.ghost : Services.Colors.ghostAlpha(0.2)
        Behavior on color { ColorAnimation { duration: 300 } }

        Text {
            anchors.centerIn: parent
            text: "\uE7F4"
            color: root.open ? Services.Colors.abyss : Services.Colors.mist
            font.pixelSize: 18
            font.family: "Material Symbols Rounded"
            Behavior on color { ColorAnimation { duration: 200 } }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: Services.AppState.notificationsVisible = !Services.AppState.notificationsVisible
    }
}
