import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import "root:/services" as Services
import "root:/modules/settings/components"
import "root:/modules/widgets" as Widgets

// Screen output: how the monitors are arranged, brightness, and the
// blue-light filter.
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

    // Which monitor the settings beside the board are talking about. The
    // machine's own panel to begin with, so the column is never a blank waiting
    // for a click.
    property string sel: Services.Displays.primaryKey
    readonly property var selMon: tab.sel === "" ? null : Services.Displays.byKey(tab.sel)
    readonly property var selEnt: tab.sel === "" ? null : Services.Displays.entry(tab.sel)

    function patch(o) { if (tab.sel !== "") Services.Displays.setEntry(tab.sel, o) }


    readonly property string primaryKey: Services.Displays.primaryKey
    readonly property string primaryName: {
        const m = Services.Displays.byKey(tab.primaryKey)
        return m ? m.name : tab.primaryKey
    }

    // Only a secondary screen may mirror, and the only thing worth mirroring is
    // the screen you are sitting in front of.
    readonly property bool canMirror:
        tab.sel !== "" && tab.primaryKey !== "" && tab.sel !== tab.primaryKey

    // Position, mode, scale and rotation are all meaningless while a screen is
    // showing somebody else's picture.
    readonly property bool geometryLive: tab.selEnt ? tab.selEnt.mirror === "" : false

    // A field's name, above the control instead of beside it: the column is
    // half the card wide and a label in front of a Segmented would eat it.
    component FieldLabel: Text {
        property bool dim: false
        Layout.fillWidth: true
        Layout.topMargin: 2
        color: Services.Colors.mist
        opacity: dim ? 0.4 : 1
        font.pixelSize: Services.Sizes.fsMeta
        font.family: "JetBrainsMono NF"
    }

    // ── The board, the screen it points at, and what you can do to it ────
    // The 3x3 board says WHERE the screens are and the preview beside it says
    // what the selected one looks like -- two halves of one question, so they
    // share a row. Everything you can CHANGE goes underneath at full width:
    // the old half-column made every control a slot too narrow to read.
    Card {
        title: "Monitors"

        RowLayout {
            Layout.fillWidth: true
            spacing: 18

            MonitorGrid {
                Layout.alignment: Qt.AlignTop
                selected: tab.sel
                onPicked: key => tab.sel = key
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignTop
                spacing: 2

                Item {
                    Layout.fillWidth: true
                    // The box follows the SCALE and nothing else. It used to be sized
                    // from the panel, so picking another monitor or another resolution
                    // made the whole section jump -- and the one thing this preview is
                    // not about is which numbers the mode has.
                    Layout.preferredHeight: rig.ext + rig.standH + 16
                    Behavior on Layout.preferredHeight { NumberAnimation { duration: Services.Sizes.msEmphasis; easing.type: Services.Sizes.easeOut } }

                    Item {
                        id: rig
                        anchors.centerIn: parent
                        width: Math.max(rig.ext, rig.bodyW)
                        height: rig.ext + rig.standH

                        // The panel's own proportions. NOT the logical size: that
                        // divides by the scale, which would draw a bigger scale smaller.
                        readonly property var mode: tab.selMon
                            ? Services.Displays.modeSize(tab.selMon, tab.selEnt) : { w: 16, h: 9 }
                        // One size, always. A preview that grew with the scale
                        // made the whole section jump every time you stepped the
                        // ladder, and the scale is a number you read, not a shape.
                        readonly property real longest: 230
                        // The panel's LONGEST side is always `longest`, whatever shape
                        // it is, so a 16:9 and a 4:3 fill the same square and switching
                        // between two monitors does not resize anything.
                        readonly property real aspect: rig.mode.w / rig.mode.h
                        readonly property real bodyW: rig.aspect >= 1 ? rig.longest : rig.longest * rig.aspect
                        readonly property real bodyH: rig.aspect >= 1 ? rig.longest / rig.aspect : rig.longest
                        // The square the panel turns inside, so a portrait turn has
                        // somewhere to go. Fixed by `longest`, never by the mode.
                        readonly property real ext: rig.longest
                        readonly property real standH: 26

                        Behavior on width { NumberAnimation { duration: Services.Sizes.msEmphasis; easing.type: Services.Sizes.easeOut } }
                        Behavior on height { NumberAnimation { duration: Services.Sizes.msEmphasis; easing.type: Services.Sizes.easeOut } }

                        opacity: tab.selEnt && tab.selEnt.disabled ? 0.4 : 1.0
                        Behavior on opacity { NumberAnimation { duration: Services.Sizes.msStandard } }

                        // The stand stays on the desk: on a real pivot monitor the
                        // neck is fixed and the panel turns on it. It hangs off
                        // whichever edge is the lower one, so a turned screen does
                        // not float above its own pole -- and its LENGTH never
                        // changes, which is what used to read as a stretch.
                        // Drawn first, so the panel covers the part behind it.
                        readonly property real neckTop: rig.ext / 2 + ((tab.selEnt
                            && (tab.selEnt.transform === 1 || tab.selEnt.transform === 3))
                            ? rig.bodyW / 2 : rig.bodyH / 2)
                        readonly property real neckLen: 16

                        Rectangle {
                            width: 13
                            radius: 3
                            x: (rig.width - width) / 2
                            y: rig.neckTop
                            height: rig.neckLen
                            Behavior on y { NumberAnimation { duration: Services.Sizes.msEmphasis; easing.type: Services.Sizes.easeInOut } }
                            // Solid, not a wash of the accent: two translucent parts
                            // laid over each other showed the neck through the screen.
                            color: Services.Colors.tint(Services.Colors.surface, Services.Colors.ghost, 0.16)
                        }
                        Rectangle {
                            width: Math.max(56, rig.longest * 0.34)
                            height: 6
                            radius: 3
                            x: (rig.width - width) / 2
                            y: rig.neckTop + rig.neckLen
                            Behavior on y { NumberAnimation { duration: Services.Sizes.msEmphasis; easing.type: Services.Sizes.easeInOut } }
                            color: Services.Colors.tint(Services.Colors.surface, Services.Colors.ghost, 0.16)
                        }

                        Rectangle {
                            id: panel
                            width: rig.bodyW
                            height: rig.bodyH
                            x: (rig.width - width) / 2
                            y: (rig.ext - height) / 2
                            Behavior on x { NumberAnimation { duration: Services.Sizes.msEmphasis; easing.type: Services.Sizes.easeOut } }
                            Behavior on y { NumberAnimation { duration: Services.Sizes.msEmphasis; easing.type: Services.Sizes.easeOut } }

                            // Only this turns, about its own middle -- which is where a
                            // pivot arm actually holds a screen.
                            rotation: tab.selEnt ? tab.selEnt.transform * 90 : 0
                            Behavior on rotation { NumberAnimation { duration: Services.Sizes.msEmphasis; easing.type: Services.Sizes.easeInOut } }

                            radius: Services.Sizes.cardR
                            color: Services.Colors.tint(Services.Colors.surface, Services.Colors.ghost, 0.30)
                            border.width: 1
                            border.color: Services.Colors.tint(Services.Colors.surface, Services.Colors.ghost, 0.42)

                            // The screen inside the chassis: thin bezel on three
                            // sides, a deeper chin under it, the way a panel is
                            // actually built.
                            Rectangle {
                                id: screen
                                anchors.fill: parent
                                anchors.margins: 5
                                anchors.bottomMargin: 13
                                radius: Services.Sizes.innerR - 2
                                color: Services.Colors.tint(Services.Colors.surface, Services.Colors.ghost, 0.13)
                            }

                            // The power light. One dot, off-centre by nothing:
                            // it is the only thing in the chin.
                            Rectangle {
                                width: 4
                                height: 4
                                radius: 2
                                x: (panel.width - width) / 2
                                y: panel.height - 9
                                color: tab.selEnt && tab.selEnt.disabled
                                    ? Services.Colors.tint(Services.Colors.surface, Services.Colors.ghost, 0.45)
                                    : Services.Colors.ghost
                                Behavior on color { ColorAnimation { duration: Services.Sizes.msStandard } }
                            }

                            ColumnLayout {
                                anchors.centerIn: screen
                                width: screen.width - 12
                                spacing: 2
                                Text {
                                    Layout.fillWidth: true
                                    horizontalAlignment: Text.AlignHCenter
                                    elide: Text.ElideRight
                                    text: tab.selMon ? tab.selMon.name : ""
                                    color: Services.Colors.snow
                                    font.pixelSize: Services.Sizes.fsBody
                                    font.bold: true
                                    font.family: "JetBrainsMono NF"
                                }
                                Text {
                                    Layout.fillWidth: true
                                    horizontalAlignment: Text.AlignHCenter
                                    elide: Text.ElideRight
                                    text: Math.round(rig.mode.w) + "×" + Math.round(rig.mode.h)
                                    color: Services.Colors.mist
                                    font.pixelSize: Services.Sizes.fsCaption
                                    font.family: "JetBrainsMono NF"
                                }
                            }
                        }
                    }
                }


                Text {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    text: tab.selMon ? tab.selMon.name : ""
                    color: Services.Colors.snow
                    font.pixelSize: Services.Sizes.fsCardTitle
                    font.bold: true
                    font.family: "JetBrainsMono NF"
                }
                Text {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: tab.selEnt
                        ? ("×" + tab.selEnt.scale + "  ·  "
                           + ["Normal", "90°", "180°", "270°"][tab.selEnt.transform])
                        : ""
                    color: Services.Colors.ash
                    font.pixelSize: Services.Sizes.fsMeta
                    font.family: "JetBrainsMono NF"
                }
            }
        }
    }

    // Everything about the selected screen, two controls to a row so a label
    // and its control are never fighting for the same 200 px.
    Card {
        title: tab.selMon ? tab.selMon.name : "Selected screen"

        Text {
            Layout.fillWidth: true
            text: tab.sel
            color: Services.Colors.ash
            font.pixelSize: Services.Sizes.fsCaption
            font.family: "JetBrainsMono NF"
            elide: Text.ElideRight
        }

        GridLayout {
            Layout.fillWidth: true
            Layout.topMargin: 4
            columns: 2
            columnSpacing: 20
            rowSpacing: 10

            // Only a secondary screen may mirror, and the only thing worth
            // mirroring is the one you are sitting in front of. Mirroring an
            // external onto the laptop panel is the backwards version of the
            // same request, so the row is simply absent on the primary.
            ColumnLayout {
                Layout.columnSpan: 2
                Layout.fillWidth: true
                spacing: 4
                visible: tab.canMirror

                FieldLabel { text: "Use" }
                Segmented {
                    Layout.fillWidth: true
                    options: [
                        { id: "extend", label: "Extended" },
                        { id: tab.primaryKey, label: "Mirror " + tab.primaryName }
                    ]
                    current: tab.selEnt ? (tab.selEnt.mirror === "" ? "extend" : tab.selEnt.mirror) : "extend"
                    onPicked: id => tab.patch({ mirror: id === "extend" ? "" : id })
                }
            }

            // A list, not a stepper: the modes are the one thing here you
            // have to READ, and a pair of arrows shows you exactly one of
            // them at a time.
            ColumnLayout {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                Layout.alignment: Qt.AlignTop
                spacing: 4

                FieldLabel { text: "Resolution"; dim: !tab.geometryLive }
                Widgets.DevicePicker {
                    Layout.fillWidth: true
                    overlay: true
                    enabled: tab.geometryLive
                    opacity: enabled ? 1 : 0.4
                    glyph: ""
                    devices: {
                        const out = [{ name: "preferred", desc: "Preferred" }]
                        const modes = tab.selMon && tab.selMon.availableModes ? tab.selMon.availableModes : []
                        for (const m of modes) out.push({ name: m, desc: m })
                        return out
                    }
                    current: tab.selEnt ? tab.selEnt.mode : "preferred"
                    onPicked: name => tab.patch({ mode: name })
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                Layout.alignment: Qt.AlignTop
                spacing: 4

                FieldLabel { text: "Scale"; dim: !tab.geometryLive }
                Widgets.DevicePicker {
                    Layout.fillWidth: true
                    overlay: true
                    enabled: tab.geometryLive
                    opacity: enabled ? 1 : 0.4
                    glyph: ""
                    devices: {
                        const out = []
                        const s = tab.selMon ? Services.Displays.modeSize(tab.selMon, tab.selEnt) : null
                        const list = s ? Services.Displays.validScales(s.w, s.h) : [1]
                        for (const v of list) out.push({ name: String(v), desc: "×" + v })
                        return out
                    }
                    current: tab.selEnt ? String(tab.selEnt.scale) : "1"
                    onPicked: name => tab.patch({ scale: parseFloat(name) })
                }
            }

            ColumnLayout {
                Layout.columnSpan: 2
                Layout.fillWidth: true
                spacing: 4

                FieldLabel { text: "Rotation"; dim: !tab.geometryLive }
                Segmented {
                    Layout.fillWidth: true
                    enabled: tab.geometryLive
                    opacity: enabled ? 1 : 0.4
                    options: [
                        { id: "0", label: "Normal" },
                        { id: "1", label: "90°" },
                        { id: "2", label: "180°" },
                        { id: "3", label: "270°" }
                    ]
                    current: tab.selEnt ? String(tab.selEnt.transform) : "0"
                    onPicked: id => tab.patch({ transform: parseInt(id) })
                }
            }

            // The last screen standing cannot be switched off, or there is
            // nowhere left to switch it back on from.
            RowLayout {
                Layout.columnSpan: 2
                Layout.fillWidth: true
                Layout.topMargin: 2
                spacing: 10
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    Text {
                        text: "Enabled"
                        color: Services.Colors.snow
                        font.pixelSize: Services.Sizes.fsInput; font.bold: true; font.family: "JetBrainsMono NF"
                    }
                    Text {
                        text: tab.onlyOneLeft ? "The only screen left on" : "Turn this screen off entirely"
                        color: Services.Colors.ash
                        font.pixelSize: Services.Sizes.fsMeta; font.family: "JetBrainsMono NF"
                    }
                }
                Item { Layout.fillWidth: true }
                Toggle {
                    enabled: !tab.onlyOneLeft
                    opacity: enabled ? 1 : 0.4
                    checked: tab.selEnt ? !tab.selEnt.disabled : true
                    onToggled: tab.patch({ disabled: tab.selEnt ? !tab.selEnt.disabled : false })
                }
            }
        }

        // Apply puts the edited layout on screen. One button: the countdown ask
        // ("keep it or it goes back") is still in the service for the keybind,
        // but on a panel you can see and click it was two extra decisions.
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 4
            spacing: 10

            Text {
                Layout.fillWidth: true
                text: "Changes are not live until you apply them"
                color: Services.Colors.ash
                font.pixelSize: Services.Sizes.fsMeta
                font.family: "JetBrainsMono NF"
            }

            ActionBtn {
                accent: true
                label: "Apply"
                onGo: Services.Displays.applyAll()
            }
        }
    }

    // Its own box, full width: ten chips in half a column would be a huddle,
    // and which workspaces a screen owns is a different question from how the
    // screen is set up.
    Card {
        title: "Workspaces"

        Text {
            Layout.fillWidth: true
            text: tab.selEnt && tab.selEnt.ws.length > 0
                ? (tab.selMon ? tab.selMon.name + " opens on " + tab.selEnt.defaultWs : "")
                : "Unassigned ones go wherever they are opened"
            color: Services.Colors.ash
            font.pixelSize: Services.Sizes.fsMeta
            font.family: "JetBrainsMono NF"
        }

        Flow {
            Layout.fillWidth: true
            spacing: 6
            enabled: tab.selEnt ? (tab.selEnt.mirror === "" && !tab.selEnt.disabled) : false
            opacity: enabled ? 1 : 0.4
            Repeater {
                // Ten, not nine: SUPER+0 is workspace 10 and it was missing.
                model: 10
                delegate: WsChip {
                    required property int index
                    n: index + 1
                }
            }
        }
    }

    // Whether the selected screen is the last one still on: turning it off
    // would leave nothing to turn it back on from.
    readonly property bool onlyOneLeft: {
        if (tab.sel === "") return true
        if (tab.selEnt && tab.selEnt.disabled) return false
        let on = 0
        for (const m of Services.Displays.monitors)
            if (!Services.Displays.entry(Services.Displays.keyOf(m)).disabled) on += 1
        return on <= 1
    }

    // Step through the modes the panel actually reports, wrapping. "preferred"
    // is index 0 and stays as the honest default.
    function cycleMode(dir) {
        if (!tab.selMon) return
        const modes = ["preferred"].concat(tab.selMon.availableModes || [])
        let i = modes.indexOf(tab.selEnt.mode)
        if (i < 0) i = 0
        tab.patch({ mode: modes[(i + dir + modes.length) % modes.length] })
    }

    function cycleScale(dir) {
        if (!tab.selMon) return
        const s = Services.Displays.modeSize(tab.selMon, tab.selEnt)
        const list = Services.Displays.validScales(s.w, s.h)
        let i = list.indexOf(tab.selEnt.scale)
        if (i < 0) i = 0
        tab.patch({ scale: list[(i + dir + list.length) % list.length] })
    }

    // One workspace number. Tapping claims it for the selected screen or gives
    // it back; tapping one this screen already owns makes it the one the screen
    // opens on, so the default never needs a control of its own.
    // Built like the workspace chip on the bar, because it is the same thing:
    // the plate says whether the workspace is spoken for, the accent says which
    // one the screen opens on, and hover grows it instead of lighting it.
    component WsChip: Item {
        id: chip
        property int n: 0
        readonly property string owner: Services.Displays.ownerOf(chip.n)
        readonly property bool mine: chip.owner === tab.sel && tab.sel !== ""
        readonly property bool taken: chip.owner !== "" && !chip.mine
        readonly property bool isDefault: chip.mine && tab.selEnt && tab.selEnt.defaultWs === chip.n
        readonly property bool warm: wsHover.containsMouse

        width: Services.Sizes.innerH
        height: Services.Sizes.innerH
        scale: Services.Sizes.hoverScale(chip.warm, wsHover.pressed)
        Behavior on scale { NumberAnimation { duration: Services.Sizes.pillHoverMs; easing.type: Services.Sizes.easeOut } }
        // Spoken for by another screen: still readable, plainly not yours.
        opacity: chip.taken ? 0.4 : 1.0

        Rectangle {
            anchors.fill: parent
            radius: Services.Sizes.innerR
            color: chip.isDefault ? Services.Colors.ghost : Services.Colors.fillRest
            gradient: Services.Prefs.useGradients && chip.isDefault ? Services.Colors.accentGradient : null
            // Unclaimed numbers keep their outline and nothing else, so the
            // ones this screen owns are the only filled things in the row.
            opacity: chip.mine ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Services.Sizes.msStandard } }
            Behavior on color { ColorAnimation { duration: Services.Sizes.msStandard } }
        }
        Rectangle {
            anchors.fill: parent
            radius: Services.Sizes.innerR
            color: "transparent"
            border.width: 1
            border.color: Services.Colors.fillLine
            opacity: chip.mine ? 0 : 1
            Behavior on opacity { NumberAnimation { duration: Services.Sizes.msStandard } }
        }

        Text {
            anchors.centerIn: parent
            text: chip.n
            color: chip.isDefault ? Services.Colors.accentText
                 : chip.warm ? Services.Colors.snow
                 : chip.mine ? Services.Colors.surfaceText : Services.Colors.ash
            font.pixelSize: Services.Sizes.fsBody
            font.bold: true
            font.family: "JetBrainsMono NF"
            Behavior on color { ColorAnimation { duration: Services.Sizes.msStandard } }
        }

        MouseArea {
            id: wsHover
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (tab.sel === "") return
                if (chip.mine && !chip.isDefault) tab.patch({ defaultWs: chip.n })
                else Services.Displays.assignWorkspace(tab.sel, chip.n, !chip.mine)
            }
        }
    }

    // A button with a word in it. `IconButton` is a glyph in a box and cannot
    // hold one, and Apply has to say what it does -- but the gesture is the
    // shell's: it grows under the pointer and its label brightens.
    component ActionBtn: Rectangle {
        id: btn
        property string label: ""
        property bool accent: false
        signal go()
        readonly property bool warm: hov.containsMouse

        // Wide enough to read as the end of the card rather than a chip stuck
        // to the corner: this is the one control here that does anything.
        implicitWidth: Math.max(112, btnText.implicitWidth + 40)
        implicitHeight: 34
        radius: Services.Sizes.innerR
        color: btn.accent ? Services.Colors.ghost : Services.Colors.fillRest
        gradient: Services.Prefs.useGradients && btn.accent ? Services.Colors.accentGradient : null
        scale: Services.Sizes.hoverScale(btn.warm, hov.pressed)
        Behavior on scale { NumberAnimation { duration: Services.Sizes.pillHoverMs; easing.type: Services.Sizes.easeOut } }
        Behavior on color { ColorAnimation { duration: Services.Sizes.msStandard } }

        Text {
            id: btnText
            anchors.centerIn: parent
            text: btn.label
            color: btn.accent ? Services.Colors.accentText
                 : btn.warm ? Services.Colors.snow : Services.Colors.surfaceText
            font.pixelSize: Services.Sizes.fsBody
            font.bold: true
            font.family: "JetBrainsMono NF"
            Behavior on color { ColorAnimation { duration: Services.Sizes.msStandard } }
        }
        MouseArea {
            id: hov
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: btn.go()
        }
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
                    Text { text: "Night Light"; color: Services.Colors.snow; font.pixelSize: Services.Sizes.fsInput; font.bold: true; font.family: "JetBrainsMono NF" }
                    Text { text: "Warms screen colors to ease eye strain"; color: Services.Colors.ash; font.pixelSize: Services.Sizes.fsMeta; font.family: "JetBrainsMono NF" }
                }
                Item { Layout.fillWidth: true }
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
                        Text { text: "Temperature"; color: Services.Colors.snow; font.pixelSize: Services.Sizes.fsInput; font.bold: true; font.family: "JetBrainsMono NF" }
                        Text {
                            text: Services.NightLight.temperature + "K · " + (Services.NightLight.temperature <= 3500 ? "warmer" : Services.NightLight.temperature >= 5000 ? "subtle" : "balanced")
                            color: Services.Colors.ash; font.pixelSize: Services.Sizes.fsMeta; font.family: "JetBrainsMono NF"
                        }
                    }
                    Item { Layout.fillWidth: true }
                    StepBtn {
                        glyph: ""
                        onClicked: Services.NightLight.setTemperature(Math.max(2500, Services.NightLight.temperature - 250))
                    }
                    Item { Layout.fillWidth: true }
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
                        Text { text: "Auto schedule"; color: Services.Colors.snow; font.pixelSize: Services.Sizes.fsInput; font.bold: true; font.family: "JetBrainsMono NF" }
                        Text { text: Services.NightLight.scheduled ? "On between the times below" : "On constantly while enabled"; color: Services.Colors.ash; font.pixelSize: Services.Sizes.fsMeta; font.family: "JetBrainsMono NF" }
                    }
                    Item { Layout.fillWidth: true }
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
                        Text { text: "From"; color: Services.Colors.snow; font.pixelSize: Services.Sizes.fsInput; font.bold: true; font.family: "JetBrainsMono NF"; Layout.preferredWidth: 40 }
                        Text { text: Services.NightLight.fromTime; color: Services.Colors.ghost; font.pixelSize: Services.Sizes.fsInput; font.bold: true; font.family: "JetBrainsMono NF" }
                        Item { Layout.fillWidth: true }
                        StepBtn {
                            glyph: ""
                            onClicked: Services.NightLight.setFrom(tab.stepTime(Services.NightLight.fromTime, -30))
                        }
                        Item { Layout.fillWidth: true }
                        StepBtn {
                            glyph: ""
                            onClicked: Services.NightLight.setFrom(tab.stepTime(Services.NightLight.fromTime, 30))
                        }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10
                        Text { text: "To"; color: Services.Colors.snow; font.pixelSize: Services.Sizes.fsInput; font.bold: true; font.family: "JetBrainsMono NF"; Layout.preferredWidth: 40 }
                        Text { text: Services.NightLight.toTime; color: Services.Colors.ghost; font.pixelSize: Services.Sizes.fsInput; font.bold: true; font.family: "JetBrainsMono NF" }
                        Item { Layout.fillWidth: true }
                        StepBtn {
                            glyph: ""
                            onClicked: Services.NightLight.setTo(tab.stepTime(Services.NightLight.toTime, -30))
                        }
                        Item { Layout.fillWidth: true }
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
