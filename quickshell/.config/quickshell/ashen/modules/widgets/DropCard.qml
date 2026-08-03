import QtQuick

import "root:/services" as Services

// A panel that falls out of its bar pill like a drop of water: it starts the
// size of the pill, stretches away, and the goo bridge pinches off. The caller
// gives it the pill's rect and the open size. Box first, contents after.
Item {
    id: root
    anchors.fill: parent

    property bool shown: false
    property real pillCX: 0
    property real pillCY: 0
    property real pillW: 44
    property real pillH: 32
    property real openW: 400
    property real openH: 300
    property real cardRadius: 20
    // What the chip was showing. Given a destination, the glyph and the name
    // FLY there instead of cross-fading -- that hand-off is the whole trick.
    property string pillGlyph: ""
    property string pillLabel: ""
    // Where they land. Text items, so their size and colour are read off them.
    property Item glyphTarget: null
    property Item labelTarget: null
    // Whether the chip it came from was lit.
    property bool pillActive: false
    // The plate the card is born on and returns to: the chip's own colour, so
    // the hand-over at either end is not a change of colour.
    property color pillColor: pillActive ? Services.Colors.ghost
                                         : Services.Colors.fillRest
    readonly property real tone: card.relay
    readonly property color cardColor:
        card.mix(pillColor, Services.Colors.surfacePanel, tone)
    // Once the card has settled a flying piece wears its landing colour.
    readonly property bool pieceSettled: card.relay >= 0.999
    // A piece only travels if it is the same piece at both ends.
    readonly property bool glyphFlies: glyphTarget !== null && pillGlyph !== ""
        && glyphTarget.text === pillGlyph
    readonly property bool labelFlies: labelTarget !== null && pillLabel !== ""
        && labelTarget.text === pillLabel

    // In flight: the copy is drawn and the real one is hidden. One flag drives
    // both, so the two are never on screen at once.
    readonly property bool morphing: card.morph < 0.995 && (shown || card.fall > 0.01)
    readonly property bool morphingGlyph: morphing && glyphFlies
    readonly property bool morphingLabel: morphing && labelFlies

    // Scales every duration and pause together, so the order of the beats
    // survives whatever the speed. 1.0 is the shell's pace.
    property real speed: 1.0
    function ms(v) { return Math.max(1, Math.round(v / root.speed)) }

    // How long the whole retraction takes: contents out (90), pieces home
    // (40 + 230), then the box itself (140 + 290). The panel window has to
    // stay mapped for all of it — unmapping earlier cuts the drop off halfway
    // and the panel reads as vanishing instead of climbing back into its chip.
    readonly property int closeMs: root.ms(Services.Sizes.panelCloseMs)

    // Content fades in only once the drop has landed, and the caller can hang
    // its own timings off this.
    readonly property alias contentAmt: card.contentAmt
    // For a panel that carries shared pieces of its own (the clock, media):
    // 0 = they sit where the pill has them, 1 = where the panel does.
    readonly property alias morph: card.morph
    readonly property alias card: card
    // Everything declared inside goes in the card, clipped to it.
    default property alias content: body.data

    // Normally the drop hangs off the bar, and where it lands is decided by the
    // bar's edge. A panel whose pill is NOT on the bar -- Process, off its peek
    // button on the bottom of the screen -- says so here instead, and the neck
    // ties it to that edge rather than to the bar.
    property string sourceEdge: ""            // "", "top" or "bottom"
    property real openXOverride: NaN
    property real openYOverride: NaN

    readonly property bool ownEdge: sourceEdge !== ""
    // Which line the drop is hanging from.
    readonly property real srcEdge: ownEdge
        ? (sourceEdge === "bottom" ? root.height : 0)
        : (Services.Sizes.barPosition === "bottom" ? root.height - Services.Sizes.barH
                                                   : Services.Sizes.barH)
    readonly property bool srcBelow: ownEdge ? sourceEdge === "bottom"
                                             : Services.Sizes.barPosition === "bottom"
    // A panel that lands far from where it left -- the launcher crosses to the
    // middle of the screen -- can turn the bridge off. Stretched over half a
    // screen it stops reading as something being pulled apart and becomes a
    // rope tying the card to the edge.
    property bool neckEnabled: true

    // A neck only makes sense pulling up or down; sideways it would be a rope
    // across the screen. GooNeck only ever draws a vertical bridge, so an own
    // edge of "left" or "right" gets no neck rather than a wrong one.
    readonly property bool neckable: neckEnabled && (ownEdge
        ? (sourceEdge === "top" || sourceEdge === "bottom")
        : !Services.Sizes.barVertical)

    readonly property real openX: isNaN(openXOverride)
        ? Services.Sizes.panelX(width, root.openW, root.pillCX) : openXOverride
    readonly property real openY: isNaN(openYOverride)
        ? Services.Sizes.panelY(height, root.openH, root.pillCY) : openYOverride

    // A layer surface is not on screen in the frame it is asked for, so the
    // fall waits for it or its first frames play unseen.
    Timer { id: arm; interval: Services.Sizes.panelArmMs; onTriggered: openAnim.restart() }
    onShownChanged: {
        if (shown) { closeAnim.stop(); arm.restart() }
        else { arm.stop(); openAnim.stop(); closeAnim.restart() }
    }
    Component.onCompleted: if (shown) arm.restart()

    // The goo bridge tying the drop to the bar until it pinches off. Only on a
    // horizontal bar: sideways it would be a neck across the screen.
    GooNeck {
        active: root.neckable
        pillCX: root.pillCX
        pillW: root.pillW
        fromBelow: root.srcBelow
        barEdge: root.srcEdge
        cardEdge: root.srcBelow ? card.y + card.height : card.y
        cardHalfW: card.width / 2
        pinch: Math.max(0, Math.min(1, card.fall / 0.55))
        // Not a fixed surface tone here: the card is born the chip's accent and
        // settles to the panel colour, and the neck has to cross with it.
        fillColor: root.cardColor
    }

    Rectangle {
        id: card

        // How far it has fallen, how far it has stretched away from the bar,
        // how far it has spread sideways, and how much of the content is in.
        property real fall: 0
        property real stretch: 0
        property real spread: 0
        property real contentAmt: 0
        property real morph: 0
        // How far along the colour hand-over is; see `tone` on the root.
        property real relay: 0

        function lerp(a, b, t) { return a + (b - a) * t }
        function mix(c1, c2, t) {
            return Qt.rgba(c1.r + (c2.r - c1.r) * t,
                           c1.g + (c2.g - c1.g) * t,
                           c1.b + (c2.b - c1.b) * t,
                           c1.a + (c2.a - c1.a) * t)
        }
        // Centre of a target in card coordinates. mapToItem has no change
        // signal, so the card's geometry and the target's own are touched to
        // make the binding re-run when either moves.
        function tgtX(item) {
            if (!item) return width / 2
            card.width; card.height; card.x
            item.x; item.y; item.width; item.height
            const p = item.mapToItem(card, item.width / 2, item.height / 2)
            return p.x
        }
        function tgtY(item) {
            if (!item) return height / 2
            card.width; card.height; card.y
            item.x; item.y; item.width; item.height
            const p = item.mapToItem(card, item.width / 2, item.height / 2)
            return p.y
        }

        ParallelAnimation {
            id: openAnim
            NumberAnimation {
                target: card; property: "fall"; to: 1
                duration: root.ms(380); easing.type: Services.Sizes.easeOut
            }
            NumberAnimation {
                target: card; property: "stretch"; to: 1
                duration: root.ms(300); easing.type: Services.Sizes.easeOut
            }
            NumberAnimation {
                target: card; property: "spread"; to: 1
                duration: root.ms(460); easing.type: Easing.OutBack; easing.overshoot: Services.Sizes.overshoot
            }
            // The colour goes over first and fast, while the box is still
            // opening out: by the time anything travels, the card has settled
            // on one tone and the pieces know what colour to be against it.
            NumberAnimation {
                target: card; property: "relay"; to: 1
                duration: root.ms(180); easing.type: Services.Sizes.easeInOut
            }
            // Box and flight overlap on purpose -- that is what makes them one
            // movement. Flight and contents must NOT: the carried piece lands
            // first, then everything that was never in the chip fades in.
            SequentialAnimation {
                PauseAnimation { duration: root.ms(190) }
                NumberAnimation {
                    target: card; property: "morph"; to: 1
                    duration: root.ms(300); easing.type: Services.Sizes.easeOut
                }
            }
            SequentialAnimation {
                PauseAnimation { duration: root.ms(500) }
                NumberAnimation { target: card; property: "contentAmt"; to: 1; duration: root.ms(220) }
            }
        }

        ParallelAnimation {
            id: closeAnim
            // Backwards, same order: the extra contents go first, then the two
            // pieces travel home, then the box follows them up.
            NumberAnimation { target: card; property: "contentAmt"; to: 0; duration: root.ms(90) }
            // Mirrored: the contents are gone before the piece sets off home,
            // the same way nothing appeared until it had landed on the way in.
            SequentialAnimation {
                PauseAnimation { duration: root.ms(100) }
                NumberAnimation {
                    target: card; property: "morph"; to: 0
                    duration: root.ms(230); easing.type: Services.Sizes.easeInOut
                }
            }
            // The colour goes back last, so the card is already shrinking into
            // the pill by the time it takes the accent again — arriving lit
            // before it has moved would just be a flash on the way out.
            SequentialAnimation {
                PauseAnimation { duration: root.ms(250) }
                NumberAnimation {
                    target: card; property: "relay"; to: 0
                    duration: root.ms(180); easing.type: Services.Sizes.easeInOut
                }
            }
            SequentialAnimation {
                PauseAnimation { duration: root.ms(140) }
                ParallelAnimation {
                    NumberAnimation {
                        target: card; property: "fall"; to: 0
                        duration: root.ms(290); easing.type: Services.Sizes.easeInOut
                    }
                    NumberAnimation {
                        target: card; property: "stretch"; to: 0
                        duration: root.ms(260); easing.type: Services.Sizes.easeInOut
                    }
                    NumberAnimation {
                        target: card; property: "spread"; to: 0
                        duration: root.ms(260); easing.type: Services.Sizes.easeInOut
                    }
                }
            }
        }

        // Floored: a pill that is collapsed to nothing (the USB one hides when
        // no stick is in) would otherwise start the drop as a sliver.
        readonly property real srcW: Math.max(24, root.pillW)
        readonly property real srcH: Math.max(24, root.pillH)
        width: srcW + (root.openW - srcW) * spread
        height: srcH + (root.openH - srcH) * stretch
        x: root.pillCX + (root.openX + root.openW / 2 - root.pillCX) * fall - width / 2
        y: root.pillCY + (root.openY + root.openH / 2 - root.pillCY) * fall - height / 2

        radius: Services.Sizes.pillR + (root.cardRadius - Services.Sizes.pillR) * Math.min(1, spread)
        color: root.cardColor
        gradient: Services.Prefs.useGradients && root.pillActive && root.tone < 0.02
            ? Services.Colors.accentGradient : null
        clip: true

        // Clicks inside must not reach the dismiss layer behind the panel.
        MouseArea { anchors.fill: parent; onClicked: {} }

        // ── The shared pieces ───────────────────────────────────────
        // Drawn at their final size and scaled down: stepping font.pixelSize
        // reflows in integer jumps. Positioned by centre, so scale never drags.
        Text {
            id: flyGlyph
            visible: root.morphingGlyph
            text: root.pillGlyph
            font.family: "Material Symbols Rounded"
            font.pixelSize: root.glyphTarget ? root.glyphTarget.font.pixelSize : 18
            color: root.pieceSettled
                ? (root.glyphTarget ? root.glyphTarget.color : Services.Colors.ghost)
                : Services.Colors.onColor(root.cardColor)
            Behavior on color { ColorAnimation { duration: root.ms(140) } }

            readonly property real s: card.lerp(18 / font.pixelSize, 1, card.morph)
            // Start: where it sits inside the chip. Next to a name it is tucked
            // against the left edge; on its own (the USB pill) it is centred,
            // and starting it off to one side made it come home crooked.
            readonly property real fromCX: (root.pillLabel !== ""
                ? root.pillCX - root.pillW / 2 + 8
                  + flyGlyph.width * (18 / flyGlyph.font.pixelSize) / 2
                : root.pillCX) - card.x
            readonly property real fromCY: root.pillCY - card.y
            x: card.lerp(fromCX, card.tgtX(root.glyphTarget), card.morph) - width / 2
            y: card.lerp(fromCY, card.tgtY(root.glyphTarget), card.morph) - height / 2
            transform: Scale {
                origin.x: flyGlyph.width / 2
                origin.y: flyGlyph.height / 2
                xScale: flyGlyph.s
                yScale: flyGlyph.s
            }
        }

        Text {
            id: flyLabel
            visible: root.morphingLabel
            text: root.pillLabel
            font.family: "JetBrainsMono NF"
            font.bold: true
            font.pixelSize: root.labelTarget ? root.labelTarget.font.pixelSize : 12
            color: root.pieceSettled
                ? (root.labelTarget ? root.labelTarget.color : Services.Colors.snow)
                : Services.Colors.onColor(root.cardColor)
            Behavior on color { ColorAnimation { duration: root.ms(140) } }

            readonly property real s: card.lerp(12 / font.pixelSize, 1, card.morph)
            readonly property real fromCX: root.pillCX + root.pillW / 2 - 8
                - flyLabel.width * (12 / flyLabel.font.pixelSize) / 2 - card.x
            readonly property real fromCY: root.pillCY - card.y
            x: card.lerp(fromCX, card.tgtX(root.labelTarget), card.morph) - width / 2
            y: card.lerp(fromCY, card.tgtY(root.labelTarget), card.morph) - height / 2
            transform: Scale {
                origin.x: flyLabel.width / 2
                origin.y: flyLabel.height / 2
                xScale: flyLabel.s
                yScale: flyLabel.s
            }
        }

        // The content is laid out at the card's open size from the first frame,
        // so nothing reflows on the way down; it is only revealed at the end.
        Item {
            id: body
            width: root.openW
            height: root.openH
            anchors.centerIn: parent
            opacity: card.contentAmt
            visible: opacity > 0.01
        }
    }
}
