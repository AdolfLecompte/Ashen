import QtQuick

import "root:/services" as Services

// One chip inside the system pill: wifi, bluetooth, volume, brightness,
// battery, keyboard. The caller says what it shows and what a click does; the
// fill, the hover, the expand and the pill-centre report are shared.
Rectangle {
    id: chip

    // AppState key the panel that belongs to this chip hangs off. Empty for a
    // chip nothing opens.
    property string pillKey: ""
    property string glyph: ""
    property string label: ""
    // On: filled with the accent, text goes dark.
    property bool active: false
    // Its panel is open — on a vertical bar that holds the chip expanded.
    property bool open: false
    property bool interactive: true
    // Overrides the label/glyph colour when the chip is neither on nor hovered
    // (the battery goes red below 20 %).
    property color idleColor: Services.Colors.ash
    // Optional width band for the label, off by default. Only the chips whose
    // text is a name — the network and the bluetooth device — need it; a
    // percentage is always the same handful of characters and clamping it just
    // padded the chip out for nothing.
    property real minLabelW: 0
    property real maxLabelW: 0

    signal activated()

    // While its panel is up the chip IS the panel, so it steps aside: the whole
    // chip, not just its contents, the way the clock and the media pill do.
    // Opacity, not `visible`: invisible keeps its slot, hidden would let the
    // strip close the gap and shove the other chips sideways.
    property bool takenOver: false
    onOpenChanged: {
        if (open) { handBack.stop(); handOver.restart() }
        else { handOver.stop(); handBack.restart() }
    }
    // The panel waits for its window to actually be on screen before it starts
    // to fall, so the chip has to wait the same beat before standing down. Left
    // to go the instant it was clicked, the bar went blank and only THEN did the
    // drop begin — a gap where nothing was moving anywhere.
    Timer {
        id: handOver
        interval: Services.Sizes.panelArmMs
        onTriggered: chip.takenOver = true
    }
    // Coming back it goes the other way: contents out, pieces home, then the
    // box. The chip is free a little before the drop is all the way in, so the
    // two meet rather than the chip waiting for an empty pill to be handed back.
    Timer {
        id: handBack
        interval: Services.Sizes.panelCloseMs - 40
        onTriggered: chip.takenOver = false
    }
    opacity: (takenOver && Services.Pills.wearsFace) ? 0.0 : 1.0
    Behavior on opacity { NumberAnimation { duration: Services.Sizes.msMicro } }

    // The panel wears this for the first frames of its fall.
    onGlyphChanged: chip.publishFace()
    onLabelChanged: chip.publishFace()
    Component.onCompleted: chip.publishFace()
    function publishFace() {
        if (pillKey !== "")
            Services.AppState.setPillFace(pillKey, glyph, label)
    }

    // Defaults to the bar's own orientation; a caller off the bar (the
    // utility pill, glued to whichever edge it landed on) overrides it.
    property bool vertical: Services.Sizes.barVertical
    readonly property bool hovered: hover.containsMouse
    readonly property bool expanded: vertical && (hovered || open)
    // Lit, the text is whichever of black and white can be read on the accent --
    // matugen hands the shell whatever the wallpaper had, so "the accent is
    // light" is not something to assume. The hover tint never takes dark text:
    // it is a wash, not a fill, and dark letters on it came out as a smudge.
    readonly property color contentColor: active
        ? Services.Colors.accentText
        : (hovered ? Services.Colors.snow : idleColor)

    radius: Services.Sizes.innerR
    width: vertical ? Services.Sizes.innerH : inner.width + 16
    height: vertical ? (expanded ? Services.Sizes.innerH + 13 : Services.Sizes.innerH)
                     : Services.Sizes.innerH
    Behavior on height { NumberAnimation { duration: Services.Sizes.msStandard; easing.type: Services.Sizes.easeOut } }

    // The plate does not react. Hover is the chip growing and its contents
    // lifting to snow -- nothing lights up underneath them.
    color: active ? Services.Colors.ghost : Services.Colors.fillRest
    gradient: Services.Prefs.useGradients && active ? Services.Colors.accentGradient : null
    Behavior on color { ColorAnimation { duration: Services.Sizes.msEmphasis } }

    // The bar's one hover language, from Sizes.
    scale: Services.Sizes.hoverScale(hovered, hover.pressed)
    Behavior on scale { NumberAnimation { duration: Services.Sizes.pillHoverMs; easing.type: Services.Sizes.easeOut } }

    MouseArea {
        id: hover
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: chip.interactive ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: if (chip.interactive) chip.activated()
    }

    // Only a chip with a panel behind it needs to publish where it is.
    Loader {
        active: chip.pillKey !== ""
        sourceComponent: PillCenter { key: chip.pillKey; pill: chip }
    }

    BarStrip {
        id: inner
        anchors.centerIn: parent
        spacing: chip.vertical ? 0 : 5
        Text {
            id: glyphText
            text: chip.glyph
            color: chip.contentColor
            font.pixelSize: 18
            font.family: "Material Symbols Rounded"
            Behavior on color { ColorAnimation { duration: Services.Sizes.msStandard } }

            // A swapped glyph pops rather than cutting: the volume icon changes
            // between headphones and speaker often enough to notice.
            transform: Scale {
                id: popScale
                origin.x: glyphText.width / 2
                origin.y: glyphText.height / 2
            }
            onTextChanged: pop.restart()
            ParallelAnimation {
                id: pop
                NumberAnimation { target: glyphText; property: "opacity"; from: 0.0; to: 1.0; duration: 180; easing.type: Services.Sizes.easeOut }
                NumberAnimation { target: popScale; property: "xScale"; from: 0.7; to: 1.0; duration: 200; easing.type: Services.Sizes.easeOut }
                NumberAnimation { target: popScale; property: "yScale"; from: 0.7; to: 1.0; duration: 200; easing.type: Services.Sizes.easeOut }
            }
        }

        Text {
            text: chip.label
            color: chip.contentColor
            // Floor and ceiling on the width: the chip is where the panel hangs from,
            // so a long SSID used to drag the open panel across the screen and "Off"
            // used to snap it narrow. Past the ceiling the name trails off.
            width: chip.maxLabelW > 0
                ? Math.max(chip.minLabelW, Math.min(implicitWidth, chip.maxLabelW))
                : implicitWidth
            elide: chip.maxLabelW > 0 ? Text.ElideRight : Text.ElideNone
            // Sideways there is no room for the words. Zero text, not an empty label:
            // an empty one still counted as a lane in BarStrip's Grid and reserved the
            // spacing after the glyph, leaving the icon off-centre in its own chip.
            visible: chip.label !== "" && (!chip.vertical || chip.expanded)
            font.pixelSize: chip.vertical ? 9 : 12
            font.family: "JetBrainsMono NF"
            font.bold: true
            Behavior on color { ColorAnimation { duration: Services.Sizes.msStandard } }
        }
    }
}
