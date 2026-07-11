import Quickshell
import Quickshell.Io
import QtQuick
import "root:/services" as Services

PanelWindow {
    id: win
    anchors { top: true; left: true; right: true; bottom: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    visible: Services.AppState.volumeVisible

    function setVolume(ratio) {
        ratio = Math.max(0, Math.min(1, ratio))
        let pct = Math.round(ratio * 100)
        Quickshell.execDetached(["sh", "-c", "wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ " + pct + "%"])
    }

    MouseArea {
        anchors.fill: parent
        z: -1
        onClicked: Services.AppState.volumeVisible = false
    }

    Rectangle {
        id: card
        anchors.top: parent.top
        anchors.topMargin: 64
        width: 280
        height: 100
        x: Math.max(12, Math.min(parent.width - width - 12, Services.AppState.volumePillCenterX - width / 2))
        Behavior on x { NumberAnimation { duration: 150 } }
        radius: 14
        color: Services.Colors.surfaceAlpha(0.95)
        border.color: Services.Colors.ghostAlpha(0.2)
        border.width: 1

        opacity: Services.AppState.volumeVisible ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

        transform: Translate {
            x: Services.AppState.volumeVisible ? 0 : -24
            Behavior on x { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
        }

        MouseArea { anchors.fill: parent; onClicked: {} }

        Column {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 10

        Row {
            width: parent.width
            spacing: 10

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Services.Audio.volume === 0 ? "" : (Services.Audio.volume < 66 ? "" : "")
                font.family: "Material Symbols Rounded"
                font.pixelSize: 18
                color: Services.Colors.ghost
            }

            Rectangle {
                id: track
                width: parent.width - 76
                height: 8
                anchors.verticalCenter: parent.verticalCenter
                radius: 4
                color: Services.Colors.ghostAlpha(0.15)

                Rectangle {
                    anchors.left: parent.left
                    height: parent.height
                    radius: 4
                    color: Services.Colors.ghost
                    width: parent.width * (Services.Audio.volume / 100)
                    Behavior on width { NumberAnimation { duration: 100 } }
                }

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -10
                    cursorShape: Qt.PointingHandCursor
                    onPressed: mouse => win.setVolume(mouse.x / track.width)
                    onPositionChanged: mouse => { if (pressed) win.setVolume(mouse.x / track.width) }
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Services.Audio.volume + "%"
                color: Services.Colors.snow
                font.pixelSize: 11
                font.family: "JetBrainsMono NF"
            }
        }
    
        Row {
            width: parent.width
            spacing: 10
            Rectangle {
                id: micBtn
                width: 28; height: 28
                radius: 8
                anchors.verticalCenter: parent.verticalCenter
                color: Services.Audio.micMuted ? Services.Colors.error_ : Services.Colors.ghostAlpha(0.2)
                Behavior on color { ColorAnimation { duration: 150 } }
                Text {
                    anchors.centerIn: parent
                    text: Services.Audio.micMuted ? "" : ""
                    font.family: "Material Symbols Rounded"
                    font.pixelSize: 16
                    color: Services.Audio.micMuted ? Services.Colors.snow : Services.Colors.ghost
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onEntered: parent.color = Services.Audio.micMuted ? Services.Colors.error_ : Services.Colors.ghostAlpha(0.35)
                    onExited: parent.color = Services.Audio.micMuted ? Services.Colors.error_ : Services.Colors.ghostAlpha(0.2)
                    onClicked: Services.Audio.toggleMicMute()
                }
            }
            Rectangle {
                id: micTrack
                width: parent.width - 28 - 10 - 50
                height: 8
                anchors.verticalCenter: parent.verticalCenter
                radius: 4
                color: Services.Colors.ghostAlpha(0.15)
                opacity: Services.Audio.micMuted ? 0.4 : 1.0
                Rectangle {
                    anchors.left: parent.left
                    height: parent.height
                    radius: 4
                    color: Services.Audio.micMuted ? Services.Colors.error_ : Services.Colors.ghost
                    width: parent.width * (Services.Audio.micVolume / 100)
                    Behavior on width { NumberAnimation { duration: 100 } }
                }
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -10
                    cursorShape: Qt.PointingHandCursor
                    onPressed: mouse => Services.Audio.setMicVolume(Math.round(Math.max(0, Math.min(1, mouse.x / micTrack.width)) * 100))
                    onPositionChanged: mouse => { if (pressed) Services.Audio.setMicVolume(Math.round(Math.max(0, Math.min(1, mouse.x / micTrack.width)) * 100)) }
                }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Services.Audio.micMuted ? "Muted" : Services.Audio.micVolume + "%"
                color: Services.Audio.micMuted ? Services.Colors.error_ : Services.Colors.snow
                font.pixelSize: 11
                font.family: "JetBrainsMono NF"
            }
        }
        }
        }
}
