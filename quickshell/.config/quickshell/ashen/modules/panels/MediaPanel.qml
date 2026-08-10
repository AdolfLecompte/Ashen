import Quickshell
import Quickshell.Widgets
import QtQuick
import "root:/services" as Services
import "root:/modules/widgets" as Widgets

// The media pill's panel: the pill does not open a card beside itself, it
// BECOMES the card. The blob and its drivers live in Widgets.MorphCard.
// The card shows Widgets.MediaCard and takes its size from it.
PanelWindow {
    id: root
    anchors { top: true; left: true; right: true; bottom: true }
    screen: Services.Screens.active
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    // stays mapped through the close animation, so the exit plays in reverse
    readonly property bool shown: Services.AppState.mediaVisible
    visible: shown || card.closing

    // The pill stands aside while its panel is wearing its face.
    Binding {
        target: Services.AppState
        property: "mediaMorphing"
        // Not `morphing`: in "window" style the card never wears the pill's
        // face, and the pill must stay where it is.
        value: card.wearingFace
    }

    readonly property real openW: panelRef.contentW + panelRef.pad * 2
    readonly property real openH: panelRef.artSize + panelRef.pad * 2

    // `hasPlayer` is derived from the copy we hold, not fetched separately:
    // two bindings onto the same ref update in whatever order QML likes, so
    // for a frame `hasPlayer` was true while `activePlayer` was already null.
    readonly property var activePlayer: panelRef.activePlayer
    readonly property bool hasPlayer: root.activePlayer !== null

    // Chip sizes at each end of the trip
    readonly property real chipSm: Services.Sizes.innerH
    readonly property real playSm: Services.Sizes.innerH
    // Origin of the pill reference layout, in card coordinates
    readonly property real prColX: pillRef.x + refCol.x
    readonly property real prColY: pillRef.y + refCol.y

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

    Widgets.MorphCard {
        id: card
        anchors.fill: parent

        shown: root.shown
        pillW: Math.max(1, Services.AppState.mediaPillW)
        pillH: Math.max(1, Services.AppState.mediaPillH)
        pillCX: Services.AppState.mediaPillCenterX
        pillCY: Services.AppState.mediaPillCenterY
        openW: root.openW
        openH: root.openH

        // ── Reference layout A: the pill ────────────────────────────────
        // A structural copy of MediaPill's row, laid out but never drawn, so the
        // shared items know where the pill puts them. Centred, not left-anchored:
        // the box then grows around its contents instead of dragging them along.
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

                Item { id: refPrev; width: root.chipSm; height: root.chipSm }
                Item { id: refPlay; width: root.playSm; height: root.playSm }
                Item { id: refNext; width: root.chipSm; height: root.chipSm }
            }
        }

        // ── Reference layout B: the card ────────────────────────────────
        // `ghostShared` leaves the flown pieces laid out but undrawn, so they are
        // targets rather than duplicates; `extrasOpacity` holds back what the pill
        // has no counterpart for until the blob has finished opening.
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
            // Changing track sweeps the flown pieces, the same numbers the card
            // publishes -- they are the ones actually drawn.
            opacity: panelRef.swapFade
            transform: Translate { x: panelRef.swapOffX }

            Image {
                id: flyImg
                anchors.fill: parent
                source: panelRef.shownArtUrl
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                visible: status === Image.Ready
            }
            Text {
                anchors.centerIn: parent
                // Only when there is genuinely no cover, never while one decodes.
                visible: panelRef.shownArtUrl === ""
                text: "\ue405"
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
            text: panelRef.shownTitle
            color: Services.Colors.snow
            opacity: panelRef.swapFade
            font.pixelSize: 18
            font.bold: true
            font.family: "JetBrainsMono NF"
            elide: Text.ElideRight
            width: visW / s
            x: card.lerp(root.prColX + refTitle.x, panelRef.x + panelRef.titleX, card.morph)
            y: card.lerp(root.prColY + refTitle.y + refTitle.height / 2,
                         panelRef.y + panelRef.titleCY, card.morph) - height / 2
            transform: [
                Scale {
                    origin.x: 0
                    origin.y: flyTitle.height / 2
                    xScale: flyTitle.s
                    yScale: flyTitle.s
                },
                Translate { x: panelRef.swapOffX }
            ]
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
            x: card.lerp(root.prColX + refTimes.x + refPos.x,
                         panelRef.x + panelRef.posX, card.morph)
            y: card.lerp(root.prColY + refTimes.y + refPos.y + refPos.height / 2,
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
            x: card.lerp(root.prColX + refTimes.x + refSep.x, flyPos.x + flyPos.width, card.morph)
            y: flyPos.y
        }
        Text {
            id: flyLen
            text: panelRef.lenText
            color: Services.Colors.mist
            font.pixelSize: 10; font.bold: true
            font.family: "JetBrainsMono NF"
            x: card.lerp(root.prColX + refTimes.x + refLen.x,
                         panelRef.x + panelRef.lenX, card.morph)
            y: card.lerp(root.prColY + refTimes.y + refLen.y + refLen.height / 2,
                         panelRef.y + panelRef.lenCY, card.morph) - height / 2
        }

        // Transport chips: the same three plates the bar shows, grown and
        // respaced. Everything about their look lives in CtlChip, so hover
        // behaves identically at either size.
        Widgets.CtlChip {
            id: flyPrev
            glyph: "\ue045"
            size: card.lerp(root.chipSm, panelRef.chipLg, card.morph)
            glyphSize: card.lerp(18, 20, card.morph)
            available: root.activePlayer !== null && root.activePlayer.canGoPrevious
            onTriggered: if (root.activePlayer) { Services.AppState.mediaStep(-1); root.activePlayer.previous() }
            x: card.lerp(pillRef.x + refCtl.x + refPrev.x + refPrev.width / 2,
                         panelRef.x + panelRef.prevCX, card.morph) - width / 2
            y: card.lerp(pillRef.y + refCtl.y + refPrev.y + refPrev.height / 2,
                         panelRef.y + panelRef.prevCY, card.morph) - height / 2
        }
        Widgets.CtlChip {
            id: flyPlay
            glyph: panelRef.playGlyph
            size: card.lerp(root.playSm, panelRef.playLg, card.morph)
            glyphSize: card.lerp(20, 24, card.morph)
            available: root.hasPlayer
            active: root.activePlayer !== null && root.activePlayer.isPlaying
            onTriggered: if (root.activePlayer) root.activePlayer.togglePlaying()
            x: card.lerp(pillRef.x + refCtl.x + refPlay.x + refPlay.width / 2,
                         panelRef.x + panelRef.playCX, card.morph) - width / 2
            y: card.lerp(pillRef.y + refCtl.y + refPlay.y + refPlay.height / 2,
                         panelRef.y + panelRef.playCY, card.morph) - height / 2
        }
        Widgets.CtlChip {
            id: flyNext
            glyph: "\ue044"
            size: card.lerp(root.chipSm, panelRef.chipLg, card.morph)
            glyphSize: card.lerp(18, 20, card.morph)
            available: root.activePlayer !== null && root.activePlayer.canGoNext
            onTriggered: if (root.activePlayer) { Services.AppState.mediaStep(1); root.activePlayer.next() }
            x: card.lerp(pillRef.x + refCtl.x + refNext.x + refNext.width / 2,
                         panelRef.x + panelRef.nextCX, card.morph) - width / 2
            y: card.lerp(pillRef.y + refCtl.y + refNext.y + refNext.height / 2,
                         panelRef.y + panelRef.nextCY, card.morph) - height / 2
        }
    }
}
