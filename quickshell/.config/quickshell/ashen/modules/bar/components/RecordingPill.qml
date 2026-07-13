import Quickshell
import QtQuick
import "root:/services" as Services

Rectangle {
    id: root
    visible: Services.AppState.recording
    width: visible ? row.width + 20 : 0
    height: 44
    radius: 10
    color: Services.Colors.ghost
    clip: true
    Behavior on width { NumberAnimation { duration: 150 } }

    property string elapsed: "00:00"

    Timer {
        interval: 1000
        running: Services.AppState.recording
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            let secs = Math.floor((Date.now() - Services.AppState.recordingStartTime) / 1000)
            let m = Math.floor(secs / 60)
            let s = secs % 60
            root.elapsed = (m < 10 ? "0" + m : m) + ":" + (s < 10 ? "0" + s : s)
        }
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 6
        Text {
            text: ""
            color: Services.Colors.abyss
            font.pixelSize: 16
            font.family: "Material Symbols Rounded"
            anchors.verticalCenter: parent.verticalCenter
        }
        Text {
            text: root.elapsed
            color: Services.Colors.abyss
            font.pixelSize: 12
            font.bold: true
            font.family: "JetBrainsMono NF"
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            Quickshell.execDetached(["sh", "-c",
                "PID=$(cat /home/adolf-arch/.cache/ashen_recording.pid 2>/dev/null); [ -n \"$PID\" ] && kill -INT \"$PID\"; rm -f /home/adolf-arch/.cache/ashen_recording.pid /home/adolf-arch/.cache/ashen_recording_start"
            ])
            Services.AppState.recording = false
        }
    }
}
