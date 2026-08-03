import QtQuick

import "root:/services" as Services

// A reading as a vessel with liquid in it. The surface never sits still: two
// sine waves of different length and speed cross each other, which is what
// keeps it from reading as a moving sawtooth.
//
// Drawn on a timer rather than on every animation frame -- a slow swell does
// not need 60 of them a second, and this can be on screen several times over.
Canvas {
    id: root

    // 0..1, how full it is.
    property real level: 0
    // "circle" or "rect".
    property string shape: "circle"
    property real radius_: 12
    // How far inside the item the vessel sits: a dial keeps its ring clear.
    property real inset: 0

    property color color_: Services.Colors.ghost
    // Same opt-in gradient the rest of the shell wears on an active accent:
    // two neighbouring tones of the scheme, horizontal, never a third colour.
    property bool gradient_: Services.Prefs.useGradients
    // Height of the swell in pixels, and how long one pass takes.
    property real waveAmp: 3
    property int periodMs: 4200
    // Off screen it must not paint: a panel that is closed still has its
    // canvas alive.
    property bool running: true

    property real phase: 0
    onLevelChanged: requestPaint()
    onGradient_Changed: requestPaint()
    onColor_Changed: requestPaint()
    Component.onCompleted: requestPaint()

    Timer {
        running: root.running && root.visible
        interval: 40
        repeat: true
        onTriggered: {
            root.phase = (root.phase + 2 * Math.PI * interval / root.periodMs) % (2 * Math.PI)
            root.requestPaint()
        }
    }

    onPaint: {
        const ctx = getContext("2d")
        ctx.reset()
        const w = width, h = height
        const f = Math.max(0, Math.min(1, root.level))
        if (f <= 0.001) return

        ctx.save()
        ctx.beginPath()
        if (root.shape === "circle") {
            ctx.arc(w / 2, h / 2, Math.min(w, h) / 2 - root.inset, 0, Math.PI * 2)
        } else {
            const r = root.radius_, i = root.inset
            ctx.moveTo(i + r, i)
            ctx.arcTo(w - i, i, w - i, h - i, r)
            ctx.arcTo(w - i, h - i, i, h - i, r)
            ctx.arcTo(i, h - i, i, i, r)
            ctx.arcTo(i, i, w - i, i, r)
            ctx.closePath()
        }
        ctx.clip()

        // Full and empty have no surface to ripple, so the swell is faded out
        // at both ends -- otherwise a full vessel spills over its own rim.
        const amp = root.waveAmp * Math.min(1, Math.min(f, 1 - f) * 8)
        const base = h - h * f
        ctx.beginPath()
        ctx.moveTo(0, h)
        ctx.lineTo(0, base)
        for (let x = 0; x <= w; x += 4) {
            const y = base
                + Math.sin(x / w * Math.PI * 2 + root.phase) * amp
                + Math.sin(x / w * Math.PI * 3.7 - root.phase * 1.6) * amp * 0.45
            ctx.lineTo(x, y)
        }
        ctx.lineTo(w, h)
        ctx.closePath()
        if (root.gradient_) {
            const g = ctx.createLinearGradient(0, 0, w, 0)
            const d = Services.Colors.gradientDepth
            const a = root.color_.a
            const lit = Services.Colors.lift(root.color_, d)
            const dark = Services.Colors.lift(root.color_, -d)
            g.addColorStop(0, Qt.rgba(lit.r, lit.g, lit.b, a))
            g.addColorStop(0.5, root.color_)
            g.addColorStop(1, Qt.rgba(dark.r, dark.g, dark.b, a))
            ctx.fillStyle = g
        } else {
            ctx.fillStyle = root.color_
        }
        ctx.fill()
        ctx.restore()
    }
}
