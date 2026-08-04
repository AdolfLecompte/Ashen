import Quickshell
import QtQuick
import QtQuick.Layouts
import "root:/services" as Services
import "root:/modules/settings/components"

// What the shell is allowed to interrupt you with, and how long it may stay.
TabPage {
    id: tab

    Card {
        title: "Do Not Disturb"

        RowLayout {
            Layout.fillWidth: true
            spacing: 12
            RowGlyph { glyph: "" }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Text {
                    text: "Silence notifications"
                    color: Services.Colors.snow
                    font.pixelSize: 13
                    font.bold: true
                    font.family: "JetBrainsMono NF"
                }
                Text {
                    text: "Toasts stay hidden; urgent ones still come through"
                    color: Services.Colors.ash
                    font.pixelSize: 10
                    font.family: "JetBrainsMono NF"
                }
            }
            Toggle {
                checked: Services.AppState.doNotDisturb
                onToggled: Services.AppState.doNotDisturb = !Services.AppState.doNotDisturb
            }
        }
    }

    Card {
        title: "Toasts"

        SectionLabel { text: "On screen for" }
        Segmented {
            options: [
                { id: "3", label: "3s" },
                { id: "6", label: "6s" },
                { id: "10", label: "10s" },
                { id: "20", label: "20s" }
            ]
            current: String(Services.Prefs.toastSeconds)
            onPicked: id => Services.Prefs.toastSeconds = parseInt(id)
        }

        Divider {}

        SectionLabel { text: "Stacked at once" }
        RowLayout {
            Layout.fillWidth: true
            spacing: 12
            Segmented {
                options: [
                    { id: "3", label: "3" },
                    { id: "5", label: "5" },
                    { id: "8", label: "8" }
                ]
                current: String(Services.Prefs.maxToasts)
                onPicked: id => Services.Prefs.maxToasts = parseInt(id)
            }
            Text {
                Layout.fillWidth: true
                text: "The rest collapse into a +N row"
                color: Services.Colors.ash
                font.pixelSize: 10
                font.family: "JetBrainsMono NF"
            }
        }
    }

    Item { Layout.preferredHeight: 8 }
}
