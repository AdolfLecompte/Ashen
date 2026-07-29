import QtQuick

import "root:/services" as Services

// Filled sparkline. Feed one or two histories (oldest first). Values are read
// as percentages unless `autoScale` is set, in which case the window's own peak
// sets the top of the plot — that is what the network rates need, since KB/s
// has no ceiling.
Canvas {
    id: root

    property var primary: []
    property var secondary: []
    property color primaryStroke: Services.Colors.ghost
    property color primaryFill: Services.Colors.ghostAlpha(0.16)
    property color secondaryStroke: Services.Colors.mist
    property color secondaryFill: Services.Colors.ghostAlpha(0.07)

    // Auto-scale keeps a flat-but-nonzero line from filling the whole box:
    // `minTop` is the smallest peak the plot will ever scale to.
    property bool autoScale: false
    property real minTop: 1
    property int gridLines: 0
    property real lineWidth: 2

    readonly property real plotTop: {
        if (!autoScale) return 100
        let peak = minTop
        for (const h of [primary, secondary]) {
            if (!h) continue
            for (const v of h) peak = Math.max(peak, v)
        }
        return peak
    }

    onPrimaryChanged: requestPaint()
    onSecondaryChanged: requestPaint()
    onPlotTopChanged: requestPaint()
    Component.onCompleted: requestPaint()
    Connections {
        target: Services.Colors
        function onGhostChanged() { root.requestPaint() }
    }

    function drawSeries(ctx, h, stroke, fill) {
        if (!h || h.length < 2) return
        let step = width / (h.length - 1)
        let y = v => height - Math.max(0, Math.min(1, v / root.plotTop)) * height
        ctx.beginPath()
        ctx.moveTo(0, y(h[0]))
        for (let i = 1; i < h.length; i++) ctx.lineTo(i * step, y(h[i]))
        ctx.strokeStyle = stroke
        ctx.lineWidth = root.lineWidth
        ctx.stroke()
        ctx.lineTo(width, height)
        ctx.lineTo(0, height)
        ctx.closePath()
        ctx.fillStyle = fill
        ctx.fill()
    }

    onPaint: {
        let ctx = getContext("2d")
        ctx.reset()
        ctx.clearRect(0, 0, width, height)
        if (gridLines > 0) {
            ctx.strokeStyle = Services.Colors.ghostAlpha(0.08)
            ctx.lineWidth = 1
            for (let g = 1; g < gridLines + 1; g++) {
                let gy = (height / (gridLines + 1)) * g
                ctx.beginPath(); ctx.moveTo(0, gy); ctx.lineTo(width, gy); ctx.stroke()
            }
        }
        // secondary first so the primary series reads on top
        drawSeries(ctx, secondary, secondaryStroke, secondaryFill)
        drawSeries(ctx, primary, primaryStroke, primaryFill)
    }
}
