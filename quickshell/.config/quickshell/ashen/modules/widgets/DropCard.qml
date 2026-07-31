import QtQuick

import "root:/services" as Services

// A panel that falls out of its bar pill like a drop of water: it starts the
// size of the pill, stretches away from the bar, and the goo bridge between the
// two thins out and pinches off. The clock and the media pill have been opening
// this way; this is that opening as one piece, so the small chips on the system
// pill can use it without each panel carrying its own copy of the maths.
//
// The caller gives it the pill (centre and size, from AppState) and the size the
// card wants when it is open, then puts the panel's content inside. Content is
// held back until the box has arrived: box first, contents after.
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
    // What the chip was showing. The drop carries it — and, if the caller says
    // where they belong, the two texts FLY from the chip's rect to their place
    // in the panel instead of one fading out while another fades in. That
    // hand-off is the whole trick: the same glyph and the same name travel, so
    // the panel reads as the chip unfolded rather than as a new window.
    property string pillGlyph: ""
    property string pillLabel: ""
    // Where they land. Text items, so their size and colour are read off them.
    property Item glyphTarget: null
    property Item labelTarget: null
    // Whether the chip it came from was lit. If it was, the card is born that
    // same accent and settles to the panel's surface while the box is still
    // opening out — before anything travels, so the pieces make the trip over
    // a card that has already decided what colour it is.
    property bool pillActive: false
    readonly property real tone: card.relay
    readonly property color cardColor: pillActive
        ? card.mix(Services.Colors.ghost, Services.Colors.surfacePanel, tone)
        : Services.Colors.surfacePanel
    // The letters are never interpolated between two colours — that was the
    // fault: a card halfway between light and dark carried text halfway
    // between dark and light, and for a few frames the two were the same grey.
    // While the card is still crossing they are simply whichever of black and
    // white can be read on it as it is right now; once it has settled they take
    // the colour of the thing they are flying to, which was chosen to be read
    // on the panel's surface in the first place. The card settles before the
    // flight begins, so a piece wears its landing colour for the whole trip and
    // arrives without a change of any kind.
    readonly property bool pieceSettled: card.relay >= 0.999
    // A piece only travels if it is the same piece at both ends. "Mute" in the
    // chip and "Muted" in the panel are two different words, and flying one
    // onto the other just stacks them; the word stays behind and only the icon
    // makes the trip. Same test for the icon itself.
    readonly property bool glyphFlies: glyphTarget !== null && pillGlyph !== ""
        && glyphTarget.text === pillGlyph
    readonly property bool labelFlies: labelTarget !== null && pillLabel !== ""
        && labelTarget.text === pillLabel

    // True while the pieces are still in flight: the panel hides the real ones,
    // but only the ones that are actually being carried.
    readonly property bool morphing: card.morph < 0.995 && (shown || card.fall > 0.01)
    readonly property bool morphingGlyph: morphing && glyphFlies
    readonly property bool morphingLabel: morphing && labelFlies

    // How fast this particular drop runs. 1.0 is the shell's pace and almost
    // everything leaves it alone; a panel you open and dismiss dozens of times
    // a session (the launcher) can ask for more. It scales every duration and
    // every pause together, so the order of the beats is preserved -- the box
    // still lands before the contents start, whatever the speed.
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

    // The window is not on screen in the frame it is told to open, so the fall
    // has to wait for it. Without this the first hundred milliseconds played
    // unseen and the drop turned up already halfway down — the same trap the
    // battery canvas hit, and the reason the clock and the media panel feel
    // like they leave from their pill and these did not.
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
        // Centre of a target in card coordinates. Recomputed whenever the card
        // moves or resizes, which is every frame of the fall — mapToItem has no
        // change signal of its own.
        function tgtX(item) {
            if (!item) return width / 2
            card.width; card.height; card.x
            const p = item.mapToItem(card, item.width / 2, item.height / 2)
            return p.x
        }
        function tgtY(item) {
            if (!item) return height / 2
            card.width; card.height; card.y
            const p = item.mapToItem(card, item.width / 2, item.height / 2)
            return p.y
        }

        ParallelAnimation {
            id: openAnim
            NumberAnimation {
                target: card; property: "fall"; to: 1
                duration: root.ms(380); easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: card; property: "stretch"; to: 1
                duration: root.ms(300); easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: card; property: "spread"; to: 1
                duration: root.ms(460); easing.type: Easing.OutBack; easing.overshoot: 0.7
            }
            // The colour goes over first and fast, while the box is still
            // opening out: by the time anything travels, the card has settled
            // on one tone and the pieces know what colour to be against it.
            NumberAnimation {
                target: card; property: "relay"; to: 1
                duration: root.ms(180); easing.type: Easing.InOutCubic
            }
            // The flight starts while the box is still spreading — that overlap
            // is what makes the two read as one movement rather than two moves
            // in a queue. What must NOT overlap is the flight and the contents:
            // the piece carried over from the chip has to reach its place and
            // stop, and only then does everything that was never in the chip
            // fade in around it. Coming in at 340, while the name was still
            // travelling, put the panel's furniture on screen underneath a
            // moving word and the whole thing read backwards.
            SequentialAnimation {
                PauseAnimation { duration: root.ms(190) }
                NumberAnimation {
                    target: card; property: "morph"; to: 1
                    duration: root.ms(300); easing.type: Easing.OutCubic
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
                    duration: root.ms(230); easing.type: Easing.InOutCubic
                }
            }
            // The colour goes back last, so the card is already shrinking into
            // the pill by the time it takes the accent again — arriving lit
            // before it has moved would just be a flash on the way out.
            SequentialAnimation {
                PauseAnimation { duration: root.ms(250) }
                NumberAnimation {
                    target: card; property: "relay"; to: 0
                    duration: root.ms(180); easing.type: Easing.InOutCubic
                }
            }
            SequentialAnimation {
                PauseAnimation { duration: root.ms(140) }
                ParallelAnimation {
                    NumberAnimation {
                        target: card; property: "fall"; to: 0
                        duration: root.ms(290); easing.type: Easing.InOutCubic
                    }
                    NumberAnimation {
                        target: card; property: "stretch"; to: 0
                        duration: root.ms(260); easing.type: Easing.InOutCubic
                    }
                    NumberAnimation {
                        target: card; property: "spread"; to: 0
                        duration: root.ms(260); easing.type: Easing.InOutCubic
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
        // Drawn once at their final size and scaled down to the chip's, the
        // same way the clock does it: stepping font.pixelSize instead makes the
        // glyphs reflow in integer jumps and reads as a stutter. Positioned by
        // centre, so scaling never drags them sideways.
        Text {
            id: flyGlyph
            visible: root.glyphFlies
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
            visible: root.labelFlies
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
