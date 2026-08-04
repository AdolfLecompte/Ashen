import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import "root:/services" as Services
import "root:/modules/widgets" as Widgets
import "root:/modules/settings/components"

// Playback and capture levels, plus the device pickers behind them.
TabPage {
    id: tab

    Card {
        title: "Audio"
        SliderRow {
            glyph: Services.Audio.muted ? "" : ""
            label: "Volume"
            value: Services.Audio.volume
            valueText: Services.Audio.muted ? "Muted" : shownPct + "%"
            dimmed: Services.Audio.muted
            muted: Services.Audio.muted
            onGlyphClicked: Services.Audio.toggleMute()
            glyphInteractive: true
            // Unmutes on drag: nudging a muted slider and hearing nothing
            // reads as broken. -l 1.0 keeps it from going past 100%.
            onMoved: pct => Quickshell.execDetached(["sh", "-c",
                "wpctl set-mute @DEFAULT_AUDIO_SINK@ 0 && wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ " + pct + "%"])
        }

        // Output device selector (speakers / headphones / HDMI)
        Widgets.DevicePicker {
            Layout.fillWidth: true
            glyph: "\ue050"
            devices: Services.Audio.sinks
            current: Services.Audio.defaultSink
            onPicked: name => Services.Audio.setSink(name)
        }

        SliderRow {
            glyph: Services.Audio.micMuted ? "" : ""
            label: "Microphone"
            value: Services.Audio.micVolume
            valueText: Services.Audio.micMuted ? "Muted" : shownPct + "%"
            dimmed: Services.Audio.micMuted
            muted: Services.Audio.micMuted
            // Click the mic glyph to mute/unmute
            onGlyphClicked: Services.Audio.toggleMicMute()
            glyphInteractive: true
            onMoved: pct => {
                if (Services.Audio.micMuted) Services.Audio.toggleMicMute()
                Services.Audio.setMicVolume(pct)
            }
        }

        // Input device selector (microphones)
        Widgets.DevicePicker {
            Layout.fillWidth: true
            glyph: "\ue029"
            devices: Services.Audio.sources
            current: Services.Audio.defaultSource
            onPicked: name => Services.Audio.setSource(name)
        }

    }

    Card {
        title: "Screen Recording"

        RowLayout {
            Layout.fillWidth: true
            spacing: 12
            RowGlyph { glyph: "\ue029" }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Text {
                    text: "Capture desktop audio"
                    color: Services.Colors.snow
                    font.pixelSize: 13
                    font.bold: true
                    font.family: "JetBrainsMono NF"
                }
                Text {
                    text: "Records whatever the default output is playing"
                    color: Services.Colors.ash
                    font.pixelSize: 10
                    font.family: "JetBrainsMono NF"
                }
            }
            Toggle {
                checked: Services.Prefs.recordAudio
                onToggled: Services.Prefs.recordAudio = !Services.Prefs.recordAudio
            }
        }

        Divider {}

        DirField {
            glyph: "\ue2c7"
            title: "Save to"
            value: Services.Prefs.recordDir !== ""
                ? Services.Prefs.recordDir : Services.Paths.recordings
            placeholder: Services.Paths.recordings
            onCommitted: path => Services.Prefs.recordDir = path
        }
    }

    Card {
        title: "Notification sound"

        Text {
            text: "A sound when a notification arrives. Nothing here touches what your apps play."
            color: Services.Colors.ash
            font.pixelSize: 10
            font.family: "JetBrainsMono NF"
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 12
            Text {
                Layout.fillWidth: true
                text: "Play a sound on arrival"
                color: Services.Colors.snow
                font.pixelSize: Services.Sizes.fsBody
                font.family: "JetBrainsMono NF"
            }
            Toggle {
                checked: Services.Prefs.notifySound
                onToggled: Services.Prefs.notifySound = !Services.Prefs.notifySound
            }
        }

        Collapse {
            open: Services.Prefs.notifySound
            gap: 12

            RowLayout {
                Layout.fillWidth: true
                spacing: 12
                Text {
                    Layout.fillWidth: true
                    text: "Only for critical ones"
                    color: Services.Colors.snow
                    font.pixelSize: Services.Sizes.fsBody
                    font.family: "JetBrainsMono NF"
                }
                Toggle {
                    checked: Services.Prefs.notifySoundCriticalOnly
                    onToggled: Services.Prefs.notifySoundCriticalOnly = !Services.Prefs.notifySoundCriticalOnly
                }
            }

            SectionLabel { text: "VOLUME" }

            // The slider speaks in whole percent, the preference in 0..1.
            SliderRow {
                glyph: "\ue050"
                label: "Volume"
                value: Math.round(Services.Prefs.soundVolume * 100)
                onMoved: pct => Services.Prefs.soundVolume = pct / 100
            }

            SectionLabel { text: "SOUND" }

            // The freedesktop set every distribution ships, plus whatever the
            // user points at. Picking one plays it: choosing a sound you cannot
            // hear is choosing blind.
            Flow {
                Layout.fillWidth: true
                spacing: 8

                Repeater {
                    model: Services.Notifications.soundChoices

                    delegate: Rectangle {
                        required property var modelData
                        readonly property bool active:
                            Services.Notifications.soundFile === modelData.path
                        height: 30
                        width: soundName.implicitWidth + 24
                        radius: 9
                        color: active ? Services.Colors.ghost : Services.Colors.fillRest
                        gradient: Services.Prefs.useGradients && active
                            ? Services.Colors.accentGradient : null
                        Behavior on color { ColorAnimation { duration: Services.Sizes.msMicro } }

                        Text {
                            id: soundName
                            anchors.centerIn: parent
                            // The shell's own are marked: they travel with the
                            // rice, the rest are whatever this machine has.
                            text: (parent.modelData.mine ? "\u2726 " : "") + parent.modelData.name
                            color: parent.active ? Services.Colors.accentText
                                 : (soundHover.containsMouse ? Services.Colors.snow : Services.Colors.mist)
                            font.pixelSize: 11
                            font.family: "JetBrainsMono NF"
                            Behavior on color { ColorAnimation { duration: Services.Sizes.msMicro } }
                        }
                        MouseArea {
                            id: soundHover
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                Services.Prefs.notifySoundFile = parent.modelData.path
                                Services.Notifications.play(parent.modelData.path)
                            }
                        }
                    }
                }
            }
        }
    }

    Item { Layout.preferredHeight: 8 }
}
