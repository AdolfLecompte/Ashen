import QtQuick

import "root:/services" as Services

// One chip inside the system pill: wifi, bluetooth, volume, brightness,
// battery, keyboard. They were six copies of the same forty lines in one file,
// which is why nothing could be changed in one of them without reading all six.
//
// The caller says what it shows (glyph, label), whether it counts as on
// (`active`), and what a click means. Everything else — the fill, the hover
// grow, the vertical expand, the pill-centre report the panel hangs off — is
// the same for all of them and lives here.
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

    // While its panel is up the chip IS the panel: it steps aside so the drop
    // that grew out of its rect reads as the chip itself falling open. The whole
    // chip goes, not just its contents — that is what the clock and the media
    // pill do, and leaving an empty capsule sitting on the bar made these five
    // the odd ones out. Opacity, not `visible`: invisible keeps its slot, hidden
    // would let the strip close the gap and shove the other chips sideways.
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
    opacity: takenOver ? 0.0 : 1.0
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
    // Lit, the text is whichever of black and white can be read on the accent —
    // not a fixed dark, which only held while the accent happened to be light.
    // matugen hands the shell whatever the wallpaper had in it, and on the
    // current palette `ghost` is a mid grey that white wins on. The hover tint
    // never takes dark text at all: it is a wash over the pill rather than a
    // fill, and dark letters on it came out as a smudge — the same one the
    // launcher, power and notification pills already had taken out.
    readonly property color contentColor: active
        ? Services.Colors.onColor(Services.Colors.ghost)
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
            // Where a band is set: a network called "HUAWEI-LeaderAP-7EC0" made
            // the chip a hundred pixels wider and dragged the open panel across
            // the screen with it, since the chip's width is where the panel
            // hangs from. Floor as well as ceiling, so "Off" does not snap it
            // narrow either; past the ceiling the name trails off.
            width: chip.maxLabelW > 0
                ? Math.max(chip.minLabelW, Math.min(implicitWidth, chip.maxLabelW))
                : implicitWidth
            elide: chip.maxLabelW > 0 ? Text.ElideRight : Text.ElideNone
            // Sideways there is no room for the words unless you ask for them.
            // An empty label (icon-only chip) still counted as a lane in
            // BarStrip's Grid, so the spacing after the glyph was reserved
            // with nothing to fill it -- the icon sat off-centre in its own
            // chip. Zero text drops it from the layout entirely.
            visible: chip.label !== "" && (!chip.vertical || chip.expanded)
            font.pixelSize: chip.vertical ? 9 : 12
            font.family: "JetBrainsMono NF"
            font.bold: true
            Behavior on color { ColorAnimation { duration: Services.Sizes.msStandard } }
        }
    }
}
