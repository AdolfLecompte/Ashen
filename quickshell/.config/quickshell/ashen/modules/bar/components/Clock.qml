import QtQuick
import QtQuick.Layouts

import "root:/services" as Services

Rectangle {
    id: root
    property string currentTime: ""
    property string currentDate: ""
    property string timeIcon: ""

    height: 44
    width: clockRow.implicitWidth + 40
    radius: 10
    color: Services.Colors.surfaceAlpha(0.82)
    border.color: Services.Colors.ghostAlpha(0.2)
    border.width: 0

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: Services.AppState.calendarVisible = !Services.AppState.calendarVisible
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: {
            let now = new Date()
            let h = now.getHours()
            root.currentTime = Qt.formatDateTime(now, Services.Prefs.timeFormat)
            root.currentDate = Qt.formatDateTime(now, "ddd, MMM d")
            if (h >= 0 && h < 5)        root.timeIcon = ""
            else if (h >= 5 && h < 8)   root.timeIcon = ""
            else if (h >= 8 && h < 17)  root.timeIcon = ""
            else if (h >= 17 && h < 20) root.timeIcon = ""
            else                         root.timeIcon = ""
        }
    }

    RowLayout {
        id: clockRow
        anchors.centerIn: parent
        spacing: 16

        Column {
            spacing: 1
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.currentTime
                color: Services.Colors.snow
                font.pixelSize: 15
                font.family: "JetBrainsMono NF"
                font.bold: true
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.currentDate
                color: Services.Colors.mist
                font.pixelSize: 10
                font.family: "JetBrainsMono NF"
                font.bold: true
            }
        }

        Row {
            spacing: 4
            Layout.alignment: Qt.AlignVCenter
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Services.Weather.icon
                font.pixelSize: 22
                font.family: "Material Symbols Rounded"
                color: Services.Colors.neutral
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Services.Weather.temp
                font.pixelSize: 13
                font.family: "JetBrainsMono NF"
                font.bold: true
                color: Services.Colors.mist
            }
        }
    }
}
