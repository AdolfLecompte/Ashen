import QtQuick

import "root:/services" as Services

Rectangle {
    id: root
    readonly property int pillH: 44

    width: pillH; height: pillH
    radius: 10
    color: Services.Colors.surfaceAlpha(0.82)
    border.color: Services.Colors.ghostAlpha(0.2)
    border.width: 1

    Text {
        anchors.centerIn: parent
        text: "\uE9B0"
        color: Services.AppState.launcherVisible ? Services.Colors.snow : Services.Colors.ghost
        font.pixelSize: 22
        font.family: "Material Symbols Rounded"
        Behavior on color { ColorAnimation { duration: 200 } }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: Services.AppState.launcherVisible = !Services.AppState.launcherVisible
    }
}
