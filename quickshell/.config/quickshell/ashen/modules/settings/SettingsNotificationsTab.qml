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

    Card {
        title: "Sound"

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

            SectionLabel { text: "SOUND" }

            // The freedesktop set every distribution ships, plus whatever the
            // user points at. Picking one plays it: choosing a sound you cannot
            // hear is choosing blind.
            Flow {
                Layout.fillWidth: true
                spacing: 8

                Repeater {
                    model: ["message", "message-new-instant", "bell", "complete", "dialog-information"]
                    delegate: Rectangle {
                        required property var modelData
                        readonly property string file:
                            "/usr/share/sounds/freedesktop/stereo/" + modelData + ".oga"
                        readonly property bool active: Services.Notifications.soundFile === file
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
                            text: modelData
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
                                Services.Prefs.notifySoundFile = parent.file
                                Services.Notifications.play(parent.file)
                            }
                        }
                    }
                }
            }
        }
    }

    Item { Layout.preferredHeight: 8 }
}
