import QtQuick

import "root:/services" as Services

// Arrival for a panel with no pill to grow out of: it appears where it lives,
// already its own size, and unfolds from its centre -- fade, box out, contents
// assemble -- and runs backwards to close. Publishes numbers only, so panels
// with different layouts share one arrival. See DropCard for the pill version.
Item {
    id: root

    property bool shown: false

    // "Plain" is the other half of the Appearance setting: the panel simply
    // appears at its final size, opacity only. Nothing unfolds, nothing rises,
    // nothing is staggered -- a window, not a transformation.
    readonly property bool plain: Services.Prefs.panelStyle === "plain"

    // How folded the box starts, as a fraction of its final size.
    property real foldFrom: root.plain ? 1.0 : 0.92
    // Pixels below its resting place to come up from, 0 for none. The rise
    // runs on the same beat as the unfold, so arriving and opening are one
    // movement.
    property int rise: 0
    readonly property real offY: root.plain ? 0 : root.rise * (1 - root.boxAmt)

    // The drivers, in the order they run.
    property real boxAmt: 0
    property real contentAmt: 0
    property real fade: 0

    readonly property int openMs: root.plain ? 280 : 700
    readonly property int closeMs: root.plain ? 210 : 380
    // How long the panel must stay mapped after `shown` goes false.
    readonly property int holdMs: closeMs + 60

    // Size now, given the size when open. Plain keeps its full width and
    // unrolls its height from the top edge: the contents are laid out at the
    // final size from the first frame and the box simply reveals more of them.
    function boxW(full) {
        if (root.plain) return full
        return full * (root.foldFrom + (1 - root.foldFrom) * root.boxAmt)
    }
    function boxH(full) {
        if (root.plain) return full * (0.06 + 0.94 * root.boxAmt)
        return full * (root.foldFrom + (1 - root.foldFrom) * root.boxAmt)
    }
    // Centred while it unfolds; pinned to its top edge while it unrolls.
    function boxX(fullX, full) { return root.plain ? fullX : fullX + (full - root.boxW(full)) / 2 }
    function boxY(fullY, full) { return root.plain ? fullY : fullY + (full - root.boxH(full)) / 2 }
    // Nothing is glued to an edge here, so a corner is always its full radius.
    function boxRadius(full) { return full }

    // Per-piece stagger out of the single content driver: piece i starts a
    // little after piece i-1 and they all land together.
    function stage(i) {
        if (root.plain) return root.contentAmt
        const start = Math.min(0.5, i * 0.1)
        return Math.max(0, Math.min(1, (contentAmt - start) / (1 - start)))
    }
    // A few pixels of rise, so a piece settles rather than appears.
    function riseOf(i) { return root.plain ? 0 : (1 - root.stage(i)) * 10 }

    // Explicit animations, not Behaviors: open and close are asymmetric, and
    // the other one has to be stopped rather than left to fight over the same
    // properties.
    onShownChanged: {
        if (shown) { closeAnim.stop(); openAnim.restart() }
        else { openAnim.stop(); closeAnim.restart() }
    }
    // A panel can be built with `shown` already true (LazyPanel preloads), and
    // a property born with its new value never emits a change.
    Component.onCompleted: if (shown) openAnim.restart()

    ParallelAnimation {
        id: openAnim
        NumberAnimation {
            target: root; property: "fade"; to: 1
            duration: root.plain ? 150 : Services.Sizes.msPronounced
            easing.type: Services.Sizes.easeOut
        }
        NumberAnimation {
            target: root; property: "boxAmt"; to: 1
            duration: root.plain ? 260 : Services.Sizes.msPanel
            easing.type: root.plain ? Services.Sizes.easeOut : Services.Sizes.easeBox
        }
        // The box finishes unfolding before anything fills it -- unless there
        // is no unfolding, in which case the contents are simply there.
        SequentialAnimation {
            PauseAnimation { duration: root.plain ? 0 : Services.Sizes.msEmphasis }
            NumberAnimation {
                target: root; property: "contentAmt"; to: 1
                duration: root.plain ? root.openMs : Services.Sizes.msEmphasis
                easing.type: Services.Sizes.easeOut
            }
        }
    }

    ParallelAnimation {
        id: closeAnim
        NumberAnimation {
            target: root; property: "contentAmt"; to: 0
            duration: root.plain ? root.closeMs : Services.Sizes.msInstant
            easing.type: Services.Sizes.easeIn
        }
        SequentialAnimation {
            PauseAnimation { duration: root.plain ? 0 : 60 }
            NumberAnimation {
                target: root; property: "boxAmt"; to: 0
                duration: root.plain ? 190 : Services.Sizes.msEmphasis
                easing.type: Services.Sizes.easeIn
            }
        }
        SequentialAnimation {
            PauseAnimation { duration: root.plain ? 0 : 120 }
            NumberAnimation {
                target: root; property: "fade"; to: 0
                duration: root.plain ? root.closeMs : Services.Sizes.msStandard
                easing.type: Services.Sizes.easeIn
            }
        }
    }
}
