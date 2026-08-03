import QtQuick
import QtQuick.Layouts

import "root:/services" as Services

Rectangle {
    id: root
    // Hidden from Settings > Bar > Pills
    visible: Services.Prefs.pillVisible("clock")
    property string currentTime: ""
    property string currentDate: ""
    property string timeIcon: ""
    // A side bar is one pill wide: the clock stacks hours over minutes there and
    // drops the date and the weather chip.
    readonly property bool vertical: Services.Sizes.barVertical
    property string vertHour: ""
    property string vertMinute: ""
    property string vertSuffix: ""
    property string vertSecond: ""

    height: root.vertical ? vertCol.implicitHeight + 16 : Services.Sizes.pillH
    width: root.vertical ? Services.Sizes.pillH : clockRow.implicitWidth + 40
    radius: Services.Sizes.pillR
    color: Services.Colors.surfacePill
    border.color: Services.Colors.fillRest
    border.width: 0

    MouseArea {
        id: pillHover
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: Services.AppState.calendarVisible = !Services.AppState.calendarVisible
    }

    // No hover grow here: the clock is the widest thing on the bar and it sits
    // dead centre, so swelling it under a passing pointer nudged the whole
    // strip. The press is kept — that half is feedback for something you did.
    scale: pillHover.pressed ? Services.Sizes.pillPressScale : 1.0
    Behavior on scale { NumberAnimation { duration: Services.Sizes.pillHoverMs; easing.type: Services.Sizes.easeOut } }

    // Reports where it sits so the calendar can drop out of it
    PillCenter { key: "clock" }

    // …and its size, so the panel knows the rect it has to grow out of
    Binding { target: Services.AppState; property: "clockPillW"; value: root.width }
    Binding { target: Services.AppState; property: "clockPillH"; value: root.height }

    // The panel is a morphed copy of this pill, so while it is open the pill
    // steps aside: the card standing on its rect *is* the pill now. Fading
    // opacity rather than flipping `visible` — invisible still holds its slot
    // in the bar, hidden would let the row close the gap and shift.
    property bool takenOverByPanel: false
    Connections {
        target: Services.AppState
        // clockMorphing, not calendarVisible: the pill must stay on screen
        // until the panel's surface is up and the morph starts drawing
        function onClockMorphingChanged() {
            if (Services.AppState.clockMorphing) {
                handBack.stop()
                root.takenOverByPanel = true
            } else {
                handBack.restart()
            }
        }
    }
    // The card is back on the pill's rect at ~500 ms; fade in just under that
    Timer { id: handBack; interval: 470; onTriggered: root.takenOverByPanel = false }

    opacity: root.takenOverByPanel ? 0.0 : 1.0
    Behavior on opacity { NumberAnimation { duration: Services.Sizes.msMicro } }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: {
            let now = new Date()
            let h = now.getHours()
            root.currentTime = Qt.formatDateTime(now, Services.Prefs.timeFormat)
            root.currentDate = Qt.formatDateTime(now, "ddd, MMM d")
            root.vertHour = Qt.formatDateTime(now, Services.Prefs.hourToken)
            root.vertMinute = Qt.formatDateTime(now, "mm")
            root.vertSecond = Services.Prefs.clockSeconds ? Qt.formatDateTime(now, "ss") : ""
            root.vertSuffix = Services.Prefs.clock24h ? "" : Qt.formatDateTime(now, "AP")
            if (h >= 0 && h < 5)        root.timeIcon = ""
            else if (h >= 5 && h < 8)   root.timeIcon = ""
            else if (h >= 8 && h < 17)  root.timeIcon = ""
            else if (h >= 17 && h < 20) root.timeIcon = ""
            else                         root.timeIcon = ""
        }
    }

    Column {
        id: vertCol
        visible: root.vertical
        anchors.centerIn: parent
        spacing: 0

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.vertHour
            color: Services.Colors.snow
            font.pixelSize: 15
            font.family: "JetBrainsMono NF"
            font.bold: true
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.vertMinute
            color: Services.Colors.snow
            font.pixelSize: 15
            font.family: "JetBrainsMono NF"
            font.bold: true
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: root.vertSecond !== ""
            text: root.vertSecond
            color: Services.Colors.mist
            font.pixelSize: 11
            font.family: "JetBrainsMono NF"
            font.bold: true
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: root.vertSuffix !== ""
            text: root.vertSuffix
            color: Services.Colors.mist
            font.pixelSize: 9
            font.family: "JetBrainsMono NF"
            font.bold: true
        }

        // Weather rides under the time instead of beside it
        Item { width: 1; height: 6 }
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 16; height: 1
            color: Services.Colors.ghostAlpha(0.25)
        }
        Item { width: 1; height: 5 }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Services.Weather.icon
            font.pixelSize: 15
            font.family: "Material Symbols Rounded"
            color: Services.Colors.neutral
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Services.Weather.temp
            color: Services.Colors.mist
            font.pixelSize: 9
            font.family: "JetBrainsMono NF"
            font.bold: true
        }
    }

    RowLayout {
        id: clockRow
        visible: !root.vertical
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
