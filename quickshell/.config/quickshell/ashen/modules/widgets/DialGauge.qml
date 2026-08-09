import QtQuick

import "root:/services" as Services

// A reading in a ring: the number in the middle, the level around the rim.
// Volume, brightness and battery all say the same kind of thing, so they say it
// the same way. The centre sits on FIXED slots, never a packing Column: text in
// there changes length ("62%" -> "Muted") and would shove the rest of the dial.
Item {
    id: root

    property int size: 132
    property int lw: 10

    // 0..1. What the ring is asked to show; `frac` is what it actually
    // strokes, so it can travel there rather than jump.
    property real value: 0
    property int easeMs: 220

    property string glyph: ""
    property string label: ""
    // The second line. Its height is reserved whether or not there is anything
    // in it, so a state that has something to add here does not shove the
    // number it belongs to.
    property string caption: ""

    property int glyphSize: 20
    property int labelSize: 22
    property int captionSize: 10

    // The vessel fills with liquid as well as stroking its rim; the ring on
    // its own said the same thing twice as quietly.
    property bool liquid: true
    property color fillColor: Services.Colors.ghost
    // The liquid is the accent itself, solid: not a veil, not a mix towards the
    // surface. Anything under it is re-inked by `Submerged`, so it can be the
    // full tone without costing the reading its contrast.
    readonly property color liquidColor: root.fillColor
    // What can be read once that colour is covering a letter.
    readonly property color liquidInk: Services.Colors.onColor(root.liquidColor)
    property color trackColor: Services.Colors.ghostAlpha(0.14)
    // The ring breathes: for something that is still happening (charging), not
    // for something that merely is. Opacity on a second canvas, so the pulse
    // costs a recomposite per frame and not a repaint.
    property bool glow: false

    // Held dark until the caller says the card is actually on screen. A Canvas
    // keeps its last frame as a texture and flashes it on re-map, which reads
    // as the dial jumping from full to its real level.
    property bool armed: true
    // Sweep up from empty when it arms, at a constant speed whatever the level
    // (so a low reading is a short sweep, not a slow one). 0 disables it.
    property int sweepMs: 0

    signal tapped()

    // While DropCard is carrying the chip's glyph or reading across the
    // screen, the copy that already lives here has to stand down or the piece
    // arrives on top of itself. The panel knows; the dial does not.
    property bool hideGlyph: false
    property bool hideLabel: false

    // For DropCard: the pieces flying out of the bar chip land on these.
    readonly property alias glyphItem: glyphText
    readonly property alias labelItem: labelText

    implicitWidth: root.size
    implicitHeight: root.size
    width: implicitWidth
    height: implicitHeight

    property real frac: root.value
    Behavior on frac {
        // easeMs 0 means "keep up": a dial tied to a slider being dragged has
        // to be under the finger, not easing towards where it was.
        enabled: root.easeMs > 0 && !sweep.running
        NumberAnimation { duration: root.easeMs; easing.type: Services.Sizes.easeOut }
    }

    onArmedChanged: if (armed && sweepMs > 0) sweep.restart()
    SequentialAnimation {
        id: sweep
        PropertyAction { target: root; property: "frac"; value: 0 }
        NumberAnimation {
            target: root; property: "frac"
            to: root.value
            duration: Math.round(Math.max(450, root.sweepMs * root.value))
            easing.type: Services.Sizes.easeTrace
        }
        // The end value was captured when the sweep started; if a fresher
        // reading landed mid-sweep, settle onto it rather than stopping short.
        onStopped: if (root.frac !== root.value) root.frac = root.value
    }

    // One radius for every arc drawn here, measured off the item and not off
    // whichever canvas is drawing: the halo's canvas is deliberately bigger
    // than the dial, and deriving the radius from its own size would push the
    // glow outwards onto a different circle than the ring it belongs to.
    readonly property real arcR: (root.size - root.lw) / 2 - 1
    // How far the glow reaches past the ring: half of the extra stroke width,
    // plus a pixel so the antialiased edge is not the thing that gets cut.
    readonly property int haloExtra: 9
    readonly property int haloPad: Math.ceil(haloExtra / 2) + 2

    onFracChanged: { ring.requestPaint(); halo.requestPaint() }
    onFillColorChanged: { ring.requestPaint(); halo.requestPaint() }
    onArcRChanged: { ring.requestPaint(); halo.requestPaint() }

    function strokeArc(ctx, w, h, width_, color) {
        const r = root.arcR
        const cx = w / 2, cy = h / 2
        // Straight up, clockwise: the only starting point that needs no
        // explaining.
        const a0 = -Math.PI / 2
        ctx.lineWidth = width_
        ctx.lineCap = "round"
        ctx.beginPath()
        ctx.arc(cx, cy, r, a0, a0 + Math.PI * 2 * Math.max(0, Math.min(1, root.frac)), false)
        ctx.strokeStyle = color
        ctx.stroke()
    }

    // Under everything: the same arc, fatter and faint. Only its opacity moves.
    Canvas {
        id: halo
        // Bigger than the dial by exactly what the fat stroke overhangs. Drawn
        // at the same radius all the same, so it stays concentric.
        anchors.fill: parent
        anchors.margins: -root.haloPad
        opacity: 0
        visible: root.glow && root.armed
        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            if (root.frac <= 0.001) return
            root.strokeArc(ctx, width, height, root.lw + root.haloExtra,
                           Qt.rgba(root.fillColor.r, root.fillColor.g, root.fillColor.b, 0.30))
        }
        SequentialAnimation on opacity {
            running: root.glow && root.armed
            loops: Animation.Infinite
            NumberAnimation { to: 1; duration: 900; easing.type: Services.Sizes.easeLoop }
            NumberAnimation { to: 0; duration: 900; easing.type: Services.Sizes.easeLoop }
        }
    }

    // Inside the ring, not under it: the rim stays legible at any level.
    LiquidFill {
        id: liquidFill
        anchors.fill: parent
        visible: root.liquid && root.armed
        running: root.liquid && root.armed && root.visible
        level: root.frac
        inset: root.lw + 3
        waveAmp: Math.max(2.5, root.size * 0.032)
        color_: root.liquidColor
        // Doubles as the mask for the submerged half of the centre.
        layer.enabled: true
    }

    Canvas {
        id: ring
        anchors.fill: parent
        opacity: root.armed ? 1 : 0
        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            ctx.lineWidth = root.lw
            ctx.lineCap = "round"
            ctx.beginPath()
            ctx.arc(width / 2, height / 2, root.arcR, 0, Math.PI * 2, false)
            ctx.strokeStyle = root.trackColor
            ctx.stroke()
            if (root.frac <= 0.001) return
            root.strokeArc(ctx, width, height, root.lw, root.fillColor)
        }
    }

    // ── The fixed centre ───────────────────────────────────────────────────
    // Wrapped in a layer the size of the dial so the submerged copy and the
    // liquid that masks it are measured against the same rect.
    Item {
        id: centre
        anchors.fill: parent

    Item {
        id: stack
        anchors.centerIn: parent
        width: root.size - 2 * root.lw - 12

        readonly property int glyphH: root.glyph === "" ? 0 : Math.round(root.glyphSize * 1.35)
        readonly property int labelH: Math.round(root.labelSize * 1.35)
        readonly property int capH: root.captionSize <= 0 ? 0 : Math.round(root.captionSize * 1.6)
        height: glyphH + labelH + capH

        Text {
            id: glyphText
            width: parent.width
            height: stack.glyphH
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            visible: root.glyph !== ""
            opacity: root.hideGlyph ? 0 : 1
            text: root.glyph
            font.family: "Material Symbols Rounded"
            font.pixelSize: root.glyphSize
            color: root.fillColor
            Behavior on color { ColorAnimation { duration: Services.Sizes.msMicro } }
        }
        Text {
            id: labelText
            y: stack.glyphH
            width: parent.width
            height: stack.labelH
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            opacity: root.hideLabel ? 0 : 1
            text: root.label
            color: Services.Colors.snow
            font.pixelSize: root.labelSize
            font.bold: true
            font.family: "JetBrainsMono NF"
        }
        Text {
            y: stack.glyphH + stack.labelH
            width: parent.width
            height: stack.capH
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            visible: stack.capH > 0
            text: root.caption
            color: Services.Colors.mist
            font.pixelSize: root.captionSize
            font.bold: true
            font.family: "JetBrainsMono NF"
            opacity: root.caption === "" ? 0 : 1
            Behavior on opacity { NumberAnimation { duration: Services.Sizes.msMicro } }
        }
    }
    }

    // The half of the centre the liquid has reached, re-inked so the reading
    // meets its own level instead of floating over it.
    Submerged {
        anchors.fill: parent
        visible: root.liquid && root.armed
        source: centre
        mask: liquidFill
        ink: root.liquidInk
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.tapped()
    }
}
