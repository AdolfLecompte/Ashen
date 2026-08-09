import QtQuick

import "root:/services" as Services

// A reading as a vessel with liquid in it. Two sine waves of different length
// and speed cross, which is what keeps the surface from reading as a moving
// sawtooth. Painted on a timer, not every frame: a slow swell does not need 60
// a second, and this can be on screen several times over.
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
    // The liquid is one solid tone. The shell's gradient is for an accent that
    // sits still; on a surface that keeps moving the two tones read as a slick
    // rather than as a light. Still opt-in per caller, just off by default.
    property bool gradient_: false
    // Height of the swell in pixels, and how long one pass takes. Kept low: the
    // point is that the surface is alive, not that the vessel is being shaken.
    property real waveAmp: 3.5
    property int periodMs: 4200
    // Off screen it must not paint: a panel that is closed still has its
    // canvas alive.
    property bool running: true

    // One phase per wave, each wrapped at its own turn. A single phase shared
    // by two waves running at different speeds cannot wrap without one of them
    // jumping, which is the tear that made the loop restart.
    property real phaseA: 0
    property real phaseB: 0
    onLevelChanged: requestPaint()
    onGradient_Changed: requestPaint()
    onColor_Changed: requestPaint()
    Component.onCompleted: requestPaint()

    readonly property real tau: Math.PI * 2

    Timer {
        running: root.running && root.visible
        interval: 33
        repeat: true
        onTriggered: {
            root.phaseA = (root.phaseA + root.tau * interval / root.periodMs) % root.tau
            root.phaseB = (root.phaseB + root.tau * interval / (root.periodMs * 0.62)) % root.tau
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
        // Whole numbers of cycles across the width, so the surface meets both
        // walls at the same height and the swell reads as one rolling motion
        // rather than a wave shape that happens to be sliding past.
        for (let x = 0; x <= w; x += 2) {
            const u = x / w * root.tau
            const y = base
                + Math.sin(u + root.phaseA) * amp
                + Math.sin(u * 2 - root.phaseB) * amp * 0.45
            ctx.lineTo(x, y)
        }
        ctx.lineTo(w, h)
        ctx.closePath()
        if (root.gradient_) {
            const g = ctx.createLinearGradient(0, 0, w, 0)
            const a = root.color_.a
            const lit = Services.Colors.lift(root.color_, Services.Colors.gradientUp)
            const dark = Services.Colors.lift(root.color_, -Services.Colors.gradientDown)
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
