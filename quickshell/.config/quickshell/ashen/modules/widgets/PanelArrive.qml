import QtQuick

import "root:/services" as Services

// Arrival for a panel with no pill to grow out of. It appears where it lives,
// already its own size, and unfolds from its centre: fade in, box out to full,
// then the contents assemble. Closing runs it backwards -- contents out, box
// contracts, fade.
//
// Publishes numbers only, so panels with different layouts share one arrival.
// See DropCard for the version that grows out of a chip.
Item {
    id: root

    property bool shown: false

    // How folded the box starts, as a fraction of its final size.
    property real foldFrom: 0.92
    // Pixels below its resting place to come up from, 0 for none. The rise
    // runs on the same beat as the unfold, so arriving and opening are one
    // movement.
    property int rise: 0
    readonly property real offY: root.rise * (1 - root.boxAmt)

    // The drivers, in the order they run.
    property real boxAmt: 0
    property real contentAmt: 0
    property real fade: 0

    readonly property int openMs: 700
    readonly property int closeMs: 380
    // How long the panel must stay mapped after `shown` goes false.
    readonly property int holdMs: closeMs + 60

    // Size now, given the size when open.
    function boxW(full) { return full * (root.foldFrom + (1 - root.foldFrom) * root.boxAmt) }
    function boxH(full) { return full * (root.foldFrom + (1 - root.foldFrom) * root.boxAmt) }
    // Where to put it so it unfolds around its centre rather than off a corner.
    function boxX(fullX, full) { return fullX + (full - root.boxW(full)) / 2 }
    function boxY(fullY, full) { return fullY + (full - root.boxH(full)) / 2 }
    // Nothing is glued to an edge here, so a corner is always its full radius.
    function boxRadius(full) { return full }

    // Per-piece stagger out of the single content driver: piece i starts a
    // little after piece i-1 and they all land together.
    function stage(i) {
        const start = Math.min(0.5, i * 0.1)
        return Math.max(0, Math.min(1, (contentAmt - start) / (1 - start)))
    }
    // A few pixels of rise, so a piece settles rather than appears.
    function riseOf(i) { return (1 - root.stage(i)) * 10 }

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
            duration: Services.Sizes.msPronounced; easing.type: Services.Sizes.easeOut
        }
        NumberAnimation {
            target: root; property: "boxAmt"; to: 1
            duration: Services.Sizes.msPanel; easing.type: Services.Sizes.easeBox
        }
        // The box finishes unfolding before anything fills it.
        SequentialAnimation {
            PauseAnimation { duration: Services.Sizes.msEmphasis }
            NumberAnimation {
                target: root; property: "contentAmt"; to: 1
                duration: Services.Sizes.msEmphasis; easing.type: Services.Sizes.easeOut
            }
        }
    }

    ParallelAnimation {
        id: closeAnim
        NumberAnimation {
            target: root; property: "contentAmt"; to: 0
            duration: Services.Sizes.msInstant; easing.type: Services.Sizes.easeIn
        }
        SequentialAnimation {
            PauseAnimation { duration: 60 }
            NumberAnimation {
                target: root; property: "boxAmt"; to: 0
                duration: Services.Sizes.msEmphasis; easing.type: Services.Sizes.easeIn
            }
        }
        SequentialAnimation {
            PauseAnimation { duration: 120 }
            NumberAnimation {
                target: root; property: "fade"; to: 0
                duration: Services.Sizes.msStandard; easing.type: Services.Sizes.easeIn
            }
        }
    }
}
