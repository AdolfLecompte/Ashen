pragma Singleton
import Quickshell
import QtQuick

// Shared bar metrics and geometry. Tweak the numbers here to scale the whole
// bar at once; ask the helpers below where a panel should sit rather than
// hardcoding an edge, so every panel follows the bar when it moves.
Singleton {
    id: root

    // Bar thickness: height on a horizontal bar, width on a vertical one
    readonly property int barH: 56

    // Pill (top level bar item) size and corner radius
    readonly property int pillH: 44
    readonly property int pillR: 10

    // The utility pill that peeks out of the edges the bar is not on. Slimmer
    // than a bar pill, so it reads as a ledge. Here because panels grow from it.
    readonly property int utilPillLen: 400
    readonly property int utilPillThick: 36

    // ── Hover language ──────────────────────────────────────────────────
    // One place for how everything you can click on the bar reacts: grow
    // under the pointer, give a little under the click. Every pill and chip
    // calls the same function, so none of them can drift on its own.
    readonly property real pillHoverScale: 1.06
    readonly property real pillPressScale: 0.94
    readonly property int pillHoverMs: 150
    function hoverScale(hovered, pressed) {
        if (pressed) return pillPressScale
        return hovered ? pillHoverScale : 1.0
    }

    // The tint a thing takes on under the pointer is NOT here: it is a colour,
    // and it lives with the other fills in Colors (fillRest / fillHover /
    // fillHoverPill). Sizes owns how things move, Colors owns how they look.

    // Inner chip (item nested inside a pill) size and corner radius
    readonly property int innerH: 32
    readonly property int innerR: 8

    // Smallest gap between two clickable things: closer and they read as one
    // control, and a hovered button grows into its neighbour. Never less.
    readonly property int btnGap: 6

    // ── Type scale ───────────────────────────────────────────────────────
    // Nine steps and nothing between them. A panel uses at most four; if it
    // needs five, it is two panels.
    readonly property int fsCaption: 9        // the line under a title, units
    readonly property int fsMeta: 10          // column headers, labels
    readonly property int fsBody: 11          // list rows — the default
    readonly property int fsInput: 13         // anything typed into
    readonly property int fsCardTitle: 14     // bold: a card's name
    readonly property int fsSectionTitle: 17  // bold: SectionHead
    readonly property int fsPanelTitle: 20    // bold: the panel's own name
    readonly property int fsReadout: 24       // bold: the number that IS the card
    readonly property int fsHero: 42          // empty-state glyph, lock clock

    // ── Shape ────────────────────────────────────────────────────────────
    // Everything is a rounded rectangle or a circle; these are the corners it
    // may have. See innerR and pillR above for the two small ones.
    readonly property int cardR: 14           // a card inside a panel
    readonly property int cardLgR: 18         // a hero card
    readonly property int panelR: 22          // the panel itself

    // ── Motion ───────────────────────────────────────────────────────────
    // Every duration in the shell comes from here. Choreographies -- a drop,
    // an arrival, a staged swap -- keep their own numbers: those are a score,
    // not a style.
    readonly property int msInstant: 90       // acknowledging a click
    readonly property int msMicro: 140        // colour, opacity, hover
    readonly property int msStandard: 200     // a property moving on your input
    readonly property int msPronounced: 260   // an accent travelling, a tab turning
    readonly property int msEmphasis: 320     // resizing, or covering a distance
    readonly property int msPanel: 420        // a panel's own box

    // The curves, named by what they are for.
    readonly property int easeOut: Easing.OutCubic      // arriving, settling
    readonly property int easeIn: Easing.InCubic        // leaving
    readonly property int easeInOut: Easing.InOutCubic  // there and back
    readonly property int easeBox: Easing.OutQuint      // a panel's box, no bounce
    readonly property int easeLoop: Easing.InOutSine    // heartbeats, glows
    readonly property int easeTrace: Easing.Linear      // progress strokes: a
                                                        // front-loaded curve
                                                        // hides the duration
    // Overshoot lives only in a landing, and only across the short axis.
    readonly property real overshoot: 0.7

    // ── Panel opening language ──────────────────────────────────────────
    // A layer surface is not on screen in the frame it is asked for, so panels
    // wait this long before growing -- and their pill hands over on the same
    // beat, or the bar goes blank first.
    readonly property int panelArmMs: 200
    // How long a panel takes to climb back into its pill. The window has to
    // stay mapped for all of it and the pill only comes back at the end, so
    // the panel, its dismiss layer and the chip all read it from here.
    readonly property int panelCloseMs: 440

    // Gap between the bar and a panel hanging off it, and between a panel and
    // the far screen edges
    readonly property int panelGap: 8
    readonly property int edgeGap: 12

    // ── Bar placement ────────────────────────────────────────────────────
    // `barPosition` is what the user picked; it must never drive the layout on
    // its own, because moving the bar is animated: it fades out, changes edge
    // while nobody can see it, and fades back in. `applied` is the edge
    // everything lays out against, and it only changes while the bar is hidden.
    readonly property string wanted: Prefs.barPosition
    property string applied: Prefs.barPosition
    property bool hidden: false

    onWantedChanged: if (wanted !== applied) {
        hidden = true
        swapTimer.restart()
    }

    Timer {
        id: swapTimer
        // Just long enough for the fade-out to finish.
        interval: 240
        onTriggered: {
            root.applied = root.wanted
            revealTimer.restart()
        }
    }
    Timer {
        id: revealTimer
        // Hyprland animates the layer when its geometry changes; coming back
        // during that jump reads as a pop-in.
        interval: 320
        onTriggered: root.hidden = false
    }

    readonly property string barPosition: applied
    // Where the utility pill a keybind should use lives: the bottom one, unless
    // the bar is sitting there.
    readonly property string utilEdge: applied === "bottom" ? "left" : "bottom"
    readonly property bool barVertical: applied === "left" || applied === "right"

    // Distance from the bar's edge to the first pixel a panel may use
    readonly property int panelTop: barH + panelGap

    // Margins for a panel pinned to a screen corner: the side the bar is on has
    // to clear it, the other three only keep the usual breathing room.
    readonly property int marginTop: applied === "top" ? panelTop : edgeGap
    readonly property int marginBottom: applied === "bottom" ? panelTop : edgeGap
    readonly property int marginLeft: applied === "left" ? panelTop : edgeGap
    readonly property int marginRight: applied === "right" ? panelTop : edgeGap
    // Corner-pinned panels hang from the bottom edge only when the bar is there
    readonly property bool pinBottom: applied === "bottom"

    // Where a panel that drops out of a bar pill belongs, in window coords.
    // On a horizontal bar it tracks the pill across the screen and is pinned to
    // the bar's edge; on a vertical bar the two axes swap roles.
    function panelX(winW, cardW, pillX) {
        if (!barVertical)
            return Math.max(edgeGap, Math.min(winW - cardW - edgeGap, pillX - cardW / 2))
        return applied === "left" ? panelTop : winW - cardW - panelTop
    }

    function panelY(winH, cardH, pillY) {
        if (barVertical)
            return Math.max(edgeGap, Math.min(winH - cardH - edgeGap, pillY - cardH / 2))
        return applied === "top" ? panelTop : winH - cardH - panelTop
    }

    // Transform origin for the grow-out-of-its-pill open animation: the corner
    // or point of the card that faces the bar.
    function originX(cardX, cardW, pillX) {
        if (!barVertical) return Math.max(0, Math.min(cardW, pillX - cardX))
        return applied === "left" ? 0 : cardW
    }

    function originY(cardY, cardH, pillY) {
        if (barVertical) return Math.max(0, Math.min(cardH, pillY - cardY))
        return applied === "top" ? 0 : cardH
    }
}
