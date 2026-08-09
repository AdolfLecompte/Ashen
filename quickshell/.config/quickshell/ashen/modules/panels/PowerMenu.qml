import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import "root:/modules/widgets" as Widgets
import "root:/services" as Services

// The four ways out, as a panel like any other: a card of named tiles instead
// of a strip of bare icons stuck to the screen edge. Restart and shut down
// have to be held; the fill rising through the tile is what says so.
PanelWindow {
    id: root

    anchors { top: true; left: true; right: true; bottom: true }
    screen: Services.Screens.active
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    // stays mapped through the close animation, so the exit plays in reverse
    readonly property bool shown: Services.AppState.powerMenuVisible
    visible: shown || closeDelay.running
    onShownChanged: if (!shown) closeDelay.restart()
    Timer { id: closeDelay; interval: host.holdMs }

    WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    function close() { Services.AppState.powerMenuVisible = false }

    // Every one of these has to be held down, not clicked. Nothing here is
    // red: error_ is for something that went wrong, and shutting a machine
    // down on purpose is not that -- what sets these apart is that they make
    // you keep pressing.
    readonly property var actions: [
        { icon: "", label: "Lock",      cmd: "",                   lock: true },
        { icon: "", label: "Suspend",   cmd: "systemctl suspend"  },
        { icon: "", label: "Restart",   cmd: "systemctl reboot"   },
        { icon: "", label: "Shut down", cmd: "systemctl poweroff" },
    ]

    Rectangle {
        anchors.fill: parent
        color: Services.Colors.scrim
        opacity: root.shown ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: Services.Sizes.msPronounced } }
        MouseArea { anchors.fill: parent; onClicked: root.close() }
    }

    FocusScope {
        anchors.fill: parent
        focus: root.shown
        Keys.onEscapePressed: root.close()
    }

    Widgets.PanelHost {
        id: host
        shown: root.shown
        pillKey: "power"
        restSide: "center"
        pillCX: Services.AppState.powerPillCenterX
        pillCY: Services.AppState.powerPillCenterY
        pillW: Services.AppState.powerPillW
        pillH: Services.AppState.powerPillH
        pillActive: root.shown
        pillColor: Services.Colors.surfacePill
        pillGlyph: Services.AppState.pillGlyph("power")

        // Square tiles standing on their own: no card around them, because the
        // four ways out are four things, not one panel with things in it.
        readonly property int tileW: 190
        readonly property int tileH: 190
        readonly property int gap: 16
        // The card is invisible but still CLIPS: with no padding the hover
        // growth got sliced off at the edge tiles. This is room to breathe in,
        // not a margin you can see.
        readonly property int pad: 16
        openW: 4 * tileW + 3 * gap + pad * 2
        openH: tileH + pad * 2
        cardColor: "transparent"
        // Centred whichever way it arrives: it is the most consequential thing
        // in the shell and should not be read out of the corner of your eye.
        openXOverride: (root.width - host.openW) / 2
        openYOverride: (root.height - host.openH) / 2
        cardRadius: Services.Sizes.panelR

        body: Component {
            Item {
                id: card

                // The four tiles land one after another out of the card's
                // single content driver.
                function stage(i) {
                    const start = Math.min(0.5, i * 0.12)
                    return Math.max(0, Math.min(1, (host.contentAmt - start) / (1 - start)))
                }

                // What the pointer is on. The tiles carry no words of their own:
                // an icon the size of a fist is the thing you press, and the
                // name belongs where it cannot make four tiles into a paragraph.
                property string hovered: ""

                Row {
                    id: tileRow
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    anchors.topMargin: host.pad
                    spacing: host.gap

                    Repeater {
                        model: root.actions

                        delegate: Item {
                            id: tile
                            required property var modelData
                            required property int index

                            width: host.tileW
                            height: host.tileH

                            opacity: card.stage(index)
                            // The shell's one hover language: it grows and its
                            // contents lift. The plate never lights up.
                            scale: (0.92 + 0.08 * card.stage(index))
                                   * Services.Sizes.hoverScale(hover.containsMouse, hover.pressed)
                            Behavior on scale {
                                NumberAnimation {
                                    duration: Services.Sizes.pillHoverMs
                                    easing.type: Services.Sizes.easeOut
                                }
                            }

                            // Held down the fill rises through the tile, and
                            // drains if you let go. A short press shows a
                            // little of it, which is how you find out it wants
                            // holding without a word on screen.
                            property real holdAmt: 0
                            onHoldAmtChanged: plate.requestPaint()
                            Connections {
                                target: Services.Colors
                                function onGhostChanged() { plate.requestPaint() }
                                function onSurfaceChanged() { plate.requestPaint() }
                            }
                            function fire() {
                                root.close()
                                // Locking happens in this process: spawning a
                                // shell to call our own IPC was the shell
                                // asking itself to do what it can already do.
                                if (tile.modelData.lock === true) {
                                    Services.AppState.lockRequested()
                                    return
                                }
                                Quickshell.execDetached(["sh", "-c", tile.modelData.cmd])
                            }
                            NumberAnimation {
                                id: holdFill
                                target: tile; property: "holdAmt"
                                to: 1; duration: 700
                                easing.type: Services.Sizes.easeTrace
                                onFinished: tile.fire()
                            }
                            NumberAnimation {
                                id: holdDrain
                                target: tile; property: "holdAmt"
                                to: 0; duration: Services.Sizes.msStandard
                                easing.type: Services.Sizes.easeOut
                            }

                            // Plate and fill are one Canvas: `clip` clips to
                            // the bounding box and never to the radius, so a
                            // clipped fill rose square and ate the corners.
                            Canvas {
                                id: plate
                                anchors.fill: parent
                                onPaint: {
                                    const ctx = getContext("2d")
                                    ctx.reset()
                                    const w = width, h = height, r = Services.Sizes.cardR

                                    function shape() {
                                        ctx.beginPath()
                                        ctx.moveTo(r, 0)
                                        ctx.arcTo(w, 0, w, h, r)
                                        ctx.arcTo(w, h, 0, h, r)
                                        ctx.arcTo(0, h, 0, 0, r)
                                        ctx.arcTo(0, 0, w, 0, r)
                                        ctx.closePath()
                                    }

                                    // The tiles stand alone now, so each one is
                                    // its own capsule: the flat dark surface,
                                    // not a translucent one. Every plate tone in
                                    // Colors carries alpha, and four of them
                                    // floating over a wallpaper with no panel
                                    // behind read as smudges rather than tiles.
                                    shape()
                                    ctx.fillStyle = Services.Colors.surface
                                    ctx.fill()

                                    if (tile.holdAmt <= 0.001) return
                                    ctx.save()
                                    shape()
                                    ctx.clip()
                                    const top = h * (1 - tile.holdAmt)
                                    if (Services.Prefs.useGradients) {
                                        const g = ctx.createLinearGradient(0, 0, w, 0)
                                        g.addColorStop(0, Services.Colors.lift(Services.Colors.ghost, Services.Colors.gradientUp))
                                        g.addColorStop(0.5, Services.Colors.ghost)
                                        g.addColorStop(1, Services.Colors.lift(Services.Colors.ghost, -Services.Colors.gradientDown))
                                        ctx.fillStyle = g
                                    } else {
                                        ctx.fillStyle = Services.Colors.ghost
                                    }
                                    ctx.fillRect(0, top, w, h - top)
                                    ctx.restore()
                                }
                            }

                            // Past halfway the contents sit on the accent and
                            // take whichever of black and white reads on it.
                            readonly property bool onAccent: tile.holdAmt > 0.5

                            // The icon lifts a little to make room the moment the
                            // name arrives, so nothing on the tile ever moves
                            // except at the one instant you are looking at it.
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.verticalCenterOffset: hover.containsMouse ? -14 : 0
                                Behavior on anchors.verticalCenterOffset {
                                    NumberAnimation { duration: Services.Sizes.msStandard; easing.type: Services.Sizes.easeOut }
                                }
                                z: 1
                                text: tile.modelData.icon
                                color: tile.onAccent
                                    ? Services.Colors.accentText
                                    : (hover.containsMouse ? Services.Colors.snow : Services.Colors.ghost)
                                font.pixelSize: 68
                                font.family: "Material Symbols Rounded"
                                Behavior on color { ColorAnimation { duration: Services.Sizes.msMicro } }
                            }

                            // Its own name, on its own tile: which one you are
                            // about to press is a question about THIS tile, and
                            // the answer belongs where you are looking.
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: 22
                                z: 1
                                text: tile.modelData.label
                                color: tile.onAccent ? Services.Colors.accentText : Services.Colors.snow
                                font.pixelSize: Services.Sizes.fsCardTitle
                                font.bold: true
                                font.family: "JetBrainsMono NF"
                                opacity: hover.containsMouse ? 1 : 0
                                Behavior on opacity { NumberAnimation { duration: Services.Sizes.msMicro } }
                                Behavior on color { ColorAnimation { duration: Services.Sizes.msMicro } }
                            }

                            MouseArea {
                                id: hover
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                hoverEnabled: true
                                onPressed: { holdDrain.stop(); holdFill.restart() }
                                // Released, cancelled, or the pointer sliding
                                // off are all "changed your mind", and only the
                                // first of the three fires `released`.
                                onReleased: { holdFill.stop(); holdDrain.restart() }
                                onCanceled: { holdFill.stop(); holdDrain.restart() }
                                onExited: { holdFill.stop(); holdDrain.restart() }
                            }
                        }
                    }
                }
            }
        }
    }
}
