import Quickshell
import Quickshell.Io
import QtQuick
import Qt5Compat.GraphicalEffects
import QtQuick.Layouts
import "root:/services" as Services

ColumnLayout {
    id: tab
    anchors.fill: parent
    anchors.margins: 28
    spacing: 18

    Text {
        text: "General"
        color: Services.Colors.snow
        font.pixelSize: 20
        font.bold: true
        font.family: "JetBrainsMono NF"
    }

    // ── Foto de perfil ──
    RowLayout {
        Layout.fillWidth: true
        spacing: 14

        Rectangle {
            id: faceBox
            width: 64; height: 64
            radius: 14
            color: Services.Colors.ghostAlpha(0.15)
            border.color: Services.Colors.ghostAlpha(0.35)
            border.width: 2
            clip: true

            Image {
                id: faceImg
                anchors.fill: parent
                source: "file:///home/adolf/.face?" + Services.AppState.faceVersion
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                visible: false
                cache: false
            }
            Rectangle {
                id: faceMask
                anchors.fill: faceImg
                radius: 12
                visible: false
            }
            OpacityMask {
                anchors.fill: faceImg
                source: faceImg
                maskSource: faceMask
                visible: faceImg.status === Image.Ready
            }
            Text {
                anchors.centerIn: parent
                text: ""
                color: Services.Colors.ghost
                font.pixelSize: 30
                font.family: "Material Symbols Rounded"
                visible: faceImg.status !== Image.Ready
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            Text { text: "Profile Picture"; color: Services.Colors.snow; font.pixelSize: 13; font.bold: true; font.family: "JetBrainsMono NF" }
            Text { text: "adolf-arch"; color: Services.Colors.mist; font.pixelSize: 11; font.family: "JetBrainsMono NF" }
        }

        Rectangle {
            width: changeRow.implicitWidth + 20
            height: 34
            radius: 8
            color: Services.Colors.ghostAlpha(0.15)
            Behavior on color { ColorAnimation { duration: 150 } }
            RowLayout {
                id: changeRow
                anchors.centerIn: parent
                spacing: 6
                Text { text: ""; font.family: "Material Symbols Rounded"; font.pixelSize: 14; color: Services.Colors.ghost }
                Text { text: "Change"; color: Services.Colors.snow; font.pixelSize: 12; font.family: "JetBrainsMono NF" }
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                hoverEnabled: true
                onEntered: parent.color = Services.Colors.ghostAlpha(0.3)
                onExited: parent.color = Services.Colors.ghostAlpha(0.15)
                onClicked: facePickProc.running = true
            }
        }
    }

    Process {
        id: facePickProc
        command: ["sh", "-c", "zenity --file-selection --title='Choose profile picture' --file-filter='Images | *.png *.jpg *.jpeg' 2>/dev/null"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                let path = text.trim()
                if (path.length > 0) {
                    faceCopyProc.command = ["sh", "-c", "cp \"" + path + "\" /home/adolf/.face"]
                    faceCopyProc.running = true
                }
            }
        }
    }
    Process {
        id: faceCopyProc
        running: false
        onExited: Services.AppState.faceVersion = Date.now()
    }

    Rectangle { Layout.fillWidth: true; height: 1; color: Services.Colors.ghostAlpha(0.15) }

    // ── Brillo ──
    ColumnLayout {
        Layout.fillWidth: true
        spacing: 6
        RowLayout {
            spacing: 10
            Text { text: ""; font.family: "Material Symbols Rounded"; font.pixelSize: 18; color: Services.Colors.ghost }
            Text { text: "Brightness"; color: Services.Colors.snow; font.pixelSize: 13; font.family: "JetBrainsMono NF"; Layout.fillWidth: true }
            Text { text: Services.Brightness.level + "%"; color: Services.Colors.mist; font.pixelSize: 12; font.family: "JetBrainsMono NF" }
        }
        Rectangle {
            id: brightTrack
            Layout.fillWidth: true
            height: 10
            radius: 5
            color: Services.Colors.ghostAlpha(0.15)
            Rectangle {
                anchors.left: parent.left
                height: parent.height
                radius: 5
                color: Services.Colors.ghost
                width: parent.width * (Services.Brightness.level / 100)
                Behavior on width { NumberAnimation { duration: 100 } }
            }
            Rectangle {
                width: 16; height: 16; radius: 8
                color: Services.Colors.snow
                border.color: Services.Colors.ghost
                border.width: 2
                anchors.verticalCenter: parent.verticalCenter
                x: Math.min(Math.max(parent.width * (Services.Brightness.level / 100) - width / 2, 0), parent.width - width)
                Behavior on x { NumberAnimation { duration: 100 } }
            }
            MouseArea {
                anchors.fill: parent
                anchors.margins: -8
                cursorShape: Qt.PointingHandCursor
                onPressed: mouse => Quickshell.execDetached(["sh", "-c", "brightnessctl set " + Math.round(Math.max(0, Math.min(1, mouse.x / brightTrack.width)) * 100) + "%"])
                onPositionChanged: mouse => { if (pressed) Quickshell.execDetached(["sh", "-c", "brightnessctl set " + Math.round(Math.max(0, Math.min(1, mouse.x / brightTrack.width)) * 100) + "%"]) }
            }
        }
    }

    // ── Volumen ──
    ColumnLayout {
        Layout.fillWidth: true
        spacing: 6
        RowLayout {
            spacing: 10
            Text { text: ""; font.family: "Material Symbols Rounded"; font.pixelSize: 18; color: Services.Colors.ghost }
            Text { text: "Volume"; color: Services.Colors.snow; font.pixelSize: 13; font.family: "JetBrainsMono NF"; Layout.fillWidth: true }
            Text { text: Services.Audio.muted ? "Muted" : Services.Audio.volume + "%"; color: Services.Colors.mist; font.pixelSize: 12; font.family: "JetBrainsMono NF" }
        }
        Rectangle {
            id: volTrack
            Layout.fillWidth: true
            height: 10
            radius: 5
            color: Services.Colors.ghostAlpha(0.15)
            opacity: Services.Audio.muted ? 0.4 : 1.0
            Rectangle {
                anchors.left: parent.left
                height: parent.height
                radius: 5
                color: Services.Colors.ghost
                width: parent.width * (Services.Audio.volume / 100)
                Behavior on width { NumberAnimation { duration: 100 } }
            }
            Rectangle {
                width: 16; height: 16; radius: 8
                color: Services.Colors.snow
                border.color: Services.Colors.ghost
                border.width: 2
                anchors.verticalCenter: parent.verticalCenter
                x: Math.min(Math.max(parent.width * (Services.Audio.volume / 100) - width / 2, 0), parent.width - width)
                Behavior on x { NumberAnimation { duration: 100 } }
            }
            MouseArea {
                anchors.fill: parent
                anchors.margins: -8
                cursorShape: Qt.PointingHandCursor
                onPressed: mouse => Quickshell.execDetached(["sh", "-c", "wpctl set-mute @DEFAULT_AUDIO_SINK@ 0 && wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ " + Math.round(Math.max(0, Math.min(1, mouse.x / volTrack.width)) * 100) + "%"])
                onPositionChanged: mouse => { if (pressed) Quickshell.execDetached(["sh", "-c", "wpctl set-mute @DEFAULT_AUDIO_SINK@ 0 && wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ " + Math.round(Math.max(0, Math.min(1, mouse.x / volTrack.width)) * 100) + "%"]) }
            }
        }
    }

    Rectangle { Layout.fillWidth: true; height: 1; color: Services.Colors.ghostAlpha(0.15) }

    // ── Keyboard layout ──
    ColumnLayout {
        id: kbLayoutSection
        Layout.fillWidth: true
        spacing: 8

        property string currentLayout: "latam"

        Component.onCompleted: kbLayoutProc.running = true
        Process {
            id: kbLayoutProc
            command: ["sh", "-c", "grep kb_layout /home/adolf/ashen/hypr/.config/hypr/conf/input.lua | head -1"]
            running: false
            stdout: StdioCollector {
                onStreamFinished: {
                    let m = text.match(/"([^"]*)"/)
                    if (m) kbLayoutSection.currentLayout = m[1]
                }
            }
        }

        function setLayout(code) {
            kbLayoutSection.currentLayout = code
            Quickshell.execDetached(["sh", "-c",
                "hyprctl keyword input:kb_layout " + code +
                " && sed -i 's/kb_layout = \"[^\"]*\"/kb_layout = \"" + code + "\"/' /home/adolf/ashen/hypr/.config/hypr/conf/input.lua"
            ])
        }

        Text { text: "Keyboard Layout"; color: Services.Colors.snow; font.pixelSize: 13; font.bold: true; font.family: "JetBrainsMono NF" }

        RowLayout {
            spacing: 10
            Repeater {
                model: [
                    { code: "us", label: "US" },
                    { code: "latam", label: "Latam" },
                ]
                delegate: Rectangle {
                    required property var modelData
                    width: 90; height: 44
                    radius: 10
                    color: kbLayoutSection.currentLayout === modelData.code ? Services.Colors.ghost : Services.Colors.ghostAlpha(0.12)
                    Behavior on color { ColorAnimation { duration: 150 } }
                    Text {
                        anchors.centerIn: parent
                        text: modelData.label
                        font.pixelSize: 13
                        font.bold: true
                        font.family: "JetBrainsMono NF"
                        color: kbLayoutSection.currentLayout === modelData.code ? Services.Colors.abyss : Services.Colors.mist
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: kbLayoutSection.setLayout(modelData.code)
                    }
                }
            }
        }
    }

    Rectangle { Layout.fillWidth: true; height: 1; color: Services.Colors.ghostAlpha(0.15) }

    // ── Mantener despierto ──
    RowLayout {
        Layout.fillWidth: true
        spacing: 12
        Text { text: ""; font.family: "Material Symbols Rounded"; font.pixelSize: 20; color: Services.AppState.keepAwake ? Services.Colors.ghost : Services.Colors.mist }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            Text { text: "Keep Awake"; color: Services.Colors.snow; font.pixelSize: 13; font.bold: true; font.family: "JetBrainsMono NF" }
            Text { text: "Prevents auto-lock and screen dimming"; color: Services.Colors.mist; font.pixelSize: 10; font.family: "JetBrainsMono NF" }
        }
        Rectangle {
            width: 52; height: 28; radius: 14
            color: Services.AppState.keepAwake ? Services.Colors.ghost : Services.Colors.ghostAlpha(0.25)
            Behavior on color { ColorAnimation { duration: 200 } }
            Rectangle {
                width: 20; height: 20; radius: 10
                color: Services.Colors.snow
                anchors.verticalCenter: parent.verticalCenter
                x: Services.AppState.keepAwake ? parent.width - width - 4 : 4
                Behavior on x { NumberAnimation { duration: 200 } }
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    Services.AppState.keepAwake = !Services.AppState.keepAwake
                    if (Services.AppState.keepAwake) {
                        Quickshell.execDetached(["sh", "-c", "pkill -9 hypridle"])
                    } else {
                        Quickshell.execDetached(["sh", "-c", "hypridle"])
                    }
                }
            }
        }
    }

    Item { Layout.fillHeight: true }
}
