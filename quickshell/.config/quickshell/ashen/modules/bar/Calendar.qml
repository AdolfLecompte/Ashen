import Quickshell
import QtQuick
import QtQuick.Layouts

import "root:/services" as Services

PanelWindow {
    id: root

    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }

    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    visible: Services.AppState.calendarVisible

    property string currentTime: Qt.formatDateTime(new Date(), "hh:mm:ss AP")
    property string currentDate: Qt.formatDateTime(new Date(), "MMMM d, yyyy")
    property string currentDayName: Qt.locale().dayName(new Date().getDay())

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: {
            let now = new Date()
            root.currentTime = Qt.formatDateTime(now, "hh:mm:ss AP")
            root.currentDate = Qt.formatDateTime(now, "MMMM d, yyyy")
            root.currentDayName = Qt.locale().dayName(now.getDay())
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: Services.AppState.calendarVisible = false
    }

    Column {
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.topMargin: 64
        spacing: 8
        opacity: Services.AppState.calendarVisible ? 1.0 : 0.0
        scale: Services.AppState.calendarVisible ? 1.0 : 0.92
        Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

        // Caja superior — invertida
        Rectangle {
            width: 440
            height: 100
            radius: 14
            color: Services.Colors.ghostAlpha(0.75)
            MouseArea { anchors.fill: parent; onClicked: {} }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 24
                anchors.rightMargin: 24

                // Dia y fecha
                Column {
                    spacing: 4
                    Layout.fillWidth: true

                    Text {
                        text: root.currentDayName.toUpperCase()
                        color: Services.Colors.surfaceAlpha(0.7)
                        font.pixelSize: 11
                        font.family: "JetBrainsMono NF"
                        font.bold: true
                        font.letterSpacing: 2
                    }
                    Text {
                        text: root.currentDate
                        color: Services.Colors.abyss
                        font.pixelSize: 16
                        font.family: "JetBrainsMono NF"
                        font.bold: true
                    }
                }

                // Separador
                Rectangle {
                    width: 1; height: 50
                    color: Services.Colors.surfaceAlpha(0.3)
                }

                // Hora
                Column {
                    spacing: 2
                    Layout.alignment: Qt.AlignVCenter

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: root.currentTime.split(" ")[0]
                        color: Services.Colors.abyss
                        font.pixelSize: 22
                        font.family: "JetBrainsMono NF"
                        font.bold: true
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: root.currentTime.split(" ")[1]
                        color: Services.Colors.surfaceAlpha(0.7)
                        font.pixelSize: 11
                        font.family: "JetBrainsMono NF"
                        font.bold: true
                        font.letterSpacing: 1
                    }
                }
            }
        }

        // Caja calendario
        Rectangle {
            width: 440
            height: calCol.implicitHeight + 28
            radius: 14
            color: Services.Colors.surfaceAlpha(0.95)
            border.color: Services.Colors.ghostAlpha(0.2)
            border.width: 1
            MouseArea { anchors.fill: parent; onClicked: {} }

            Column {
                id: calCol
                anchors.centerIn: parent
                spacing: 8
                width: parent.width - 28

                RowLayout {
                    width: parent.width

                    Text {
                        Layout.fillWidth: true
                        text: Qt.locale().monthName(calRoot.currentMonth) + " " + calRoot.currentYear
                        color: Services.Colors.snow
                        font.pixelSize: 14
                        font.family: "JetBrainsMono NF"
                        font.bold: true
                    }

                    Rectangle {
                        width: 28; height: 28; radius: 8; color: "transparent"
                        Text {
                            anchors.centerIn: parent
                            text: "‹"
                            color: Services.Colors.ghost
                            font.pixelSize: 20
                            font.family: "JetBrainsMono NF"
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            hoverEnabled: true
                            onEntered: parent.color = Services.Colors.ghostAlpha(0.15)
                            onExited: parent.color = "transparent"
                            onClicked: {
                                if (calRoot.currentMonth === 0) { calRoot.currentMonth = 11; calRoot.currentYear-- }
                                else calRoot.currentMonth--
                            }
                        }
                    }

                    Rectangle {
                        width: 28; height: 28; radius: 8; color: "transparent"
                        Text {
                            anchors.centerIn: parent
                            text: ""
                            color: Services.Colors.ghost
                            font.pixelSize: 16
                            font.family: "Material Symbols Rounded"
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            hoverEnabled: true
                            onEntered: parent.color = Services.Colors.ghostAlpha(0.15)
                            onExited: parent.color = "transparent"
                            onClicked: {
                                calRoot.currentMonth = calRoot.todayMonth
                                calRoot.currentYear = calRoot.todayYear
                            }
                        }
                    }

                    Rectangle {
                        width: 28; height: 28; radius: 8; color: "transparent"
                        Text {
                            anchors.centerIn: parent
                            text: "›"
                            color: Services.Colors.ghost
                            font.pixelSize: 20
                            font.family: "JetBrainsMono NF"
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            hoverEnabled: true
                            onEntered: parent.color = Services.Colors.ghostAlpha(0.15)
                            onExited: parent.color = "transparent"
                            onClicked: {
                                if (calRoot.currentMonth === 11) { calRoot.currentMonth = 0; calRoot.currentYear++ }
                                else calRoot.currentMonth++
                            }
                        }
                    }
                }

                Row {
                    width: parent.width
                    Repeater {
                        model: ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]
                        Text {
                            width: calCol.width / 7
                            horizontalAlignment: Text.AlignHCenter
                            text: modelData
                            color: Services.Colors.ash
                            font.pixelSize: 11
                            font.family: "JetBrainsMono NF"
                        }
                    }
                }

                Grid {
                    id: calRoot
                    width: parent.width
                    columns: 7
                    spacing: 2

                    property int currentMonth: new Date().getMonth()
                    property int currentYear: new Date().getFullYear()
                    property int today: new Date().getDate()
                    property int todayMonth: new Date().getMonth()
                    property int todayYear: new Date().getFullYear()
                    property int firstDay: new Date(currentYear, currentMonth, 1).getDay()
                    property int daysInMonth: new Date(currentYear, currentMonth + 1, 0).getDate()

                    Repeater {
                        model: calRoot.firstDay + calRoot.daysInMonth
                        delegate: Rectangle {
                            required property int index
                            property int day: index - calRoot.firstDay + 1
                            property bool isValid: index >= calRoot.firstDay
                            property bool isToday: isValid && day === calRoot.today && calRoot.currentMonth === calRoot.todayMonth && calRoot.currentYear === calRoot.todayYear

                            width: calCol.width / 7 - 2
                            height: Math.min(width, 32)
                            radius: 6
                            color: isToday ? Services.Colors.ghost : "transparent"

                            Text {
                                anchors.centerIn: parent
                                text: parent.isValid ? parent.day : ""
                                color: parent.isToday ? Services.Colors.abyss : Services.Colors.snow
                                font.pixelSize: 12
                                font.family: "JetBrainsMono NF"
                                font.bold: parent.isToday
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                hoverEnabled: true
                                onEntered: if (!parent.isToday) parent.color = Services.Colors.ghostAlpha(0.15)
                                onExited: if (!parent.isToday) parent.color = "transparent"
                            }
                        }
                    }
                }
            }
        }

        // Caja del clima -- ahora mismo + pronostico, invertida como el reloj
        Rectangle {
            width: 440
            height: weatherCol.implicitHeight + 28
            radius: 14
            color: Services.Colors.ghostAlpha(0.75)
            MouseArea { anchors.fill: parent; onClicked: {} }

            Column {
                id: weatherCol
                anchors.centerIn: parent
                width: parent.width - 28
                spacing: 10

                // Clima ahora mismo
                Row {
                    spacing: 12
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Services.Weather.icon
                        color: Services.Colors.abyss
                        font.pixelSize: 40
                        font.family: "Material Symbols Rounded"
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Services.Weather.tempC + "°C"
                        color: Services.Colors.abyss
                        font.pixelSize: 30
                        font.bold: true
                        font.family: "JetBrainsMono NF"
                    }
                }

                Rectangle { width: parent.width; height: 1; color: Services.Colors.surfaceAlpha(0.25) }

                // Pronostico de los proximos dias
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 20

                    Repeater {
                        model: Services.Weather.forecast
                        delegate: Column {
                            required property var modelData
                            spacing: 2
                            width: 72

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: modelData.label
                                color: Services.Colors.surfaceAlpha(0.7)
                                font.pixelSize: 11
                                font.family: "JetBrainsMono NF"
                                font.bold: true
                                font.letterSpacing: 1
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: modelData.icon
                                color: Services.Colors.abyss
                                font.pixelSize: 30
                                font.family: "Material Symbols Rounded"
                            }
                            Row {
                                anchors.horizontalCenter: parent.horizontalCenter
                                spacing: 5
                                Text {
                                    text: modelData.maxC + "°"
                                    color: Services.Colors.abyss
                                    font.pixelSize: 12
                                    font.bold: true
                                    font.family: "JetBrainsMono NF"
                                }
                                Text {
                                    text: modelData.minC + "°"
                                    color: Services.Colors.surfaceAlpha(0.6)
                                    font.pixelSize: 12
                                    font.family: "JetBrainsMono NF"
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
