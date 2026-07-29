import Quickshell
import Quickshell.Widgets
import QtQuick
import "root:/services" as Services
import "root:/modules/widgets" as Widgets

PanelWindow {
    id: root
    anchors { top: true; left: true; right: true; bottom: true }
    screen: Services.Screens.active
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    // stays mapped through the close animation, so the exit plays in reverse
    readonly property bool shown: Services.AppState.mediaVisible
    visible: shown || closeDelay.running

    // A layer surface is not presented on the frame it is asked for, so a morph
    // started at click time spends its first ~200 ms off screen and only its
    // tail is ever seen. Hold the pill, let the surface land, then run.
    onShownChanged: {
        if (shown) {
            arm.restart()
        } else {
            arm.stop()
            Services.AppState.mediaMorphing = false
            openAnim.stop()
            closeAnim.start()
            closeDelay.restart()
        }
    }
    Timer {
        id: arm
        interval: 200
        onTriggered: {
            Services.AppState.mediaMorphing = true
            closeAnim.stop()
            openAnim.start()
        }
    }
    // Long enough to cover the slowest leg of the morph back into the pill
    Timer { id: closeDelay; interval: 560 }

    readonly property bool opening: Services.AppState.mediaMorphing

    // ── Dynamic-island morph ────────────────────────────────────────────
    // This panel is not a card that appears next to the pill: it IS the pill,
    // grown up. It starts as an exact copy of the pill's rect and swells into
    // the full card, so the two read as one object changing size.
    //
    // The droplet comes from animating the axes apart instead of together: the
    // blob stretches downward first (it falls out of the bar), then the width
    // catches up and spreads with a hair of overshoot, the way a drop flattens
    // when it lands. A goo neck keeps it tied to the bar until it pinches off.
    //
    // What the card actually shows is Widgets.MediaCard, the same item the lock
    // screen mounts. This file only owns the blob and the trip: everything the
    // pill and the card have in common — cover, title, times, the three
    // transport chips — is ONE item that travels between the two layouts,
    // while the card's own extras fade in behind it.
    //
    // The card's size comes from the shared item, so growing the cover there
    // grows the panel here and the two can never disagree.
    readonly property real openW: panelRef.contentW + panelRef.pad * 2
    readonly property real openH: panelRef.artSize + panelRef.pad * 2
    readonly property real pillW: Math.max(1, Services.AppState.mediaPillW)
    readonly property real pillH: Math.max(1, Services.AppState.mediaPillH)
    readonly property real pillCX: Services.AppState.mediaPillCenterX
    readonly property real pillCY: Services.AppState.mediaPillCenterY

    // The player state lives in the shared card; everything here reads it back
    // out rather than keeping a second copy in step.
    readonly property bool hasPlayer: panelRef.hasPlayer
    readonly property var activePlayer: panelRef.activePlayer

    MouseArea {
        anchors.fill: parent
        z: -1
        onClicked: Services.AppState.mediaVisible = false
    }

    FocusScope {
        anchors.fill: parent
        focus: root.shown
        Keys.onEscapePressed: Services.AppState.mediaVisible = false
    }

    // The goo bridge, drawn under the card so the card's own edge hides where
    // the two meet. Alive only while the blob is on its way out of the bar.
    Canvas {
        id: neck

        readonly property bool horizontalBar: !Services.Sizes.barVertical
        // 0 = still fused to the bar, 1 = snapped off
        readonly property real pinch: Math.max(0, Math.min(1, card.fall / 0.55))
        readonly property real cx: root.pillCX
        // Bar edge the drop hangs from, and the card edge facing it
        readonly property real barEdge: Services.Sizes.barPosition === "bottom"
            ? parent.height - Services.Sizes.barH : Services.Sizes.barH
        readonly property real cardEdge: Services.Sizes.barPosition === "bottom"
            ? card.y + card.height : card.y
        readonly property real span: Math.abs(cardEdge - barEdge)

        // Only once the card edge is actually past the bar edge — while the
        // blob is still inside the bar the bridge would be drawn upside down,
        // over the bar itself.
        readonly property bool detached: Services.Sizes.barPosition === "bottom"
            ? cardEdge < barEdge : cardEdge > barEdge

        visible: horizontalBar && detached && pinch > 0.001 && pinch < 1 && span > 1
        opacity: 1 - Math.pow(pinch, 2)

        x: cx - root.pillW
        width: root.pillW * 2
        y: Math.min(barEdge, cardEdge)
        height: Math.max(0, span)

        onPinchChanged: requestPaint()
        onHeightChanged: requestPaint()

        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            if (height <= 0) return
            const mid = width / 2
            // Wide where it meets the bar, card width where it meets the card,
            // and squeezed to nothing at the waist as the drop pulls away
            const wBar = root.pillW / 2 * 0.72
            const wCard = Math.min(card.width / 2, root.pillW / 2)
            const waist = Math.min(wBar, wCard) * (1 - pinch)
            const top = Services.Sizes.barPosition === "bottom" ? wCard : wBar
            const bottom = Services.Sizes.barPosition === "bottom" ? wBar : wCard

            ctx.fillStyle = Services.Colors.surfaceAlpha(0.95)
            ctx.beginPath()
            ctx.moveTo(mid - top, 0)
            ctx.quadraticCurveTo(mid - waist, height / 2, mid - bottom, height)
            ctx.lineTo(mid + bottom, height)
            ctx.quadraticCurveTo(mid + waist, height / 2, mid + top, 0)
            ctx.closePath()
            ctx.fill()
        }
    }

    Rectangle {
        id: card

        // Where the grown-up card wants to end up: same placement rules as
        // before, so it still tracks its pill and follows the bar around.
        readonly property real openX: Services.Sizes.panelX(parent.width, root.openW, root.pillCX)
        readonly property real openY: Services.Sizes.panelY(parent.height, root.openH, root.pillCY)

        // Only drawn once the morph is actually armed, so the pill never has to
        // share the screen with a copy of itself.
        visible: root.opening || closeDelay.running

        function lerp(a, b, t) { return a + (b - a) * t }

        // Three drivers rather than one, so the shape lags behind the motion
        // and the blob deforms on the way instead of scaling rigidly.
        property real fall: 0      // travel from the bar to the resting spot
        property real stretch: 0   // height
        property real spread: 0    // width
        // 0 = shared items sit in the pill's arrangement, 1 = the card's.
        // Deliberately started late: the box opens first and the contents
        // rearrange inside it afterwards, never both at once.
        property real morph: 0
        // Fade for everything that exists only in the card
        property real contentAmt: 0

        // Origin of the pill reference layout, in card coordinates
        readonly property real prColX: pillRef.x + refCol.x
        readonly property real prColY: pillRef.y + refCol.y

        // Chip sizes at each end of the trip
        readonly property real chipSm: Services.Sizes.innerH
        readonly property real playSm: Services.Sizes.innerH

        // Explicit animations rather than Behaviors with direction-dependent
        // durations: a `root.opening ? a : b` inside a Behavior is read with
        // the *old* value of the flag, so the close silently ran with the open
        // timings. Two named animations leave no room for that.
        ParallelAnimation {
            id: openAnim
            NumberAnimation {
                target: card; property: "fall"; to: 1
                duration: 460; easing.type: Easing.OutCubic
            }
            // Height leads: the drop elongates as it detaches from the bar
            NumberAnimation {
                target: card; property: "stretch"; to: 1
                duration: 360; easing.type: Easing.OutCubic
            }
            // Width trails and lands wide: the flatten-on-impact part. The
            // overshoot is tiny (~5 px) — a real bounce reads as a pop.
            NumberAnimation {
                target: card; property: "spread"; to: 1
                duration: 560; easing.type: Easing.OutBack; easing.overshoot: 0.7
            }
            // Box first, contents after: the shared items hold the pill's
            // arrangement while the blob grows around them, then travel.
            SequentialAnimation {
                PauseAnimation { duration: 200 }
                NumberAnimation {
                    target: card; property: "morph"; to: 1
                    duration: 340; easing.type: Easing.OutCubic
                }
            }
            // The card-only extras arrive last, filling the gaps the travelling
            // items have opened up by then.
            SequentialAnimation {
                PauseAnimation { duration: 380 }
                NumberAnimation { target: card; property: "contentAmt"; to: 1; duration: 200 }
            }
        }

        // Closing is not the opening backwards: the extras leave, the items
        // regroup into the pill, and only then does the shape collapse — the
        // same order, mirrored, so the box is never smaller than its contents.
        ParallelAnimation {
            id: closeAnim
            NumberAnimation { target: card; property: "contentAmt"; to: 0; duration: 90 }
            SequentialAnimation {
                PauseAnimation { duration: 40 }
                NumberAnimation {
                    target: card; property: "morph"; to: 0
                    duration: 260; easing.type: Easing.InOutCubic
                }
            }
            SequentialAnimation {
                PauseAnimation { duration: 160 }
                ParallelAnimation {
                    NumberAnimation {
                        target: card; property: "fall"; to: 0
                        duration: 340; easing.type: Easing.InOutCubic
                    }
                    NumberAnimation {
                        target: card; property: "stretch"; to: 0
                        duration: 300; easing.type: Easing.InOutCubic
                    }
                    NumberAnimation {
                        target: card; property: "spread"; to: 0
                        duration: 300; easing.type: Easing.InOutCubic
                    }
                }
            }
        }

        width: root.pillW + (root.openW - root.pillW) * spread
        height: root.pillH + (root.openH - root.pillH) * stretch
        x: root.pillCX + (openX + root.openW / 2 - root.pillCX) * fall - width / 2
        y: root.pillCY + (openY + root.openH / 2 - root.pillCY) * fall - height / 2

        // Pill corner while small, card corner once open
        radius: Services.Sizes.pillR + (20 - Services.Sizes.pillR) * Math.min(1, spread)
        color: Services.Colors.surfaceAlpha(0.95)
        clip: true

        MouseArea { anchors.fill: parent; onClicked: {} }

        // ── Reference layout A: the pill ────────────────────────────────
        // An exact structural copy of MediaPill's row, laid out but never
        // drawn. It exists so the shared items know where the pill puts
        // them, to the pixel, without anyone maintaining a second set of
        // coordinates by hand.
        //
        // Centred, not left-anchored: the real pill is exactly its row plus 10
        // px of margin either side, so centring lands on the same pixels while
        // the card still matches the pill — and once the box starts inflating
        // the contents hold the middle instead of being dragged along by the
        // left edge. The box grows around them; they only move when told to.
        Row {
            id: pillRef
            opacity: 0
            anchors.centerIn: parent
            spacing: 8

            Item {
                id: refArt
                width: Services.Sizes.pillH - 10
                height: Services.Sizes.pillH - 10
                anchors.verticalCenter: parent.verticalCenter
            }

            Column {
                id: refCol
                width: 120
                spacing: 3
                anchors.verticalCenter: parent.verticalCenter

                Text {
                    id: refTitle
                    width: parent.width
                    text: panelRef.titleText
                    font.pixelSize: 11
                    font.bold: true
                    font.family: "JetBrainsMono NF"
                    elide: Text.ElideRight
                }
                // The pill's single "0:12/3:45" as three pieces at zero
                // spacing: in a monospaced face that lays out identically to
                // the joined string, and it lets the two numbers walk apart.
                Row {
                    id: refTimes
                    spacing: 0
                    Text {
                        id: refPos
                        text: panelRef.posText
                        font.pixelSize: 10; font.bold: true
                        font.family: "JetBrainsMono NF"
                    }
                    Text {
                        id: refSep
                        text: "/"
                        font.pixelSize: 10; font.bold: true
                        font.family: "JetBrainsMono NF"
                    }
                    Text {
                        id: refLen
                        text: panelRef.lenText
                        font.pixelSize: 10; font.bold: true
                        font.family: "JetBrainsMono NF"
                    }
                }
            }

            Row {
                id: refCtl
                spacing: 4
                anchors.verticalCenter: parent.verticalCenter

                Item { id: refPrev; width: card.chipSm; height: card.chipSm }
                Item { id: refPlay; width: card.playSm; height: card.playSm }
                Item { id: refNext; width: card.chipSm; height: card.chipSm }
            }
        }

        // ── Reference layout B: the card ────────────────────────────────
        // The real thing, the same item the lock screen shows. `ghostShared`
        // leaves the pieces the morph flies in laid out but undrawn, so they
        // are targets rather than duplicates; `extrasOpacity` holds back what
        // the pill has no counterpart for until the blob has finished opening.
        Widgets.MediaCard {
            id: panelRef
            anchors.centerIn: parent
            ghostShared: true
            extrasOpacity: card.contentAmt
        }

        // ── The shared items ────────────────────────────────────────────
        // One of each, drawn on top of both refs, walking from slot A to slot
        // B. These are the only transport controls the user can click.

        // Album art: 34 px pill chip to the card's cover, growing about its own
        // centre so it reads as the same square swelling.
        ClippingRectangle {
            id: flyArt
            readonly property real size: card.lerp(refArt.width, panelRef.artSize, card.morph)
            width: size
            height: size
            radius: card.lerp(Services.Sizes.innerR, 28, card.morph)
            color: Services.Colors.abyss
            x: card.lerp(pillRef.x + refArt.x + refArt.width / 2,
                         panelRef.x + panelRef.artCX, card.morph) - width / 2
            y: card.lerp(pillRef.y + refArt.y + refArt.height / 2,
                         panelRef.y + panelRef.artCY, card.morph) - height / 2

            Image {
                id: flyImg
                anchors.fill: parent
                source: panelRef.stableArtUrl
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                visible: status === Image.Ready
            }
            Text {
                anchors.centerIn: parent
                visible: flyImg.status !== Image.Ready
                text: ""
                color: Services.Colors.ash
                font.family: "Material Symbols Rounded"
                font.pixelSize: card.lerp(18, 40, card.morph)
            }
        }

        // Title. Scaled rather than re-sized: stepping font.pixelSize from 11
        // to 18 reflows the glyphs in integer jumps and reads as a stutter.
        // Laid out at the big size and shrunk, so the elide width has to be
        // divided back out to keep the visible width honest.
        Text {
            id: flyTitle
            readonly property real s: card.lerp(11 / 18, 1, card.morph)
            readonly property real visW: card.lerp(refCol.width, panelRef.titleW, card.morph)
            text: panelRef.titleText
            color: Services.Colors.snow
            font.pixelSize: 18
            font.bold: true
            font.family: "JetBrainsMono NF"
            elide: Text.ElideRight
            width: visW / s
            x: card.lerp(card.prColX + refTitle.x, panelRef.x + panelRef.titleX, card.morph)
            y: card.lerp(card.prColY + refTitle.y + refTitle.height / 2,
                         panelRef.y + panelRef.titleCY, card.morph) - height / 2
            transform: Scale {
                origin.x: 0
                origin.y: flyTitle.height / 2
                xScale: flyTitle.s
                yScale: flyTitle.s
            }
        }

        // Elapsed and total. Same size at both ends, so they only travel: in
        // the pill they are welded either side of a slash, in the card they
        // stand at opposite ends of the wave.
        Text {
            id: flyPos
            text: panelRef.posText
            color: Services.Colors.mist
            font.pixelSize: 10; font.bold: true
            font.family: "JetBrainsMono NF"
            x: card.lerp(card.prColX + refTimes.x + refPos.x,
                         panelRef.x + panelRef.posX, card.morph)
            y: card.lerp(card.prColY + refTimes.y + refPos.y + refPos.height / 2,
                         panelRef.y + panelRef.posCY, card.morph) - height / 2
        }
        // The slash has nowhere to go once the numbers separate, so it is the
        // one shared piece that does fade — quickly, before the gap opens.
        Text {
            id: flySep
            text: "/"
            color: Services.Colors.mist
            font.pixelSize: 10; font.bold: true
            font.family: "JetBrainsMono NF"
            opacity: 1 - Math.min(1, card.morph * 4)
            visible: opacity > 0.01
            x: card.lerp(card.prColX + refTimes.x + refSep.x, flyPos.x + flyPos.width, card.morph)
            y: flyPos.y
        }
        Text {
            id: flyLen
            text: panelRef.lenText
            color: Services.Colors.mist
            font.pixelSize: 10; font.bold: true
            font.family: "JetBrainsMono NF"
            x: card.lerp(card.prColX + refTimes.x + refLen.x,
                         panelRef.x + panelRef.lenX, card.morph)
            y: card.lerp(card.prColY + refTimes.y + refLen.y + refLen.height / 2,
                         panelRef.y + panelRef.lenCY, card.morph) - height / 2
        }

        // Transport chips: the same three plates the bar shows, grown and
        // respaced. Everything about their look lives in CtlChip, so hover
        // behaves identically at either size.
        Widgets.CtlChip {
            id: flyPrev
            glyph: ""
            size: card.lerp(card.chipSm, panelRef.chipLg, card.morph)
            glyphSize: card.lerp(18, 20, card.morph)
            available: root.hasPlayer && root.activePlayer.canGoPrevious
            onTriggered: root.activePlayer.previous()
            x: card.lerp(pillRef.x + refCtl.x + refPrev.x + refPrev.width / 2,
                         panelRef.x + panelRef.prevCX, card.morph) - width / 2
            y: card.lerp(pillRef.y + refCtl.y + refPrev.y + refPrev.height / 2,
                         panelRef.y + panelRef.prevCY, card.morph) - height / 2
        }
        Widgets.CtlChip {
            id: flyPlay
            glyph: panelRef.playGlyph
            size: card.lerp(card.playSm, panelRef.playLg, card.morph)
            glyphSize: card.lerp(20, 24, card.morph)
            available: root.hasPlayer
            active: root.hasPlayer && root.activePlayer.isPlaying
            onTriggered: root.activePlayer.togglePlaying()
            x: card.lerp(pillRef.x + refCtl.x + refPlay.x + refPlay.width / 2,
                         panelRef.x + panelRef.playCX, card.morph) - width / 2
            y: card.lerp(pillRef.y + refCtl.y + refPlay.y + refPlay.height / 2,
                         panelRef.y + panelRef.playCY, card.morph) - height / 2
        }
        Widgets.CtlChip {
            id: flyNext
            glyph: ""
            size: card.lerp(card.chipSm, panelRef.chipLg, card.morph)
            glyphSize: card.lerp(18, 20, card.morph)
            available: root.hasPlayer && root.activePlayer.canGoNext
            onTriggered: root.activePlayer.next()
            x: card.lerp(pillRef.x + refCtl.x + refNext.x + refNext.width / 2,
                         panelRef.x + panelRef.nextCX, card.morph) - width / 2
            y: card.lerp(pillRef.y + refCtl.y + refNext.y + refNext.height / 2,
                         panelRef.y + panelRef.nextCY, card.morph) - height / 2
        }
    }
}
