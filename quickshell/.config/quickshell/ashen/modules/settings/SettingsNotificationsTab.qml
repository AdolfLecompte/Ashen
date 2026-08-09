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
                    font.pixelSize: Services.Sizes.fsInput
                    font.bold: true
                    font.family: "JetBrainsMono NF"
                }
                Text {
                    text: "Toasts stay hidden; urgent ones still come through"
                    color: Services.Colors.ash
                    font.pixelSize: Services.Sizes.fsMeta
                    font.family: "JetBrainsMono NF"
                }
            }
            Item { Layout.fillWidth: true }
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
                font.pixelSize: Services.Sizes.fsMeta
                font.family: "JetBrainsMono NF"
            }
        }
    }

    // Lives here, not in Sound: every preference behind it belongs to
    // Notifications (`notifySound`, `notifySoundFile`, `soundVolume`), and the
    // Sound tab is about what the machine plays, not about what interrupts you.
    Card {
        title: "Sound"

        RowLayout {
            Layout.fillWidth: true
            spacing: 12
            RowGlyph { glyph: "" }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Text {
                    text: "Play a sound on arrival"
                    color: Services.Colors.snow
                    font.pixelSize: Services.Sizes.fsInput
                    font.bold: true
                    font.family: "JetBrainsMono NF"
                }
                Text {
                    text: "Nothing here touches what your apps play"
                    color: Services.Colors.ash
                    font.pixelSize: Services.Sizes.fsMeta
                    font.family: "JetBrainsMono NF"
                }
            }
            Item { Layout.fillWidth: true }
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
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    Text {
                        text: "Only for critical ones"
                        color: Services.Colors.snow
                        font.pixelSize: Services.Sizes.fsInput
                        font.bold: true
                        font.family: "JetBrainsMono NF"
                    }
                    Text {
                        text: "The rest arrive quietly"
                        color: Services.Colors.ash
                        font.pixelSize: Services.Sizes.fsMeta
                        font.family: "JetBrainsMono NF"
                    }
                }
                Item { Layout.fillWidth: true }
                Toggle {
                    checked: Services.Prefs.notifySoundCriticalOnly
                    onToggled: Services.Prefs.notifySoundCriticalOnly = !Services.Prefs.notifySoundCriticalOnly
                }
            }

            // The slider speaks in whole percent, the preference in 0..1.
            SliderRow {
                glyph: ""
                label: "Volume"
                value: Math.round(Services.Prefs.soundVolume * 100)
                onMoved: pct => Services.Prefs.soundVolume = pct / 100
            }

            SectionLabel { text: "Sound" }

            // The freedesktop set every distribution ships, plus whatever the
            // user points at. Picking one plays it: choosing a sound you cannot
            // hear is choosing blind.
            Flow {
                Layout.fillWidth: true
                spacing: 6

                Repeater {
                    model: Services.Notifications.soundChoices

                    delegate: Item {
                        id: chip
                        required property var modelData
                        readonly property bool active:
                            Services.Notifications.soundFile === chip.modelData.path
                        readonly property bool warm: soundHover.containsMouse

                        implicitWidth: soundName.implicitWidth + 22
                        implicitHeight: Services.Sizes.innerH
                        scale: Services.Sizes.hoverScale(chip.warm, soundHover.pressed)
                        Behavior on scale { NumberAnimation { duration: Services.Sizes.pillHoverMs; easing.type: Services.Sizes.easeOut } }

                        Rectangle {
                            anchors.fill: parent
                            radius: Services.Sizes.innerR
                            color: chip.active ? Services.Colors.ghost : Services.Colors.fillRest
                            gradient: Services.Prefs.useGradients && chip.active
                                ? Services.Colors.accentGradient : null
                            Behavior on color { ColorAnimation { duration: Services.Sizes.msStandard } }
                        }

                        Text {
                            id: soundName
                            anchors.centerIn: parent
                            // The shell's own are marked: they travel with the
                            // rice, the rest are whatever this machine has.
                            text: (chip.modelData.mine ? "✦ " : "") + chip.modelData.name
                            color: chip.active ? Services.Colors.accentText
                                 : chip.warm ? Services.Colors.snow : Services.Colors.surfaceText
                            font.pixelSize: Services.Sizes.fsBody
                            font.family: "JetBrainsMono NF"
                            Behavior on color { ColorAnimation { duration: Services.Sizes.msStandard } }
                        }
                        MouseArea {
                            id: soundHover
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                Services.Prefs.notifySoundFile = chip.modelData.path
                                Services.Notifications.play(chip.modelData.path)
                            }
                        }
                    }
                }
            }
        }
    }

    Item { Layout.preferredHeight: 8 }
}
