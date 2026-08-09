import QtQuick
import "root:/services" as Services

// ── Dynamic-island morph ────────────────────────────────────────────────────
// A panel that IS its pill, grown up: it starts as a copy of the pill's rect
// and swells into the card, height first and width trailing with a hair of
// overshoot. The numbers came verbatim from MediaPanel and Calendar.
Item {
    id: root

    // Open state, straight off the panel's AppState flag.
    property bool shown: false

    // The pill it grows out of, and the card it grows into.
    property real pillW: 1
    property real pillH: 1
    property real pillCX: 0
    property real pillCY: 0
    property real openW: 100
    property real openH: 100

    // What the blob is made of. Transparent for a card whose content already
    // carries its own plates and wants no container around them.
    property color plateColor: Services.Colors.surfacePanel

    // The goo bridge back to the bar. Off for a panel that does not hang from
    // one, and never drawn on a vertical bar.
    property bool neck: true

    // Which axis leads the growth. A card dropping out of the bar elongates
    // downwards first, but one that comes out of the SIDE of its capsule has to
    // sweep sideways, or it reads as falling from somewhere it never was.
    property bool sideways: false
    readonly property int leadMs: 360
    readonly property int trailMs: 560

    // Where it lands. Left alone, it goes where a panel dropping out of that
    // pill belongs -- which is a question about the BAR. A morph that happens
    // somewhere else (the lock screen has no bar) names its own spot instead.
    property real openXOverride: NaN
    property real openYOverride: NaN

    // True once the surface has landed and the morph is armed. The panel
    // mirrors it into AppState -- which flag it is differs per panel, so it is
    // not set here.
    property bool morphing: false

    // In "window" style the card never becomes the pill: it just appears where
    // it would have dropped. A capsule that hides itself anyway leaves a hole
    // and half a morph -- the pill only stands aside when the card is really
    // wearing its face. This is the only thing a capsule should ask.
    readonly property bool plain: plate.plain
    readonly property bool wearingFace: root.morphing && !plate.plain

    // Children go inside the blob, clipped by it and positioned against it.
    // The pieces this file owns are assigned to `data` by hand further down:
    // with the default property aliased away, they would otherwise try to
    // become children of the very rectangle they build.
    default property alias content: plate.data

    // The drivers, published for the shared items to interpolate against.
    property alias fall: plate.fall          // travel from the bar to the resting spot
    property alias stretch: plate.stretch    // height
    property alias spread: plate.spread      // width
    // 0 = shared items sit in the pill's arrangement, 1 = the card's.
    property alias morph: plate.morph
    // Fade for everything that exists only in the card
    property alias contentAmt: plate.contentAmt

    // Where the blob actually is, for anything that has to line up with it.
    readonly property alias plateX: plate.x
    readonly property alias plateY: plate.y
    readonly property alias plateW: plate.width
    readonly property alias plateH: plate.height

    function lerp(a, b, t) { return a + (b - a) * t }
    function mix(c1, c2, t) {
        return Qt.rgba(c1.r + (c2.r - c1.r) * t,
                       c1.g + (c2.g - c1.g) * t,
                       c1.b + (c2.b - c1.b) * t,
                       c1.a + (c2.a - c1.a) * t)
    }

    // A layer surface is not presented on the frame it is asked for, so a morph
    // started at click time spends its first ~200 ms off screen and only its
    // tail is ever seen. Hold the pill, let the surface land, then run.
    onShownChanged: {
        if (shown) {
            arm.restart()
        } else {
            arm.stop()
            root.morphing = false
            openAnim.stop()
            closeAnim.start()
            closeDelay.restart()
        }
    }
    // The window has to stay mapped through the close: the panel asks this.
    readonly property bool closing: closeDelay.running

    data: [

    Timer {
        id: arm
        interval: Services.Sizes.panelArmMs
        onTriggered: {
            root.morphing = true
            closeAnim.stop()
            // The style may have changed since it last closed.
            plate.restDrivers()
            openAnim.start()
        }
    },

    // Long enough to cover the slowest leg of the morph back into the pill
    Timer { id: closeDelay; interval: 560 },

    // The goo bridge, drawn under the card so the card's own edge hides where
    // the two meet. Alive only while the blob is on its way out of the bar.
    GooNeck {
        active: root.neck && !Services.Sizes.barVertical
        pillCX: root.pillCX
        pillW: root.pillW
        fromBelow: Services.Sizes.barPosition === "bottom"
        barEdge: Services.Sizes.barPosition === "bottom"
            ? root.height - Services.Sizes.barH : Services.Sizes.barH
        cardEdge: Services.Sizes.barPosition === "bottom"
            ? plate.y + plate.height : plate.y
        cardHalfW: plate.width / 2
        pinch: Math.max(0, Math.min(1, plate.fall / 0.55))
        fillColor: Services.Colors.surfacePanel
    },

    Rectangle {
        id: plate

        // Where the grown-up card wants to end up: it still tracks its pill and
        // follows the bar around.
        readonly property real openX: isNaN(root.openXOverride)
            ? Services.Sizes.panelX(root.width, root.openW, root.pillCX)
            : root.openXOverride
        readonly property real openY: isNaN(root.openYOverride)
            ? Services.Sizes.panelY(root.height, root.openH, root.pillCY)
            : root.openYOverride

        // Only drawn once the morph is actually armed, so the pill never has to
        // share the screen with a copy of itself.
        visible: root.morphing || closeDelay.running

        // "Window" style: the drivers land on 1 at once and only the opacity
        // moves, so the card appears where it would have dropped without
        // becoming the pill first. The morph timings below are untouched.
        readonly property bool plain: Services.Prefs.panelStyle === "plain"
        property real plainFade: 0

        // Where the drivers rest while closed. In "window" they stay landed -- the
        // card never becomes the pill -- but in "transform" they must be back at
        // zero. The style can change between openings, so this is applied on the
        // way in rather than assumed.
        function restDrivers() {
            const v = plate.plain ? 1 : 0
            plate.fall = v; plate.stretch = v; plate.spread = v; plate.morph = v
            plate.contentAmt = plate.plain ? 1 : 0
            plate.plainFade = 0
        }
        onPlainChanged: if (!root.shown) plate.restDrivers()

        property real fall: 0
        property real stretch: 0
        property real spread: 0
        // Deliberately started late: the box opens first and the contents
        // rearrange inside it afterwards, never both at once.
        property real morph: 0
        property real contentAmt: 0

        // Explicit animations rather than Behaviors with direction-dependent
        // durations: a `root.opening ? a : b` inside a Behavior is read with
        // the *old* value of the flag, so the close silently ran with the open
        // timings. Two named animations leave no room for that.
        ParallelAnimation {
            id: openAnim
            NumberAnimation {
                target: plate; property: "plainFade"; to: 1
                duration: plate.plain ? 260 : 0; easing.type: Services.Sizes.easeOut
            }
            NumberAnimation {
                target: plate; property: "fall"; to: 1
                duration: plate.plain ? 0 : 460; easing.type: Services.Sizes.easeOut
            }
            // The leading axis elongates as the blob detaches; the trailing one
            // lands wide with a hair of overshoot -- the flatten-on-impact part.
            // The overshoot is tiny (~5 px): a real bounce reads as a pop.
            NumberAnimation {
                target: plate; property: "stretch"; to: 1
                duration: plate.plain ? 0 : (root.sideways ? root.trailMs : root.leadMs)
                easing.type: root.sideways ? Easing.OutBack : Services.Sizes.easeOut
                easing.overshoot: Services.Sizes.overshoot
            }
            NumberAnimation {
                target: plate; property: "spread"; to: 1
                duration: plate.plain ? 0 : (root.sideways ? root.leadMs : root.trailMs)
                easing.type: root.sideways ? Services.Sizes.easeOut : Easing.OutBack
                easing.overshoot: Services.Sizes.overshoot
            }
            // Box first, contents after: the shared items hold the pill's
            // arrangement while the blob grows around them, then travel.
            SequentialAnimation {
                PauseAnimation { duration: plate.plain ? 0 : 200 }
                NumberAnimation {
                    target: plate; property: "morph"; to: 1
                    duration: plate.plain ? 0 : 340; easing.type: Services.Sizes.easeOut
                }
            }
            // The card-only extras arrive last, filling the gaps the travelling
            // items have opened up by then.
            SequentialAnimation {
                PauseAnimation { duration: plate.plain ? 0 : 380 }
                NumberAnimation { target: plate; property: "contentAmt"; to: 1; duration: plate.plain ? 0 : 200 }
            }
        }

        // Closing is not the opening backwards: the extras leave, the items
        // regroup into the pill, and only then does the shape collapse -- the
        // same order, mirrored, so the box is never smaller than its contents.
        ParallelAnimation {
            id: closeAnim
            NumberAnimation {
                target: plate; property: "plainFade"; to: 0
                duration: plate.plain ? 200 : 0; easing.type: Services.Sizes.easeIn
            }
            NumberAnimation { target: plate; property: "contentAmt"; to: 0; duration: plate.plain ? 0 : 90 }
            SequentialAnimation {
                PauseAnimation { duration: plate.plain ? 0 : 40 }
                NumberAnimation {
                    target: plate; property: "morph"; to: plate.plain ? 1 : 0
                    duration: plate.plain ? 0 : 260; easing.type: Services.Sizes.easeInOut
                }
            }
            SequentialAnimation {
                PauseAnimation { duration: plate.plain ? 0 : 160 }
                ParallelAnimation {
                    NumberAnimation {
                        target: plate; property: "fall"; to: plate.plain ? 1 : 0
                        duration: plate.plain ? 0 : 340; easing.type: Services.Sizes.easeInOut
                    }
                    NumberAnimation {
                        target: plate; property: "stretch"; to: plate.plain ? 1 : 0
                        duration: plate.plain ? 0 : 300; easing.type: Services.Sizes.easeInOut
                    }
                    NumberAnimation {
                        target: plate; property: "spread"; to: plate.plain ? 1 : 0
                        duration: plate.plain ? 0 : 300; easing.type: Services.Sizes.easeInOut
                    }
                }
            }
        }

        width: root.pillW + (root.openW - root.pillW) * spread
        height: (root.pillH + (root.openH - root.pillH) * stretch)
                * (plate.plain ? 0.06 + 0.94 * plate.plainFade : 1)
        x: root.pillCX + (openX + root.openW / 2 - root.pillCX) * fall - width / 2
        y: plate.plain ? openY
           : root.pillCY + (openY + root.openH / 2 - root.pillCY) * fall - height / 2

        // Pill corner while small, card corner once open
        opacity: plate.plain ? plate.plainFade : 1
        radius: Services.Sizes.pillR + (20 - Services.Sizes.pillR) * Math.min(1, spread)
        color: root.plateColor
        clip: true

        MouseArea { anchors.fill: parent; onClicked: {} }
    }
    ]
}
