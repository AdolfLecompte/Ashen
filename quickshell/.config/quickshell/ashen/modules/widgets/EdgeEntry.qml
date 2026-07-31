import QtQuick

// How the big panels arrive.
//
// The bar's own panels fall out of the pill they belong to (see DropCard), but
// the launcher, Settings and the notification rail have no pill to fall from —
// dragging them out of one read as arbitrary. These do the same thing from the
// other end: a small pill sits GLUED to the screen edge they live on — whole
// and touching it, the way a dock item sits against the side — then unsticks
// and grows into the card. Only then does the content assemble. Same language
// as the drop, no chip required.
//
// The pill takes the shape of the edge it comes off: a side edge gives a tall
// narrow pill, a top or bottom edge a wide flat one. A pill lying the wrong way
// across its own edge is the thing that looked odd.
//
// Three beats, in order, because overlapping them makes the panel look like it
// is assembling while it is still moving:
//   travel  — the pill crosses in from outside, if it has to
//   grow    — the pill becomes the card
//   content — the contents arrive, staggered
//
// Non-visual: it only publishes numbers. Whoever owns the card decides what to
// move with them, so a full-height rail and a centred card can share one
// arrival without sharing a layout.
Item {
    id: root

    property bool shown: false

    // Which screen edge the pill comes off: "left", "right", "top", "bottom".
    // A card centred on screen still names one — it rides in from there and
    // unfolds where it sits — with a longer `travelMs` for the distance. Use
    // "center" only for something that must open strictly in place.
    property string edge: "left"

    readonly property bool vertical: edge === "left" || edge === "right"
    readonly property bool centred: edge === "center"

    // The pill lies along its edge, so the long side follows the edge.
    property int pillLong: 150
    property int pillShort: 46
    readonly property int pillW: centred ? pillLong : (vertical ? pillShort : pillLong)
    readonly property int pillH: centred ? pillShort : (vertical ? pillLong : pillShort)
    property int pillRadius: 12

    // Two different distances, and they move on different beats.
    //
    // `restMargin` is the small gap between the card and its edge. The pill
    // starts GLUED to the edge -- whole, touching it, never half-buried, which
    // just looked cut off -- and unsticks by this much as it grows, so
    // separating and transforming are one movement.
    property int restMargin: 0
    // `travel` is a real journey from outside, crossed BEFORE anything grows:
    // a centred card coming up off the bottom, or the power menu, which has no
    // box to grow into at all.
    property int travel: 0

    // A card docked to its edge separates by a few dozen pixels; a centred one
    // has to cross half the screen to get there, so it needs longer in the air
    // and must not start unfolding while it is still travelling.
    property int travelMs: 300
    property int growDelay: 120

    // A pill with a journey to make must be SOLID before it sets off, or it
    // materialises somewhere out in the middle of the screen instead of
    // leaving the edge: OutQuint is ~92 % of the way there by the time a
    // 170 ms fade has finished, so the whole arrival read as a fade out of
    // nowhere. Fade at the edge first, then travel.
    //
    // A pill that only unsticks from its own edge (travel 0 — the notification
    // rail, Settings) has nowhere to materialise, so it does not wait.
    readonly property int fadeMs: 120
    readonly property int travelDelay: travel > 0 ? fadeMs : 0

    // The three drivers, in the order they run.
    property real boxAmt: 0
    property real growAmt: 0
    property real contentAmt: 0
    // Kept apart from boxAmt so the pill is solid before it moves; fading
    // across the whole motion looks like a ghost sliding in.
    property real fade: 0

    readonly property int openMs: 760
    readonly property int closeMs: 520
    // What the panel must keep its window mapped for after `shown` goes false,
    // or the surface unmaps mid-exit and the animation is never seen.
    readonly property int holdMs: closeMs + 60

    // The journey is over before the box grows; the unsticking happens with it.
    readonly property real reach: centred ? 0
                                : travel * (1 - boxAmt) + restMargin * (1 - growAmt)
    readonly property real offX: edge === "left" ? -reach
                               : edge === "right" ? reach : 0
    readonly property real offY: edge === "top" ? -reach
                               : edge === "bottom" ? reach : 0

    // Pill → card. The card's own numbers go in, the current ones come out, so
    // a panel never has to know which stage the arrival is at.
    function boxW(full) { return root.pillW + (full - root.pillW) * root.growAmt }
    function boxH(full) { return root.pillH + (full - root.pillH) * root.growAmt }
    function boxRadius(full) { return root.pillRadius + (full - root.pillRadius) * root.growAmt }

    // How glued to its edge the card still is, 1 to 0. While it is 1 the card
    // is literally touching the screen border, so the corners on that side are
    // squared off and it reads as JOINED to the edge rather than a rounded pill
    // kissing it. They round back as it pulls away.
    readonly property real atEdge: {
        const total = travel + restMargin
        // A panel growing out of a real widget (Process, off its peek button)
        // has neither: what unglues it there is the growth itself.
        if (total <= 0) return 1 - growAmt
        return Math.max(0, Math.min(1, reach / total))
    }
    function edgeRadius(full) { return full * (1 - root.atEdge) }

    // Interpolate anything between its pill value and its card value on the
    // growth. Used by a panel that grows out of a real widget rather than off
    // an edge, so its position travels along with its size.
    function lerp(from, to) { return from + (to - from) * root.growAmt }

    // Per-piece stagger out of the single content driver: piece i starts a
    // little after piece i-1 and they all land together. One driver, no
    // animation per child, nothing to keep in sync.
    function stage(i) {
        const start = Math.min(0.5, i * 0.1)
        return Math.max(0, Math.min(1, (contentAmt - start) / (1 - start)))
    }

    // A few pixels of rise for a piece that is assembling, so the content
    // settles into place instead of merely appearing.
    function riseOf(i) { return (1 - root.stage(i)) * 10 }

    // The other one has to be stopped, not merely left alone: closing while
    // still opening left both running and fighting over the same three
    // properties, so the box grew a little further before it began to shrink.
    onShownChanged: {
        if (shown) { closeAnim.stop(); openAnim.restart() }
        else { openAnim.stop(); closeAnim.restart() }
    }
    // A panel can be constructed with `shown` already true (LazyPanel preloads
    // and the first open can land in either order), and a property born with
    // its new value never emits a change.
    Component.onCompleted: if (shown) openAnim.restart()

    // Explicit animations rather than Behaviors: open and close are asymmetric,
    // and a Behavior with a conditional duration reads the OLD value of the
    // flag that picks it.
    ParallelAnimation {
        id: openAnim
        NumberAnimation { target: root; property: "fade"; to: 1; duration: root.fadeMs; easing.type: Easing.OutCubic }
        SequentialAnimation {
            // Solid at the edge before it moves.
            PauseAnimation { duration: root.travelDelay }
            NumberAnimation { target: root; property: "boxAmt"; to: 1; duration: root.travelMs; easing.type: Easing.OutQuint }
        }
        SequentialAnimation {
            // Overlaps the journey a little on purpose: arriving and growing
            // are one gesture, unlike growing and filling.
            PauseAnimation { duration: root.travelDelay + root.growDelay }
            // OutQuint, never OutBack: a panel that bounces was rejected long
            // ago, and the rule holds for the pill growing into one.
            NumberAnimation { target: root; property: "growAmt"; to: 1; duration: 420; easing.type: Easing.OutQuint }
        }
        SequentialAnimation {
            PauseAnimation { duration: root.travelDelay + root.growDelay + 360 }
            NumberAnimation { target: root; property: "contentAmt"; to: 1; duration: 280; easing.type: Easing.OutCubic }
        }
    }

    ParallelAnimation {
        id: closeAnim
        NumberAnimation { target: root; property: "contentAmt"; to: 0; duration: 100; easing.type: Easing.InCubic }
        SequentialAnimation {
            PauseAnimation { duration: 60 }
            NumberAnimation { target: root; property: "growAmt"; to: 0; duration: 300; easing.type: Easing.InCubic }
        }
        SequentialAnimation {
            PauseAnimation { duration: 260 }
            ParallelAnimation {
                NumberAnimation { target: root; property: "boxAmt"; to: 0; duration: 260; easing.type: Easing.InCubic }
                NumberAnimation { target: root; property: "fade"; to: 0; duration: 220; easing.type: Easing.InCubic }
            }
        }
    }
}
