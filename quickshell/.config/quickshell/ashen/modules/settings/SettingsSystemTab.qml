import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "root:/services" as Services
import "root:/modules/widgets" as Widgets

Item {
    id: tab
    anchors.fill: parent

    // ── Reusable bits ─────────────────────────────────────────────────────
    // Volume, mic and brightness are the same widget with a different backend,
    // so the row lives here once. The track itself is shared with the bar pills
    // (modules/widgets/SliderTrack) so drag behaviour cannot drift apart.
    component SliderRow: ColumnLayout {
        id: sliderRow
        property string glyph: ""
        property string label: ""
        property int value: 0                 // authoritative, from the service
        // What is on screen right now: follows the drag, not the 1s service poll
        readonly property int shownPct: Math.round(bar.shown * 100)
        property string valueText: shownPct + "%"
        property bool dimmed: false
        property bool muted: false
        // Brightness has nothing to mute, so its glyph must not pretend to be
        // a button (no hover, no hand cursor).
        property bool glyphInteractive: false
        signal moved(int pct)
        signal glyphClicked()

        Layout.fillWidth: true
        spacing: 6

        RowLayout {
            spacing: 10
            Rectangle {
                width: 26; height: 26
                radius: 8
                color: glyphArea.containsMouse && sliderRow.glyphInteractive
                    ? Services.Colors.ghostAlpha(0.2) : "transparent"
                Behavior on color { ColorAnimation { duration: 120 } }
                Text {
                    anchors.centerIn: parent
                    text: sliderRow.glyph
                    font.family: "Material Symbols Rounded"
                    font.pixelSize: 18
                    color: sliderRow.muted ? Services.Colors.error_ : Services.Colors.ghost
                    Behavior on color { ColorAnimation { duration: 120 } }
                }
                MouseArea {
                    id: glyphArea
                    anchors.fill: parent
                    enabled: sliderRow.glyphInteractive
                    hoverEnabled: sliderRow.glyphInteractive
                    cursorShape: Qt.PointingHandCursor
                    onClicked: sliderRow.glyphClicked()
                }
            }
            Text {
                text: sliderRow.label
                color: Services.Colors.snow
                font.pixelSize: 13
                font.family: "JetBrainsMono NF"
                Layout.fillWidth: true
            }
            Text {
                text: sliderRow.valueText
                color: Services.Colors.mist
                font.pixelSize: 12
                font.family: "JetBrainsMono NF"
            }
        }
        Widgets.SliderTrack {
            id: bar
            Layout.fillWidth: true
            value: sliderRow.value / 100
            dimmed: sliderRow.dimmed
            onMoved: r => sliderRow.moved(Math.round(r * 100))
        }
    }

    // A pill row where exactly one option is active.
    component ChoiceRow: RowLayout {
        id: choiceRow
        property var options: []       // [{ id, label }]
        property string current: ""
        signal picked(string id)
        spacing: 8
        Repeater {
            model: choiceRow.options
            delegate: Rectangle {
                required property var modelData
                width: pillText.implicitWidth + 24
                height: 32
                radius: 8
                color: choiceRow.current === modelData.id ? Services.Colors.ghost : Services.Colors.ghostAlpha(0.12)
                Behavior on color { ColorAnimation { duration: 150 } }
                Text {
                    id: pillText
                    anchors.centerIn: parent
                    text: modelData.label
                    font.pixelSize: 11
                    font.family: "JetBrainsMono NF"
                    color: choiceRow.current === modelData.id ? Services.Colors.abyss : Services.Colors.snow
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: choiceRow.picked(modelData.id)
                }
            }
        }
    }

    component Toggle: Rectangle {
        id: sw
        property bool checked: false
        signal toggled()
        width: 52; height: 28; radius: 14
        color: checked ? Services.Colors.ghost : Services.Colors.ghostAlpha(0.25)
        Behavior on color { ColorAnimation { duration: 200 } }
        Rectangle {
            width: 20; height: 20; radius: 10
            color: Services.Colors.snow
            anchors.verticalCenter: parent.verticalCenter
            x: sw.checked ? parent.width - width - 4 : 4
            Behavior on x { NumberAnimation { duration: 200 } }
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: sw.toggled()
        }
    }

    component SectionLabel: Text {
        color: Services.Colors.mist
        font.pixelSize: 11
        font.family: "JetBrainsMono NF"
    }

    component Divider: Rectangle {
        Layout.fillWidth: true
        height: 1
        color: Services.Colors.ghostAlpha(0.15)
    }

    // ── Content ───────────────────────────────────────────────────────────
    Flickable {
        anchors.fill: parent
        anchors.margins: 28
        contentHeight: col.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded; width: 4 }

        ColumnLayout {
            id: col
            width: parent.width
            spacing: 14

            property string timeRemaining: "--"
            property var availableProfiles: []
            property string activeProfile: ""

            // Layout picker state
            property bool pickerOpen: false
            property string layoutQuery: ""
            // Match on code or name, so both "de" and "german" find German
            readonly property var filteredLayouts: {
                let q = col.layoutQuery.trim().toLowerCase()
                let all = Services.Keyboard.available
                if (q === "") return all
                return all.filter(l => l.code.indexOf(q) !== -1
                    || l.name.toLowerCase().indexOf(q) !== -1)
            }

            // Live preview under "Time Format". new Date() is not reactive, so
            // without this tick the sample freezes at whatever time the tab opened.
            property string timePreview: Qt.formatDateTime(new Date(), Services.Prefs.timeFormat)
            Timer {
                interval: 1000
                running: true
                repeat: true
                onTriggered: col.timePreview = Qt.formatDateTime(new Date(), Services.Prefs.timeFormat)
            }

            function setProfile(name) {
                if (!availableProfiles.includes(name)) return
                Quickshell.execDetached(["sh", "-c", "powerprofilesctl set " + name])
                activeProfile = name
            }

            Component.onCompleted: {
                battProc.running = true
                profProc.running = true
            }

            Process {
                id: battProc
                command: ["sh", "-c", "upower -i $(upower -e | grep BAT) 2>/dev/null | grep -E 'time to (empty|full)'"]
                running: false
                stdout: StdioCollector {
                    onStreamFinished: {
                        let line = text.trim()
                        col.timeRemaining = line.length > 0 ? line.split(":").slice(1).join(":").trim() : "--"
                    }
                }
            }
            Process {
                id: profProc
                command: ["sh", "-c", "powerprofilesctl list"]
                running: false
                stdout: StdioCollector {
                    onStreamFinished: {
                        let lines = text.split("\n")
                        let profiles = []
                        let active = ""
                        for (let line of lines) {
                            let m = line.match(/^\s*(\*?)\s*([\w-]+):$/)
                            if (m) { profiles.push(m[2]); if (m[1] === "*") active = m[2] }
                        }
                        col.availableProfiles = profiles
                        col.activeProfile = active
                    }
                }
            }

            Text {
                text: "System"
                color: Services.Colors.snow
                font.pixelSize: 20
                font.bold: true
                font.family: "JetBrainsMono NF"
            }

            // ── Battery + power profile ──
            RowLayout {
                spacing: 14
                Text {
                    text: Services.Battery.level + "%"
                    color: Services.Colors.snow
                    font.pixelSize: 24
                    font.bold: true
                    font.family: "JetBrainsMono NF"
                }
                ColumnLayout {
                    spacing: 2
                    Text {
                        text: Services.Battery.charging ? "Charging" : "On battery"
                        color: Services.Colors.mist
                        font.pixelSize: 11
                        font.family: "JetBrainsMono NF"
                    }
                    Text {
                        text: col.timeRemaining !== "--" ? col.timeRemaining : (Services.Battery.charging ? "Fully charged" : "Calculating...")
                        color: Services.Colors.ash
                        font.pixelSize: 10
                        font.family: "JetBrainsMono NF"
                    }
                }
            }

            SectionLabel { text: "Power Profile" }

            RowLayout {
                spacing: 10
                Repeater {
                    model: [
                        { id: "power-saver", icon: "", label: "Saver" },
                        { id: "balanced", icon: "", label: "Balanced" },
                        { id: "performance", icon: "", label: "Performance" },
                    ]
                    delegate: Rectangle {
                        required property var modelData
                        property bool available: col.availableProfiles.includes(modelData.id)
                        width: 100; height: 64
                        radius: 12
                        color: col.activeProfile === modelData.id ? Services.Colors.ghost : Services.Colors.ghostAlpha(0.12)
                        opacity: available ? 1.0 : 0.35
                        Behavior on color { ColorAnimation { duration: 150 } }
                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 4
                            Text {
                                text: modelData.icon
                                font.family: "Material Symbols Rounded"
                                font.pixelSize: 20
                                color: col.activeProfile === modelData.id ? Services.Colors.abyss : Services.Colors.mist
                                Layout.alignment: Qt.AlignHCenter
                            }
                            Text {
                                text: modelData.label
                                font.pixelSize: 10
                                font.family: "JetBrainsMono NF"
                                color: col.activeProfile === modelData.id ? Services.Colors.abyss : Services.Colors.mist
                                Layout.alignment: Qt.AlignHCenter
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: parent.available ? Qt.PointingHandCursor : Qt.ForbiddenCursor
                            enabled: parent.available
                            onClicked: col.setProfile(modelData.id)
                        }
                    }
                }
            }

            Divider {}

            // ── Audio + display ──
            SectionLabel { text: "Audio & Display" }

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

            SliderRow {
                glyph: ""
                label: "Brightness"
                value: Services.Brightness.level
                onMoved: pct => Quickshell.execDetached(["sh", "-c", "brightnessctl set " + pct + "%"])
            }

            Divider {}

            // ── Clock ──
            SectionLabel { text: "Clock" }

            RowLayout {
                Layout.fillWidth: true
                spacing: 12
                Text {
                    text: ""
                    font.family: "Material Symbols Rounded"
                    font.pixelSize: 18
                    color: Services.Colors.ghost
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    Text { text: "Time Format"; color: Services.Colors.snow; font.pixelSize: 13; font.family: "JetBrainsMono NF" }
                    Text {
                        text: col.timePreview
                        color: Services.Colors.ash
                        font.pixelSize: 10
                        font.family: "JetBrainsMono NF"
                    }
                }
                ChoiceRow {
                    options: [
                        { id: "24", label: "24H" },
                        { id: "12", label: "12H AM/PM" },
                    ]
                    current: Services.Prefs.clock24h ? "24" : "12"
                    onPicked: id => Services.Prefs.clock24h = (id === "24")
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 12
                Text {
                    text: ""
                    font.family: "Material Symbols Rounded"
                    font.pixelSize: 18
                    color: Services.Colors.ghost
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    Text { text: "Show Seconds"; color: Services.Colors.snow; font.pixelSize: 13; font.family: "JetBrainsMono NF" }
                    Text { text: "Ticks the clock every second"; color: Services.Colors.ash; font.pixelSize: 10; font.family: "JetBrainsMono NF" }
                }
                Toggle {
                    checked: Services.Prefs.clockSeconds
                    onToggled: Services.Prefs.clockSeconds = !Services.Prefs.clockSeconds
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 12
                Text {
                    text: ""
                    font.family: "Material Symbols Rounded"
                    font.pixelSize: 18
                    color: Services.Colors.ghost
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    Text { text: "Temperature"; color: Services.Colors.snow; font.pixelSize: 13; font.family: "JetBrainsMono NF" }
                    Text {
                        // The forecast API only speaks celsius; F and K are converted locally
                        text: "Now: " + Services.Weather.temp
                        color: Services.Colors.ash
                        font.pixelSize: 10
                        font.family: "JetBrainsMono NF"
                    }
                }
                ChoiceRow {
                    options: [
                        { id: "C", label: "°C" },
                        { id: "F", label: "°F" },
                        { id: "K", label: "K" },
                    ]
                    current: Services.Prefs.tempUnit
                    onPicked: id => Services.Prefs.tempUnit = id
                }
            }

            Divider {}

            // ── Keyboard ──
            RowLayout {
                Layout.fillWidth: true
                SectionLabel { text: "Keyboard Layout"; Layout.fillWidth: true }
                SectionLabel {
                    // XKB caps at 4 groups; past that they cannot be selected
                    text: Services.Keyboard.layouts.length + " / " + Services.Keyboard.maxLayouts
                    color: Services.Keyboard.canAdd ? Services.Colors.ash : Services.Colors.ghost
                }
            }

            Flow {
                Layout.fillWidth: true
                spacing: 10

                Repeater {
                    model: Services.Keyboard.layouts
                    delegate: Rectangle {
                        id: kbCard
                        required property var modelData
                        required property int index
                        readonly property bool active: Services.Keyboard.activeIndex === kbCard.index
                        width: 100; height: 64
                        radius: 12
                        color: kbCard.active ? Services.Colors.ghost : Services.Colors.ghostAlpha(0.12)
                        Behavior on color { ColorAnimation { duration: 150 } }
                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 4
                            Text {
                                text: "\ue312"
                                font.family: "Material Symbols Rounded"
                                font.pixelSize: 20
                                color: kbCard.active ? Services.Colors.abyss : Services.Colors.mist
                                Layout.alignment: Qt.AlignHCenter
                            }
                            Text {
                                text: kbCard.modelData.toUpperCase()
                                font.pixelSize: 10
                                font.family: "JetBrainsMono NF"
                                color: kbCard.active ? Services.Colors.abyss : Services.Colors.mist
                                Layout.alignment: Qt.AlignHCenter
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            hoverEnabled: true
                            onClicked: Services.Keyboard.setLayout(kbCard.index)
                        }
                        // Removing the last layout would leave a keyboard that
                        // types nothing, so the X only exists while there are 2+
                        Rectangle {
                            visible: Services.Keyboard.layouts.length > 1 && (kbCard.hovered || rmArea.containsMouse)
                            anchors.top: parent.top
                            anchors.right: parent.right
                            anchors.margins: 4
                            width: 18; height: 18
                            radius: 9
                            color: rmArea.containsMouse ? Services.Colors.error_ : Services.Colors.ghostAlpha(0.4)
                            Behavior on color { ColorAnimation { duration: 120 } }
                            Text {
                                anchors.centerIn: parent
                                text: "\ue5cd"
                                font.family: "Material Symbols Rounded"
                                font.pixelSize: 11
                                color: Services.Colors.abyss
                            }
                            MouseArea {
                                id: rmArea
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                hoverEnabled: true
                                onClicked: Services.Keyboard.removeLayout(kbCard.modelData)
                            }
                        }
                        property bool hovered: false
                        HoverHandler { onHoveredChanged: kbCard.hovered = hovered }
                    }
                }

                Rectangle {
                    id: addCard
                    width: 100; height: 64
                    radius: 12
                    color: addArea.containsMouse && Services.Keyboard.canAdd
                        ? Services.Colors.ghostAlpha(0.2) : Services.Colors.ghostAlpha(0.06)
                    border.color: Services.Colors.ghostAlpha(0.3)
                    border.width: 1
                    opacity: Services.Keyboard.canAdd ? 1.0 : 0.4
                    Behavior on color { ColorAnimation { duration: 150 } }
                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 4
                        Text {
                            text: "\ue145"
                            font.family: "Material Symbols Rounded"
                            font.pixelSize: 20
                            color: Services.Colors.ghost
                            Layout.alignment: Qt.AlignHCenter
                        }
                        Text {
                            text: "Add"
                            font.pixelSize: 10
                            font.family: "JetBrainsMono NF"
                            color: Services.Colors.mist
                            Layout.alignment: Qt.AlignHCenter
                        }
                    }
                    MouseArea {
                        id: addArea
                        anchors.fill: parent
                        cursorShape: Services.Keyboard.canAdd ? Qt.PointingHandCursor : Qt.ForbiddenCursor
                        hoverEnabled: true
                        enabled: Services.Keyboard.canAdd
                        onClicked: {
                            col.pickerOpen = !col.pickerOpen
                            if (col.pickerOpen) {
                                col.layoutQuery = ""
                                searchField.forceActiveFocus()
                            }
                        }
                    }
                }
            }

            Text {
                visible: !Services.Keyboard.canAdd
                text: "XKB allows 4 layouts at most -- remove one to add another"
                color: Services.Colors.ash
                font.pixelSize: 10
                font.family: "JetBrainsMono NF"
            }

            // ── Layout picker: 99 layouts, so it filters instead of listing ──
            Rectangle {
                Layout.fillWidth: true
                visible: col.pickerOpen
                radius: 12
                color: Services.Colors.ghostAlpha(0.08)
                implicitHeight: pickerCol.implicitHeight + 20

                ColumnLayout {
                    id: pickerCol
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 10
                    spacing: 8

                    Rectangle {
                        Layout.fillWidth: true
                        height: 34
                        radius: 8
                        color: Services.Colors.ghostAlpha(0.12)
                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            spacing: 8
                            Text {
                                text: "\ue8e2"
                                font.family: "Material Symbols Rounded"
                                font.pixelSize: 15
                                color: Services.Colors.ghost
                            }
                            TextField {
                                id: searchField
                                Layout.fillWidth: true
                                placeholderText: "Search layout..."
                                text: col.layoutQuery
                                onTextChanged: col.layoutQuery = text
                                color: Services.Colors.snow
                                placeholderTextColor: Services.Colors.ash
                                font.pixelSize: 12
                                font.family: "JetBrainsMono NF"
                                background: null
                                padding: 0
                                Keys.onEscapePressed: col.pickerOpen = false
                            }
                        }
                    }

                    Text {
                        visible: col.filteredLayouts.length === 0
                        text: "No layout matches \"" + col.layoutQuery + "\""
                        color: Services.Colors.ash
                        font.pixelSize: 11
                        font.family: "JetBrainsMono NF"
                    }

                    // Capped height: the unfiltered list is 99 entries long
                    ListView {
                        Layout.fillWidth: true
                        Layout.preferredHeight: Math.min(contentHeight, 168)
                        visible: col.filteredLayouts.length > 0
                        clip: true
                        model: col.filteredLayouts
                        boundsBehavior: Flickable.StopAtBounds
                        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded; width: 4 }

                        delegate: Rectangle {
                            required property var modelData
                            readonly property bool already: Services.Keyboard.layouts.includes(modelData.code)
                            width: ListView.view.width
                            height: 30
                            radius: 6
                            color: rowArea.containsMouse && !already
                                ? Services.Colors.ghostAlpha(0.18) : "transparent"
                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                spacing: 10
                                Text {
                                    text: modelData.code
                                    color: Services.Colors.ghost
                                    font.pixelSize: 11
                                    font.bold: true
                                    font.family: "JetBrainsMono NF"
                                    Layout.preferredWidth: 52
                                }
                                Text {
                                    text: modelData.name
                                    color: parent.parent.already ? Services.Colors.ash : Services.Colors.snow
                                    font.pixelSize: 11
                                    font.family: "JetBrainsMono NF"
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                                Text {
                                    visible: parent.parent.already
                                    text: "in use"
                                    color: Services.Colors.ash
                                    font.pixelSize: 9
                                    font.family: "JetBrainsMono NF"
                                }
                            }
                            MouseArea {
                                id: rowArea
                                anchors.fill: parent
                                hoverEnabled: true
                                enabled: !parent.already
                                cursorShape: parent.already ? Qt.ForbiddenCursor : Qt.PointingHandCursor
                                onClicked: {
                                    Services.Keyboard.addLayout(modelData.code)
                                    col.pickerOpen = false
                                }
                            }
                        }
                    }
                }
            }

            Text {
                text: Services.Keyboard.keymap
                color: Services.Colors.ash
                font.pixelSize: 10
                font.family: "JetBrainsMono NF"
            }

            Divider {}

            // ── Keep awake ──
            RowLayout {
                Layout.fillWidth: true
                spacing: 12
                Text {
                    text: ""
                    font.family: "Material Symbols Rounded"
                    font.pixelSize: 20
                    color: Services.AppState.keepAwake ? Services.Colors.ghost : Services.Colors.mist
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    Text { text: "Keep Awake"; color: Services.Colors.snow; font.pixelSize: 13; font.bold: true; font.family: "JetBrainsMono NF" }
                    Text { text: "Prevents auto-lock and screen dimming"; color: Services.Colors.ash; font.pixelSize: 10; font.family: "JetBrainsMono NF" }
                }
                Toggle {
                    checked: Services.AppState.keepAwake
                    onToggled: {
                        Services.AppState.keepAwake = !Services.AppState.keepAwake
                        if (Services.AppState.keepAwake) {
                            Quickshell.execDetached(["sh", "-c", "pkill -9 hypridle"])
                        } else {
                            Quickshell.execDetached(["sh", "-c", "hypridle"])
                        }
                    }
                }
            }

            Item { Layout.preferredHeight: 8 }
        }
    }
}
