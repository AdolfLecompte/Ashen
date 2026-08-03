import QtQuick
import QtQuick.Layouts
import "root:/services" as Services

// One Wi-Fi network row, shared by the bar panel and the settings tab. The
// caller sets the width, passes `net` ({ ssid, signal, secure }) and `known`
// (a saved network → shows the forget button), and handles `activate()` (tap
// the row) and `forget()` however it wants (connect vs. open a dialog, etc).
Rectangle {
    id: row
    required property var net
    property bool known: false
    signal activate()
    signal forget()

    height: 54
    radius: 8
    color: rowMouse.containsMouse ? Services.Colors.ghostAlpha(0.1) : "transparent"
    Behavior on color { ColorAnimation { duration: Services.Sizes.msMicro } }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        spacing: 10

        Text {
            text: row.net.signal >= 75 ? "" : row.net.signal >= 50 ? "" : row.net.signal >= 25 ? "" : ""
            color: Services.Colors.mist
            font.pixelSize: 20
            font.family: "Material Symbols Rounded"
        }
        Column {
            Layout.fillWidth: true
            spacing: 2
            Text {
                text: row.net.ssid
                color: Services.Colors.snow
                font.pixelSize: 13
                font.family: "JetBrainsMono NF"
                elide: Text.ElideRight
                width: parent.width
            }
            Text {
                text: row.net.signal + "% signal"
                color: Services.Colors.ash
                font.pixelSize: 10
                font.family: "JetBrainsMono NF"
            }
        }
        Text {
            visible: row.net.secure
            text: ""
            color: Services.Colors.ash
            font.pixelSize: 14
            font.family: "Material Symbols Rounded"
        }
        // Forget: only saved (known) networks can be forgotten.
        Rectangle {
            id: forgetBtn
            Layout.preferredWidth: 30
            Layout.preferredHeight: 30
            radius: 8
            visible: row.known
            color: forgetMouse.containsMouse ? Services.Colors.ghostAlpha(0.18) : "transparent"
            Text {
                anchors.centerIn: parent
                text: "\ue5cd"
                color: Services.Colors.ash
                font.pixelSize: 16
                font.family: "Material Symbols Rounded"
            }
            MouseArea {
                id: forgetMouse
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                hoverEnabled: true
                onClicked: row.forget()
            }
        }
    }

    MouseArea {
        id: rowMouse
        anchors.fill: parent
        // leave the right edge clickable for the forget button on saved rows
        anchors.rightMargin: row.known ? 40 : 0
        cursorShape: Qt.PointingHandCursor
        hoverEnabled: true
        onClicked: row.activate()
    }
}
