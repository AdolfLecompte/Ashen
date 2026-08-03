pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    property color abyss:    "#080809"
    property color void_:    "#0f0f11"
    property color crypt:    "#16161a"
    property color surface:  "#1c1c21"
    property color raised:   "#242428"
    property color elevated: "#2e2e34"
    property color snow:     "#e8e8ec"
    property color mist:     "#9090a0"
    property color ash:      "#4a4a54"
    property color ghost:    "#6e6e7a"
    property color shade:    "#4e4e5a"
    property color error_:   "#c87a7a"
    property color neutral:  "#8a8a96"

    function ghostAlpha(a) { return Qt.rgba(ghost.r, ghost.g, ghost.b, a) }

    // ── The accent fill ladder ───────────────────────────────────────────
    // Twenty-four different ghostAlpha() values were in use. These are the
    // roles they were all approximating. Bound, not computed once, so a
    // recolour carries through. Nothing outside this block may write an alpha
    // for a fill: that is how the bar ended up with five different strengths
    // for one hover.
    readonly property color fillInset:  Qt.rgba(ghost.r, ghost.g, ghost.b, 0.06)  // card sunk into a panel
    readonly property color fillLine:   Qt.rgba(ghost.r, ghost.g, ghost.b, 0.12)  // dividers, meter tracks
    readonly property color fillRest:   Qt.rgba(ghost.r, ghost.g, ghost.b, 0.20)  // a control at rest
    readonly property color fillHover:  Qt.rgba(ghost.r, ghost.g, ghost.b, 0.30)  // under the pointer
    readonly property color fillSunken: Qt.rgba(ghost.r, ghost.g, ghost.b, 0.45)  // held, or on without the accent

    // Two backgrounds, not nine: a panel, and something sitting on the bar.
    readonly property color surfacePanel: Qt.rgba(surface.r, surface.g, surface.b, 0.95)
    readonly property color surfacePill:  Qt.rgba(surface.r, surface.g, surface.b, 0.82)
    // There is no hover fill. Nothing on the bar lights up under the pointer:
    // it grows, and its contents lift to snow. A plate that changed colour as
    // well was a third answer to the same question, and the bar flickered
    // under a pointer merely crossing it.
    // The veil a modal drops over the screen. Was hardcoded black, the one
    // colour in the shell that did not come from the scheme.
    readonly property color scrim: Qt.rgba(abyss.r, abyss.g, abyss.b, 0.55)
    function surfaceAlpha(a) { return Qt.rgba(surface.r, surface.g, surface.b, a) }
    function snowAlpha(a) { return Qt.rgba(snow.r, snow.g, snow.b, a) }

    // Relative luminance, the real one: sRGB has to come out of its curve
    // before the channels can be weighed against each other, or every mid tone
    // reads brighter than it is.
    function lum(c) {
        function lin(v) { return v <= 0.04045 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4) }
        return 0.2126 * lin(c.r) + 0.7152 * lin(c.g) + 0.0722 * lin(c.b)
    }
    // Text that can be read on top of `bg`: dark on a light fill, light on a
    // dark one. The accent is whatever matugen pulled out of the wallpaper, so
    // "the accent is light, put dark text on it" is not something the shell can
    // assume — on the current palette `ghost` is a mid grey and it is white
    // that wins. 0.179 is where the two swap over, and either side of it both
    // choices still clear 4:1, so crossing is not a hole to fall into.
    function onColor(bg) { return lum(bg) > 0.179 ? abyss : snow }

    // The same colour, moved towards the palette's lightest or darkest tone.
    // Mixing rather than Qt.lighter/darker because those work on HSV value and
    // give up at the ends of the range: Qt.lighter of a near-black accent is
    // still near-black, and a gradient built on it comes out flat. The hue
    // rides along unchanged, which is the point -- this is one colour at two
    // depths, not two colours. Towards snow and abyss, not pure white and
    // black, so the lift stays inside the scheme.
    function lift(c, amt) {
        const t = amt > 0 ? snow : abyss
        const k = Math.abs(amt)
        return Qt.rgba(c.r + (t.r - c.r) * k,
                       c.g + (t.g - c.g) * k,
                       c.b + (t.b - c.b) * k, c.a)
    }

    // Accent gradient for interactive/active fills, used only when the user
    // enables gradients (Theme tab). ONE tone lit from the left: lighter at
    // that end, the accent itself through the middle, darker at the far end,
    // so a filled pill reads as a surface with a light on it instead of a flat
    // patch. Horizontal, because nearly everything wearing it is a pill or a
    // chip -- wider than it is tall, so across is where there is room for the
    // fall-off to be seen at all.
    // It used to run ghost -> shade, two different scheme entries; on
    // palettes where those two are far apart it read as a colour change rather
    // than as depth, and on matugen palettes where they are close it barely
    // read at all. Backgrounds never use this. Reactive: ghost updates on
    // recolour, so does the gradient.
    // How far the two ends travel from the accent. One number, because the
    // Canvas-drawn copies (PowerMenu's hold fill) have to build the same
    // gradient by hand and cannot read the Gradient object itself.
    readonly property real gradientDepth: 0.28
    readonly property Gradient accentGradient: Gradient {
        orientation: Gradient.Horizontal
        GradientStop { position: 0.0; color: root.lift(root.ghost, root.gradientDepth) }
        GradientStop { position: 0.5; color: root.ghost }
        GradientStop { position: 1.0; color: root.lift(root.ghost, -root.gradientDepth) }
    }

    // ── Live reload: the JSON is written by applyScheme() (Theme tab) or matugen
    //    (Dynamic mode). As soon as the file changes, every component using
    //    Services.Colors.* updates itself -- no quickshell restart needed.
    FileView {
        id: schemeFile
        path: Paths.scheme
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                let s = JSON.parse(text())
                if (s.abyss) root.abyss = s.abyss
                if (s.void_) root.void_ = s.void_
                if (s.crypt) root.crypt = s.crypt
                if (s.surface) root.surface = s.surface
                if (s.raised) root.raised = s.raised
                if (s.elevated) root.elevated = s.elevated
                if (s.snow) root.snow = s.snow
                if (s.mist) root.mist = s.mist
                if (s.ash) root.ash = s.ash
                if (s.ghost) root.ghost = s.ghost
                if (s.shade) root.shade = s.shade
                if (s.error_) root.error_ = s.error_
                if (s.neutral) root.neutral = s.neutral
            } catch (e) {
                console.log("[Colors] error parseando ashen_scheme.json:", e)
            }
        }
    }
}
