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
    // The roles two dozen loose ghostAlpha() values were approximating. Bound,
    // so a recolour carries through. NOTHING outside this block writes a fill
    // alpha -- that is how one hover ended up with five strengths.
    readonly property color fillInset:  Qt.rgba(ghost.r, ghost.g, ghost.b, 0.06)  // card sunk into a panel
    readonly property color fillLine:   Qt.rgba(ghost.r, ghost.g, ghost.b, 0.12)  // dividers, meter tracks
    readonly property color fillRest:   Qt.rgba(ghost.r, ghost.g, ghost.b, 0.20)  // a control at rest
    readonly property color fillHover:  Qt.rgba(ghost.r, ghost.g, ghost.b, 0.30)  // under the pointer
    readonly property color fillSunken: Qt.rgba(ghost.r, ghost.g, ghost.b, 0.45)  // held, or on without the accent

    // Two backgrounds, not nine: a panel, and something sitting on the bar.
    readonly property color surfacePanel: Qt.rgba(surface.r, surface.g, surface.b, 0.95)
    readonly property color surfacePill:  Qt.rgba(surface.r, surface.g, surface.b, 0.82)
    // There is no hover fill: things grow and their contents lift to snow.

    // Anything asking "am I on a light background" asks this, never a colour.
    readonly property bool lightTheme: root.lum(root.abyss) > 0.5

    // The veil a modal drops, always the scheme's darkest tone: on a light
    // palette that is the text colour, and a veil made of the background would
    // separate nothing from nothing.
    readonly property color scrimBase: root.darkTone
    readonly property color scrim: Qt.rgba(scrimBase.r, scrimBase.g, scrimBase.b, 0.55)
    function surfaceAlpha(a) { return Qt.rgba(surface.r, surface.g, surface.b, a) }
    function snowAlpha(a) { return Qt.rgba(snow.r, snow.g, snow.b, a) }

    // Relative luminance, the real one: sRGB has to come out of its curve
    // before the channels can be weighed against each other, or every mid tone
    // reads brighter than it is.
    function lum(c) {
        function lin(v) { return v <= 0.04045 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4) }
        return 0.2126 * lin(c.r) + 0.7152 * lin(c.g) + 0.0722 * lin(c.b)
    }
    // WCAG contrast ratio, 1..21. Takes hexes or colours.
    function contrast(a, b) {
        const ca = typeof a === "string" ? Qt.color(a) : a
        const cb = typeof b === "string" ? Qt.color(b) : b
        const la = root.lum(ca), lb = root.lum(cb)
        return (Math.max(la, lb) + 0.05) / (Math.min(la, lb) + 0.05)
    }

    // Text that can be read on `bg`; 0.179 is the crossover and both sides
    // clear 4:1. Which extreme is actually the dark one is measured too: on a
    // light palette `abyss` is the pale background and `snow` the near-black
    // text, so naming them by hand gets it backwards.
    readonly property color darkTone: root.lum(root.abyss) <= root.lum(root.snow) ? root.abyss : root.snow
    readonly property color lightTone: root.lum(root.abyss) > root.lum(root.snow) ? root.abyss : root.snow

    function onColor(bg) { return root.lum(bg) > 0.179 ? root.darkTone : root.lightTone }

    // Mix `c` towards `t` by `k`.
    function tint(c, t, k) {
        return Qt.rgba(c.r + (t.r - c.r) * k,
                       c.g + (t.g - c.g) * k,
                       c.b + (t.b - c.b) * k, c.a)
    }

    // ── What to paint ON a surface ───────────────────────────────────────
    // NOT named `onSomething`: QML reads a leading `on` + capital as a signal
    // handler, so `onGhost` was never a property and every caller got black.
    // 0.10 of the accent is mixed back in, as far as it goes before 4.5:1.
    readonly property color accentText: {
        const base = root.lum(root.ghost) > 0.179 ? root.darkTone : root.lightTone
        const k = 0.10
        return Qt.rgba(base.r + (root.ghost.r - base.r) * k,
                       base.g + (root.ghost.g - base.g) * k,
                       base.b + (root.ghost.b - base.b) * k, 1)
    }
    readonly property color surfaceText: {
        const base = root.lum(root.surface) > 0.179 ? root.darkTone : root.lightTone
        const k = 0.10
        return Qt.rgba(base.r + (root.ghost.r - base.r) * k,
                       base.g + (root.ghost.g - base.g) * k,
                       base.b + (root.ghost.b - base.b) * k, 1)
    }

    // A BODY on top of something -- a toggle knob, a slider handle. It is not
    // text, so nobody has to read anything inside it: it can take much more of
    // the accent than a letter can, and that is what stops it reading as a
    // black dot dropped on the theme.
    readonly property real bodyTint: 0.28
    readonly property color accentBody: {
        const base = root.lum(root.ghost) > 0.179 ? root.darkTone : root.lightTone
        const k = root.bodyTint
        return Qt.rgba(base.r + (root.ghost.r - base.r) * k,
                       base.g + (root.ghost.g - base.g) * k,
                       base.b + (root.ghost.b - base.b) * k, 1)
    }
    readonly property color surfaceBody: {
        const base = root.lum(root.surface) > 0.179 ? root.darkTone : root.lightTone
        const k = root.bodyTint
        return Qt.rgba(base.r + (root.ghost.r - base.r) * k,
                       base.g + (root.ghost.g - base.g) * k,
                       base.b + (root.ghost.b - base.b) * k, 1)
    }

    // The same colour moved towards the palette's lightest or darkest tone.
    // Mixed, not Qt.lighter/darker: those work on HSV value and give up at the
    // ends of the range. One colour at two depths, never two colours.
    function lift(c, amt) {
        const t = amt > 0 ? root.lightTone : root.darkTone
        const k = Math.abs(amt)
        return Qt.rgba(c.r + (t.r - c.r) * k,
                       c.g + (t.g - c.g) * k,
                       c.b + (t.b - c.b) * k, c.a)
    }

    // Opt-in accent gradient (Theme tab). ONE tone lit from the left, so a
    // filled pill reads as a surface with a light on it. Backgrounds never use
    // it. The travel is one number, because the Canvas-drawn copies build the
    // same gradient by hand and cannot read the Gradient object.
    readonly property real gradientDepth: 0.28
    // On a light palette the lit end moves TOWARDS the background, and a pill
    // whose bright end melts into the panel behind it loses its edge -- so
    // there the light end is held back and the shaded end goes further.
    readonly property real gradientUp: root.lightTheme ? root.gradientDepth * 0.45 : root.gradientDepth
    readonly property real gradientDown: root.lightTheme ? root.gradientDepth * 1.25 : root.gradientDepth
    readonly property Gradient accentGradient: Gradient {
        orientation: Gradient.Horizontal
        GradientStop { position: 0.0; color: root.lift(root.ghost, root.gradientUp) }
        GradientStop { position: 0.5; color: root.ghost }
        GradientStop { position: 1.0; color: root.lift(root.ghost, -root.gradientDown) }
    }

    // ── Live reload: the JSON is written by the Theme tab or by matugen ──
    // matugen writes both faces at once, so switching mode is a re-pick here,
    // not a re-run. A hand-picked scheme writes one flat object, used as-is.
    property var scheme: null
    onSchemeChanged: root.applyScheme()
    Connections {
        target: Prefs
        function onThemeModeChanged() { root.applyScheme() }
    }

    function applyScheme() {
        const all = root.scheme
        if (!all) return
        const s = (all.light && all.dark) ? (Prefs.themeMode === "light" ? all.light : all.dark) : all
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
        // A light scheme also ships the container tone of each accent, taken only
        // when it still stands out against a panel -- on a colourful wallpaper that
        // tone is a pastel, and the accent is a glyph colour in most of the shell.
        // scripts/ashen-accent.sh repeats this rule for everything outside the shell.
        if (s.ghostAlt && root.contrast(s.ghostAlt, root.surface) >= 4.5) root.ghost = s.ghostAlt
        if (s.shadeAlt && root.contrast(s.shadeAlt, root.surface) >= 4.5) root.shade = s.shadeAlt
    }

    FileView {
        id: schemeFile
        path: Paths.scheme
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                root.scheme = JSON.parse(text())
                root.applyScheme()
            } catch (e) {
                console.warn("[Colors] could not parse ashen_scheme.json:", e)
            }
        }
    }
}
