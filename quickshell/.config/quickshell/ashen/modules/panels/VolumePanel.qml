import Quickshell
import Quickshell.Io
import QtQuick
import "root:/services" as Services
import "root:/modules/widgets" as Widgets

// Sound, as one thing with two sides rather than two stacked copies of the
// same three controls. The dial says what the level is right now; the two
// categories under it say whose level that is. Output and input have the same
// layout, the same slider in the same place and the same device list -- only
// the icons and the devices differ -- so moving between them moves nothing on
// the screen except the reading.
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

    // Which side you are looking at. `shownCat` is what the body below the
    // tabs is actually showing: it changes at the bottom of the cross-fade, or
    // the sliders and the device list would swap under a body still at full
    // opacity and the change would read as a flicker instead of a turn.
    property string cat: "output"
    property string shownCat: "output"
    onCatChanged: swap.restart()

    readonly property bool isOut: win.cat === "output"
    readonly property int level: win.isOut ? Services.Audio.volume : Services.Audio.micVolume
    readonly property bool muted: win.isOut ? Services.Audio.muted : Services.Audio.micMuted
    // The output glyph is read off the bar chip, never rebuilt here: that set
    // has a headphones variant, and a second copy of the rule went out of step
    // with it the moment headphones were plugged in.
    readonly property string catGlyph: win.isOut
        ? Services.AppState.pillGlyph("volume")
        : (Services.Audio.micMuted ? "\ue02b" : "\ue31d")

    function setLevel(ratio) {
        ratio = Math.max(0, Math.min(1, ratio))
        const pct = Math.round(ratio * 100)
        if (win.isOut) {
            Quickshell.execDetached(["sh", "-c",
                "wpctl set-mute @DEFAULT_AUDIO_SINK@ 0 && wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ " + pct + "%"])
        } else {
            Services.Audio.setMicVolume(pct)
        }
    }
    function toggleMute() {
        if (win.isOut) Services.Audio.toggleMute()
        else Services.Audio.toggleMicMute()
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
        // The chip's speaker glyph lands on the dial's, its reading in the
        // middle of the dial: the same two things, moved.
        glyphTarget: dial.glyphItem
        labelTarget: dial.labelItem
        pillW: Services.AppState.volumePillW
        pillH: Services.AppState.volumePillH
        openW: 320
        openH: col.implicitHeight + 32
        cardRadius: 16

        SequentialAnimation {
            id: swap
            NumberAnimation { target: body; property: "opacity"; to: 0; duration: 110 }
            PropertyAction { target: win; property: "shownCat"; value: win.cat }
            NumberAnimation { target: body; property: "opacity"; to: 1; duration: 200; easing.type: Easing.OutCubic }
        }

        Column {
            id: col
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 16
            spacing: 14
            opacity: card.contentAmt

            // ── The dial ───────────────────────────────────────────────────
            // Reading in the middle, level around the rim. It follows the
            // category immediately, so switching sides is one needle moving
            // rather than a number being replaced.
            //
            // Mute lands in the caption line, which is always reserved: the
            // number keeps its size and its place. Swapping the number itself
            // for the word "Muted" resized the middle of the dial and pushed
            // everything around it -- that was the layout coming apart.
            Widgets.DialGauge {
                id: dial
                anchors.horizontalCenter: parent.horizontalCenter
                size: 132
                // Off the SLIDER, not off the service. Audio only polls once
                // a second, so a dial reading the service sat up to a second
                // behind the bar you were dragging -- the two showed different
                // numbers for the same thing. SliderTrack already solves this:
                // while you drag, its `shown` is the local position and it
                // holds it until the service catches up.
                value: levelBar.shown
                easeMs: levelBar.dragging ? 0 : 220
                glyph: win.catGlyph
                label: Math.round(dial.frac * 100) + "%"
                caption: win.muted ? "Muted" : ""
                hideGlyph: card.morphingGlyph
                hideLabel: card.morphingLabel
                fillColor: win.muted ? Services.Colors.mist : Services.Colors.ghost
                onTapped: win.toggleMute()
            }

            // ── The two sides ──────────────────────────────────────────────
            // Horizontal, and one accent that travels between them rather than
            // a plate per tab lighting up -- the movement is what says which
            // one you picked.
            Item {
                id: tabs
                width: parent.width
                height: 30

                readonly property var ids: ["output", "input"]
                readonly property real slotW: (width - 4) / 2

                Rectangle {
                    width: tabs.slotW
                    height: parent.height
                    radius: 8
                    x: win.cat === "input" ? tabs.slotW + 4 : 0
                    color: Services.Colors.ghost
                    gradient: Services.Prefs.useGradients ? Services.Colors.accentGradient : null
                    Behavior on x { SmoothedAnimation { duration: 260 } }
                }

                Row {
                    anchors.fill: parent
                    spacing: 4

                    Repeater {
                        model: [
                            { id: "output", label: "Output", glyph: "\ue050" },
                            { id: "input",  label: "Input",  glyph: "\ue31d" },
                        ]
                        delegate: Item {
                            id: tab
                            required property var modelData
                            readonly property bool active: win.cat === modelData.id
                            width: tabs.slotW
                            height: tabs.height

                            readonly property color fg: tab.active
                                ? Services.Colors.onColor(Services.Colors.ghost)
                                : (tabHover.containsMouse ? Services.Colors.snow : Services.Colors.mist)

                            Row {
                                anchors.centerIn: parent
                                spacing: 6
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: tab.modelData.glyph
                                    color: tab.fg
                                    font.family: "Material Symbols Rounded"
                                    font.pixelSize: 15
                                    Behavior on color { ColorAnimation { duration: Services.Sizes.msMicro } }
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: tab.modelData.label
                                    color: tab.fg
                                    font.pixelSize: 11
                                    font.bold: true
                                    font.family: "JetBrainsMono NF"
                                    Behavior on color { ColorAnimation { duration: Services.Sizes.msMicro } }
                                }
                            }

                            MouseArea {
                                id: tabHover
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: win.cat = tab.modelData.id
                            }
                        }
                    }
                }
            }

            // ── The side you picked ────────────────────────────────────────
            // One slider and one device list, told which side they belong to.
            // Two of each, shown and hidden, would be two things to keep in
            // step for a panel that only ever shows one of them.
            Column {
                id: body
                width: parent.width
                spacing: 10

                readonly property bool out: win.shownCat === "output"

                Widgets.SliderTrack {
                    id: levelBar
                    width: parent.width
                    knobSize: 18
                    knobBorder: 1
                    knobBorderColor: Services.Colors.ghostAlpha(0.45)
                    hitMargin: 14
                    dimmed: win.muted
                    fillColor: win.muted ? Services.Colors.mist : Services.Colors.ghost
                    value: (body.out ? Services.Audio.volume : Services.Audio.micVolume) / 100
                    onMoved: r => win.setLevel(r)
                }

                Widgets.DevicePicker {
                    width: parent.width
                    glyph: body.out ? "\ue050" : "\ue029"
                    devices: body.out ? Services.Audio.sinks : Services.Audio.sources
                    current: body.out ? Services.Audio.defaultSink : Services.Audio.defaultSource
                    onPicked: name => body.out ? Services.Audio.setSink(name)
                                               : Services.Audio.setSource(name)
                }
            }
        }
    }
}
