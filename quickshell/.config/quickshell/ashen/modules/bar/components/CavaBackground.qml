import Quickshell.Io
import QtQuick
import "root:/services" as Services

Item {
    id: root
    anchors.fill: parent
    z: -1

    readonly property var barValues: Services.Cava.barValues
    readonly property bool isActive: Services.Cava.isActive
    opacity: isActive ? 1.0 : 0.0
    Behavior on opacity { NumberAnimation { duration: 400 } }

    // Bars grow inwards from the screen edge the bar is docked to, so on a side
    // bar they lie down and run horizontally instead of standing up.
    readonly property string edge: Services.Sizes.barPosition
    readonly property bool vertical: Services.Sizes.barVertical

    onBarValuesChanged: canvas.requestPaint()
    onEdgeChanged: canvas.requestPaint()

    Canvas {
        id: canvas
        anchors.fill: parent

        // One bar, drawn from (x, y) with the far end rounded
        function drawBar(ctx, x, y, w, h, r) {
            r = Math.min(r, w / 2, h / 2)
            if (h <= 0) return
            if (h <= r) {
                ctx.beginPath()
                ctx.arc(x + w / 2, y + h - h / 2, Math.min(w / 2, h / 2), 0, Math.PI * 2)
                ctx.fill()
                return
            }
            ctx.beginPath()
            ctx.moveTo(x, y)
            ctx.lineTo(x + w, y)
            ctx.lineTo(x + w, y + h - r)
            ctx.arcTo(x + w, y + h, x + w - r, y + h, r)
            ctx.lineTo(x + r, y + h)
            ctx.arcTo(x, y + h, x, y + h - r, r)
            ctx.lineTo(x, y)
            ctx.closePath()
            ctx.fill()
        }

        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            if (root.barValues.length === 0) return

            var n = root.barValues.length
            // Slot: the strip each bar owns across the bar's long axis.
            // Depth: how far a bar may reach into the bar's short axis.
            var along = root.vertical ? height : width
            var depth = root.vertical ? width : height
            var slot = along / n
            var boost = 2.0

            ctx.fillStyle = Services.Colors.ghostAlpha(0.30)

            // The canvas is rotated so every edge can reuse the same top-down
            // bar drawing: bars always leave the origin edge downwards.
            ctx.save()
            if (root.edge === "bottom") {
                ctx.translate(width, height); ctx.rotate(Math.PI)
            } else if (root.edge === "left") {
                ctx.translate(0, height); ctx.rotate(-Math.PI / 2)
            } else if (root.edge === "right") {
                ctx.translate(width, 0); ctx.rotate(Math.PI / 2)
            }

            for (var i = 0; i < n; i++) {
                var v = Math.max(0, Math.min(100, root.barValues[i])) / 100.0
                var h = Math.min(depth, v * depth * boost)
                canvas.drawBar(ctx, i * slot, 0, Math.max(1, slot - 1), h, Math.min(3, slot / 2))
            }
            ctx.restore()
        }
    }
}
