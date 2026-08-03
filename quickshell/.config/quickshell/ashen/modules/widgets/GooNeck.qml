import QtQuick

// The bridge of goo tying a panel to the thing it fell out of, until it thins
// out and pinches off. Takes numbers, not services, so a panel hanging off the
// bar and one hanging off a screen-edge peek share it.
Canvas {
    id: neck

    // Where the neck is centred, in the parent's coordinates.
    property real pillCX: 0
    // How wide the thing it grew out of is. The neck is drawn in a box twice
    // this wide so the curve has room to bulge.
    property real pillW: 44
    // With a floor: below about 30 px the bridge reads as a scratch rather
    // than as something being pulled apart. DropCard had this and the three
    // hand-written copies did not, so a small chip drew a hairline.
    readonly property real neckW: Math.max(30, pillW)
    // The two edges it spans: the one it is anchored to, and the facing edge of
    // the card. Which is on top is worked out from `fromBelow`.
    property real barEdge: 0
    property real cardEdge: 0
    // Half the card's width, so a narrow card gets a narrow neck rather than
    // one wider than the panel it feeds.
    property real cardHalfW: 0
    // 0 = still attached and at its fattest, 1 = pinched off.
    property real pinch: 0
    // The source is below the card (the bar is on the bottom edge), so the
    // wide end of the neck is at the bottom.
    property bool fromBelow: false
    // The caller's own gate: a neck only makes sense pulling up or down, and
    // sideways it would be a rope across the screen.
    property bool active: true
    property color fillColor: "transparent"

    readonly property real span: Math.abs(cardEdge - barEdge)
    readonly property bool detached: fromBelow ? cardEdge < barEdge : cardEdge > barEdge

    visible: active && detached && pinch > 0.001 && pinch < 1 && span > 1
    opacity: 1 - Math.pow(pinch, 2)

    x: pillCX - neckW
    width: neckW * 2
    y: Math.min(barEdge, cardEdge)
    height: Math.max(0, span)

    onPinchChanged: requestPaint()
    onHeightChanged: requestPaint()
    onFillColorChanged: requestPaint()

    onPaint: {
        const ctx = getContext("2d")
        ctx.reset()
        if (height <= 0) return
        const mid = width / 2
        // The end at the bar is a little narrower than the pill itself, so the
        // neck reads as drawn out of it rather than as the pill stretching.
        const wBar = neck.neckW / 2 * 0.72
        const wCard = Math.min(neck.cardHalfW, neck.neckW / 2)
        const waist = Math.min(wBar, wCard) * (1 - neck.pinch)
        const top = neck.fromBelow ? wCard : wBar
        const bottom = neck.fromBelow ? wBar : wCard

        ctx.fillStyle = neck.fillColor
        ctx.beginPath()
        ctx.moveTo(mid - top, 0)
        ctx.quadraticCurveTo(mid - waist, height / 2, mid - bottom, height)
        ctx.lineTo(mid + bottom, height)
        ctx.quadraticCurveTo(mid + waist, height / 2, mid + top, 0)
        ctx.closePath()
        ctx.fill()
    }
}
