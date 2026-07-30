import Quickshell
import Quickshell.Io
import QtQuick
import "root:/services" as Services
import "root:/modules/widgets" as Widgets

PanelWindow {
    id: win
    anchors { top: true; left: true; right: true; bottom: true }
    screen: Services.Screens.active
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    // stays mapped through the close animation, so the exit plays in reverse
    readonly property bool shown: Services.AppState.volumeVisible
    visible: shown || closeDelay.running
    onShownChanged: if (!shown) closeDelay.restart()
    // Mapped until the drop is all the way home; see DropCard.closeMs.
    Timer { id: closeDelay; interval: card.closeMs }

    function setVolume(ratio) {
        ratio = Math.max(0, Math.min(1, ratio))
        let pct = Math.round(ratio * 100)
        Quickshell.execDetached(["sh", "-c", "wpctl set-mute @DEFAULT_AUDIO_SINK@ 0 && wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ " + pct + "%"])
    }

    MouseArea {
        anchors.fill: parent
        z: -1
        onClicked: Services.AppState.volumeVisible = false
    }

    // Falls out of its chip like a drop, the same opening as the clock.
    Widgets.DropCard {
        id: card
        shown: Services.AppState.volumeVisible
        pillCX: Services.AppState.volumePillCenterX
        pillCY: Services.AppState.volumePillCenterY
        pillActive: !Services.Audio.muted && Services.Audio.volume > 0
        pillGlyph: Services.AppState.pillGlyph("volume")
        pillLabel: Services.AppState.pillLabel("volume")
        // The chip's speaker glyph lands on the header's, its reading on the
        // percentage: the same two things, moved.
        glyphTarget: hdrGlyph
        labelTarget: hdrValue
        pillW: Services.AppState.volumePillW
        pillH: Services.AppState.volumePillH
        openW: 300
        openH: col.implicitHeight + 32
        cardRadius: 16

        Column {
            id: col
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 16
            spacing: 12

            // ── Speaker ────────────────────────────
            Item {
                width: parent.width
                height: 26

                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8

                    // Click the glyph to mute/unmute -- same effect as Settings
                    Rectangle {
                        width: 26; height: 26
                        radius: 8
                        anchors.verticalCenter: parent.verticalCenter
                        color: spkArea.containsMouse ? Services.Colors.ghostAlpha(0.2) : "transparent"
                        Behavior on color { ColorAnimation { duration: 120 } }
                        Text {
                            id: hdrGlyph
                            opacity: card.morphingGlyph ? 0 : 1
                            anchors.centerIn: parent
                            // The chip's own icon, not a second copy of the
                            // rule. Its set has a headphones variant this one
                            // never had, so with headphones in they were two
                            // different glyphs and the piece refused to fly.
                            text: Services.AppState.pillGlyph("volume")
                            font.family: "Material Symbols Rounded"
                            font.pixelSize: 18
                            color: Services.Audio.muted ? Services.Colors.mist : Services.Colors.ghost
                            Behavior on color { ColorAnimation { duration: 120 } }
                        }
                        MouseArea {
                            id: spkArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Services.Audio.toggleMute()
                        }
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Volume"
                        color: Services.Colors.mist
                        font.pixelSize: 12
                        font.family: "JetBrainsMono NF"
                    }
                }

                Text {
                    id: hdrValue
                    opacity: card.morphingLabel ? 0 : 1
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    // "Mute" on the bar and "Muted" here were two words, so the
                    // reading stayed behind and only the icon travelled. One
                    // word now, read off the chip.
                    text: Services.AppState.pillLabel("volume")
                    color: Services.Audio.muted ? Services.Colors.mist : Services.Colors.snow
                    font.pixelSize: 14
                    font.bold: true
                    font.family: "JetBrainsMono NF"
                }
            }

            Widgets.SliderTrack {
                id: volBar
                width: parent.width
                knobSize: 18
                knobBorder: 1
                knobBorderColor: Services.Colors.ghostAlpha(0.45)
                hitMargin: 14
                dimmed: Services.Audio.muted
                fillColor: Services.Audio.muted ? Services.Colors.mist : Services.Colors.ghost
                value: Services.Audio.volume / 100
                onMoved: r => win.setVolume(r)
            }

            // Output device picker (speakers / headphones / HDMI)
            Widgets.DevicePicker {
                width: parent.width
                glyph: "\ue050"
                devices: Services.Audio.sinks
                current: Services.Audio.defaultSink
                onPicked: name => Services.Audio.setSink(name)
            }

            // ── Divider ────────────────────────────
            Rectangle {
                width: parent.width
                height: 1
                color: Services.Colors.ghostAlpha(0.12)
            }

            // ── Microphone ─────────────────────────
            Item {
                width: parent.width
                height: 28

                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8

                    // Click the glyph to mute/unmute -- same effect as Settings
                    Rectangle {
                        width: 26; height: 26
                        radius: 8
                        anchors.verticalCenter: parent.verticalCenter
                        color: micArea.containsMouse ? Services.Colors.ghostAlpha(0.2) : "transparent"
                        Behavior on color { ColorAnimation { duration: 120 } }
                        Text {
                            anchors.centerIn: parent
                            text: Services.Audio.micMuted ? "" : ""
                            font.family: "Material Symbols Rounded"
                            font.pixelSize: 18
                            color: Services.Audio.micMuted ? Services.Colors.mist : Services.Colors.ghost
                            Behavior on color { ColorAnimation { duration: 120 } }
                        }
                        MouseArea {
                            id: micArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Services.Audio.toggleMicMute()
                        }
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Microphone"
                        color: Services.Colors.mist
                        font.pixelSize: 12
                        font.family: "JetBrainsMono NF"
                    }
                }

                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: Services.Audio.micMuted ? "Muted" : Math.round(micBar.shown * 100) + "%"
                    color: Services.Audio.micMuted ? Services.Colors.mist : Services.Colors.snow
                    font.pixelSize: 14
                    font.bold: true
                    font.family: "JetBrainsMono NF"
                }
            }

            Widgets.SliderTrack {
                id: micBar
                width: parent.width
                knobSize: 18
                knobBorder: 1
                knobBorderColor: Services.Colors.ghostAlpha(0.45)
                hitMargin: 14
                dimmed: Services.Audio.micMuted
                fillColor: Services.Audio.micMuted ? Services.Colors.mist : Services.Colors.ghost
                value: Services.Audio.micVolume / 100
                onMoved: r => Services.Audio.setMicVolume(Math.round(r * 100))
            }

            // Input device picker (microphones)
            Widgets.DevicePicker {
                width: parent.width
                glyph: "\ue029"
                devices: Services.Audio.sources
                current: Services.Audio.defaultSource
                onPicked: name => Services.Audio.setSource(name)
            }
        }
    }
}
