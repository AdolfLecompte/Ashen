import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import "root:/modules/widgets" as Widgets
import "root:/services" as Services

PanelWindow {
    id: root

    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }
    screen: Services.Screens.active

    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    // stays mapped through the close animation, so the exit plays in reverse
    readonly property bool shown: Services.AppState.powerMenuVisible
    visible: shown || closeDelay.running
    onShownChanged: if (!shown) closeDelay.restart()
    Timer { id: closeDelay; interval: arrive.holdMs }

    // Escape gets you out of the most consequential thing in the shell. It was
    // the only panel that took no keys at all: the way out was to find a patch
    // of screen the buttons were not on and click it.
    WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    function close() { Services.AppState.powerMenuVisible = false }

    Widgets.EdgeEntry {
        id: arrive
        shown: root.shown
        edge: Services.Sizes.barPosition === "left" ? "left" : "right"
        // No card to grow into, so this one really does come from outside.
        travel: 130
    }

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.55)
        opacity: Services.AppState.powerMenuVisible ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 250 } }
        MouseArea {
            anchors.fill: parent
            onClicked: root.close()
        }
    }

    FocusScope {
        anchors.fill: parent
        focus: root.shown
        Keys.onEscapePressed: root.close()
    }

    Column {
        // Follows the power pill: end of the bar, whichever edge that is
        anchors.verticalCenter: parent.verticalCenter
        x: Services.Sizes.barPosition === "left"
           ? Math.max(16, Services.Sizes.marginLeft)
           : parent.width - width - Math.max(16, Services.Sizes.marginRight)
        spacing: 12
        id: powerCol
        // Comes in from the edge it hugs, then the buttons stack up one after
        // another — which is what a column of four wants to do anyway.
        opacity: arrive.fade
        visible: root.shown || opacity > 0
        transform: Translate { x: arrive.offX; y: arrive.offY }

        Repeater {
            model: [
                // `hold` is for the two you cannot take back. Nothing here is
                // painted red: error_ is for something that went wrong, and
                // shutting a machine down on purpose is not that. What sets
                // those two apart is that they make you keep pressing.
                { icon: "\ue899", cmd: "qs ipc -c ashen call lockscreen lock", hold: false },
                { icon: "\uf159", cmd: "systemctl suspend",                    hold: false },
                { icon: "\uf053", cmd: "systemctl reboot",                     hold: true  },
                { icon: "\uf8c7", cmd: "systemctl poweroff",                   hold: true  },
            ]
            delegate: Item {
                id: tile
                required property var modelData
                required property int index
                readonly property bool needsHold: modelData.hold === true

                width: 90; height: 90
                readonly property int radius_: Services.Sizes.cardR

                opacity: arrive.stage(index)
                // The bar's one hover language: it grows, and its glyph lifts.
                // The plate does not light up -- this was the last hover tint
                // left anywhere after the bar was cleaned out.
                scale: (0.9 + 0.1 * arrive.stage(index))
                       * Services.Sizes.hoverScale(hover.containsMouse, hover.pressed)
                Behavior on scale { NumberAnimation { duration: Services.Sizes.pillHoverMs; easing.type: Easing.OutCubic } }

                // ── Hold to mean it ────────────────────────────────────────
                // Fills from the bottom up while you keep pressing, and drains
                // if you let go. A short press on one of these does nothing
                // except show you a little of the fill, which is how you find
                // out that it wants holding without a word of text on screen.
                property real holdAmt: 0
                onHoldAmtChanged: plate.requestPaint()
                Connections {
                    target: Services.Colors
                    function onGhostChanged() { plate.requestPaint() }
                    function onSurfaceChanged() { plate.requestPaint() }
                }
                function fire() {
                    root.close()
                    Quickshell.execDetached(["sh", "-c", tile.modelData.cmd])
                }
                NumberAnimation {
                    id: holdFill
                    target: tile; property: "holdAmt"
                    to: 1; duration: 700
                    easing.type: Easing.Linear
                    onFinished: tile.fire()
                }
                NumberAnimation {
                    id: holdDrain
                    target: tile; property: "holdAmt"
                    to: 0; duration: 180
                    easing.type: Easing.OutCubic
                }

                // Plate and fill are one Canvas, not a Rectangle with a
                // Rectangle clipped inside it. `clip` clips to the bounding
                // BOX, never to the radius, so the rising fill came up square
                // and cut the corners off the tile it was filling. A path is
                // the only thing that knows where the corner is.
                Canvas {
                    id: plate
                    anchors.fill: parent
                    onPaint: {
                        const ctx = getContext("2d")
                        ctx.reset()
                        const w = width, h = height, r = tile.radius_

                        function shape() {
                            ctx.beginPath()
                            ctx.moveTo(r, 0)
                            ctx.arcTo(w, 0, w, h, r)
                            ctx.arcTo(w, h, 0, h, r)
                            ctx.arcTo(0, h, 0, 0, r)
                            ctx.arcTo(0, 0, w, 0, r)
                            ctx.closePath()
                        }

                        shape()
                        ctx.fillStyle = Services.Colors.surfacePanel
                        ctx.fill()

                        if (tile.holdAmt <= 0.001) return
                        ctx.save()
                        shape()
                        ctx.clip()
                        const top = h * (1 - tile.holdAmt)
                        if (Services.Prefs.useGradients) {
                            // Same accent gradient the rest of the shell wears:
                            // one tone lit from the left, read off Colors so a
                            // recolour carries here too.
                            const g = ctx.createLinearGradient(0, 0, w, 0)
                            g.addColorStop(0, Services.Colors.lift(Services.Colors.ghost, 0.14))
                            g.addColorStop(0.5, Services.Colors.ghost)
                            g.addColorStop(1, Services.Colors.lift(Services.Colors.ghost, -0.14))
                            ctx.fillStyle = g
                        } else {
                            ctx.fillStyle = Services.Colors.ghost
                        }
                        ctx.fillRect(0, top, w, h - top)
                        ctx.restore()
                    }
                }

                Text {
                    anchors.centerIn: parent
                    text: tile.modelData.icon
                    // Once the fill is past the middle the glyph is sitting on
                    // the accent, so it takes whichever of black and white can
                    // be read on it. Below that it is on the panel surface and
                    // behaves like every other glyph on hover.
                    color: tile.holdAmt > 0.5
                        ? Services.Colors.onColor(Services.Colors.ghost)
                        : (hover.containsMouse ? Services.Colors.snow : Services.Colors.ghost)
                    font.pixelSize: Services.Sizes.fsHero
                    font.family: "Material Symbols Rounded"
                    z: 1
                    Behavior on color { ColorAnimation { duration: Services.Sizes.msMicro } }
                }

                MouseArea {
                    id: hover
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onPressed: if (tile.needsHold) { holdDrain.stop(); holdFill.restart() }
                    // Released, cancelled, or the pointer slid off mid-hold are
                    // all "changed your mind", and only the first of the three
                    // fires `released`.
                    onReleased: if (tile.needsHold) { holdFill.stop(); holdDrain.restart() }
                    onCanceled: if (tile.needsHold) { holdFill.stop(); holdDrain.restart() }
                    onExited: if (tile.needsHold) { holdFill.stop(); holdDrain.restart() }
                    onClicked: if (!tile.needsHold) tile.fire()
                }
            }
        }
    }
}
