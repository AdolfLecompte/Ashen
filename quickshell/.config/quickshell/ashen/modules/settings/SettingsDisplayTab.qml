import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import "root:/services" as Services
import "root:/modules/settings/components"

// Screen output: brightness and the blue-light filter.
TabPage {
    id: tab

    // Step a "HH:MM" string by `delta` minutes, wrapping within 24h. Used by the
    // night-light From/To steppers.
    function stepTime(hhmm, delta) {
        var p = hhmm.split(":")
        var m = (parseInt(p[0]) * 60 + parseInt(p[1]) + delta + 1440) % 1440
        var h = Math.floor(m / 60), mm = m % 60
        return (h < 10 ? "0" : "") + h + ":" + (mm < 10 ? "0" : "") + mm
    }

    Card {
        title: "Display"
        SliderRow {
            glyph: ""
            label: "Brightness"
            value: Services.Brightness.level
            onMoved: pct => Quickshell.execDetached(["sh", "-c", "brightnessctl set " + pct + "%"])
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 12
            RowLayout {
                Layout.fillWidth: true
                spacing: 12
                Text {
                    text: ""
                    font.family: "Material Symbols Rounded"
                    font.pixelSize: 20
                    color: Services.NightLight.enabled ? Services.Colors.ghost : Services.Colors.mist
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    Text { text: "Night Light"; color: Services.Colors.snow; font.pixelSize: 13; font.bold: true; font.family: "JetBrainsMono NF" }
                    Text { text: "Warms screen colors to ease eye strain"; color: Services.Colors.ash; font.pixelSize: 10; font.family: "JetBrainsMono NF" }
                }
                Toggle {
                    checked: Services.NightLight.enabled
                    onToggled: Services.NightLight.setEnabled(!Services.NightLight.enabled)
                }
            }

            // Options, only while enabled
            Collapse {
                Layout.leftMargin: 32
                gap: 12
                open: Services.NightLight.enabled

                // Temperature
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Text { text: "Temperature"; color: Services.Colors.snow; font.pixelSize: 12; font.bold: true; font.family: "JetBrainsMono NF" }
                        Text {
                            text: Services.NightLight.temperature + "K · " + (Services.NightLight.temperature <= 3500 ? "warmer" : Services.NightLight.temperature >= 5000 ? "subtle" : "balanced")
                            color: Services.Colors.ash; font.pixelSize: 10; font.family: "JetBrainsMono NF"
                        }
                    }
                    StepBtn {
                        glyph: ""
                        onClicked: Services.NightLight.setTemperature(Math.max(2500, Services.NightLight.temperature - 250))
                    }
                    StepBtn {
                        glyph: ""
                        onClicked: Services.NightLight.setTemperature(Math.min(6000, Services.NightLight.temperature + 250))
                    }
                }

                // Schedule on/off
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Text { text: "Auto schedule"; color: Services.Colors.snow; font.pixelSize: 12; font.bold: true; font.family: "JetBrainsMono NF" }
                        Text { text: Services.NightLight.scheduled ? "On between the times below" : "On constantly while enabled"; color: Services.Colors.ash; font.pixelSize: 10; font.family: "JetBrainsMono NF" }
                    }
                    Toggle {
                        checked: Services.NightLight.scheduled
                        onToggled: Services.NightLight.setScheduled(!Services.NightLight.scheduled)
                    }
                }

                // From / To (only when scheduled)
                Collapse {
                    gap: 10
                    open: Services.NightLight.scheduled

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10
                        Text { text: "From"; color: Services.Colors.snow; font.pixelSize: 12; font.bold: true; font.family: "JetBrainsMono NF"; Layout.preferredWidth: 40 }
                        Text { text: Services.NightLight.fromTime; color: Services.Colors.ghost; font.pixelSize: 13; font.bold: true; font.family: "JetBrainsMono NF" }
                        Item { Layout.fillWidth: true }
                        StepBtn {
                            glyph: ""
                            onClicked: Services.NightLight.setFrom(tab.stepTime(Services.NightLight.fromTime, -30))
                        }
                        StepBtn {
                            glyph: ""
                            onClicked: Services.NightLight.setFrom(tab.stepTime(Services.NightLight.fromTime, 30))
                        }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10
                        Text { text: "To"; color: Services.Colors.snow; font.pixelSize: 12; font.bold: true; font.family: "JetBrainsMono NF"; Layout.preferredWidth: 40 }
                        Text { text: Services.NightLight.toTime; color: Services.Colors.ghost; font.pixelSize: 13; font.bold: true; font.family: "JetBrainsMono NF" }
                        Item { Layout.fillWidth: true }
                        StepBtn {
                            glyph: ""
                            onClicked: Services.NightLight.setTo(tab.stepTime(Services.NightLight.toTime, -30))
                        }
                        StepBtn {
                            glyph: ""
                            onClicked: Services.NightLight.setTo(tab.stepTime(Services.NightLight.toTime, 30))
                        }
                    }
                }
            }
        }

    }

    Item { Layout.preferredHeight: 8 }
}
