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
                    font.pixelSize: Services.Sizes.fsInput
                    font.bold: true
                    font.family: "JetBrainsMono NF"
                }
                Text {
                    text: "Records whatever the default output is playing"
                    color: Services.Colors.ash
                    font.pixelSize: Services.Sizes.fsMeta
                    font.family: "JetBrainsMono NF"
                }
            }
            Item { Layout.fillWidth: true }
            Toggle {
                checked: Services.Prefs.recordAudio
                onToggled: Services.Prefs.recordAudio = !Services.Prefs.recordAudio
            }
        }
        DirField {
            glyph: "\ue2c7"
            title: "Save to"
            value: Services.Prefs.recordDir !== ""
                ? Services.Prefs.recordDir : Services.Paths.recordings
            placeholder: Services.Paths.recordings
            onCommitted: path => Services.Prefs.recordDir = path
        }
    }

    Item { Layout.preferredHeight: 8 }
}
