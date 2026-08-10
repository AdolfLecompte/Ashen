import QtQuick

import "root:/services" as Services

// A run of readings over time: the line, and the ground under it. Drawn through
// the midpoints between samples -- 40 straight segments read as a saw, and a
// spline through every sample overshoots on a spike and dips below zero.
Canvas {
    id: root

    // The samples, oldest first.
    property var values: []
    // What counts as the top of the chart.
    property real maxValue: 100
    // The line itself. The ground under it is the same colour mixed into the
    // surface -- opaque, so it is one tone whatever is behind the panel.
    property color color_: Services.Colors.ghost
    property real groundMix: 0.22
    property int lineWidth: 2
    // Leaves room for the stroke's own width at the top and bottom.
    property int padding: 3
    // Plateaus instead of a curve: each sample holds its own slot and the
    // change happens between them, over a rounded joint. A reading taken every
    // three hours did not happen smoothly in between, and drawing it as if it
    // did is a shape the data never had.
    property bool stepped: false
    // How round those joints are. Capped by the slot and by the size of the
    // step itself, so a small change cannot bulge past the level it came from.
    property real cornerR: 9

    onSteppedChanged: requestPaint()
    onValuesChanged: requestPaint()
    onColor_Changed: requestPaint()
    Component.onCompleted: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    onPaint: {
        const ctx = getContext("2d")
        ctx.reset()
        const vs = root.values || []
        if (vs.length < 2) return

        const w = width, h = height, p = root.padding
        const top = p, bot = h - p
        const dx = w / (vs.length - 1)
        const cap = Math.max(1, root.maxValue)

        function py(v) {
            const f = Math.max(0, Math.min(1, v / cap))
            return bot - (bot - top) * f
        }

        // The path once, reused for the fill and the stroke: the ground and the
        // line can never disagree about where the curve went.
        function trace() {
            if (root.stepped) {
                // One slot per sample, so the first and last plateaus are as
                // wide as the rest -- points on the edges would give the two
                // ends half a step and read as a slope.
                const slot = w / vs.length
                ctx.moveTo(0, py(vs[0]))
                for (let i = 1; i < vs.length; i++) {
                    const bx = i * slot
                    const y0 = py(vs[i - 1]), y1 = py(vs[i])
                    const r = Math.min(root.cornerR, slot / 2, Math.abs(y1 - y0) / 2)
                    ctx.lineTo(bx - r, y0)
                    ctx.bezierCurveTo(bx, y0, bx, y1, bx + r, y1)
                }
                ctx.lineTo(w, py(vs[vs.length - 1]))
                return
            }
            ctx.moveTo(0, py(vs[0]))
            for (let i = 1; i < vs.length; i++) {
                const x0 = (i - 1) * dx, x1 = i * dx
                const y0 = py(vs[i - 1]), y1 = py(vs[i])
                const mx = (x0 + x1) / 2
                ctx.bezierCurveTo(mx, y0, mx, y1, x1, y1)
            }
        }

        ctx.beginPath()
        trace()
        ctx.lineTo(w, h)
        ctx.lineTo(0, h)
        ctx.closePath()
        ctx.fillStyle = Services.Colors.tint(Services.Colors.surface,
                                             root.color_, root.groundMix)
        ctx.fill()

        ctx.beginPath()
        trace()
        ctx.lineWidth = root.lineWidth
        ctx.lineJoin = "round"
        ctx.lineCap = "round"
        ctx.strokeStyle = root.color_
        ctx.stroke()
    }
}
