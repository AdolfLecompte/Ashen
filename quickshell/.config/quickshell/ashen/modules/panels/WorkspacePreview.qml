import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import QtQuick
import "root:/services" as Services
import "root:/modules/widgets" as Widgets

// Dwell on a workspace chip and it grows into a live view of that
// workspace. The pictures are real: toplevel-export hands over a window's
// contents even when its workspace is not on screen, and windows sit at
// their true positions, scaled by the monitor.
PanelWindow {
    id: root
    anchors { top: true; left: true; right: true; bottom: true }
    screen: Services.Screens.active
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    // Takes no input, ever. The preview opens directly under the pointer's own
    // chip; if this window swallowed the pointer the chip would lose hover and
    // the preview would close itself the instant it appeared.
    mask: Region { width: 0; height: 0 }

    readonly property bool shown: Services.AppState.wsPreviewId !== 0
    visible: shown || closeDelay.running

    // Latched: the id clears the moment the pointer leaves, but the content
    // has to stay on screen until the shrink finishes.
    property int heldId: 0
    property string heldLabel: ""

    // Opening is a function, not just a signal handler: LazyPanel may build
    // this panel with `shown` ALREADY true (the preload timer and the first
    // hover can land in either order), and a property that is born at its new
    // value never emits a change. Without this the preview simply never armed.
    function beginOpen() {
        heldId = Services.AppState.wsPreviewId
        heldLabel = Services.AppState.wsPreviewLabel
        arm.restart()
    }
    Component.onCompleted: if (shown) beginOpen()

    onShownChanged: {
        if (shown) {
            beginOpen()
        } else {
            arm.stop()
            Services.AppState.wsPreviewMorphing = false
            openAnim.stop()
            closeAnim.start()
            closeDelay.restart()
        }
    }
    // A layer surface is not presented on the frame it is asked for; hold the
    // chip until the surface has landed. It doubles as the grace period the
    // captures need to produce a first frame.
    Timer {
        id: arm
        interval: 200
        onTriggered: {
            Services.AppState.wsPreviewMorphing = true
            closeAnim.stop()
            openAnim.start()
        }
    }
    Timer { id: closeDelay; interval: 420 }

    readonly property bool opening: Services.AppState.wsPreviewMorphing

    // ── The monitor being miniaturised ──────────────────────────────────
    readonly property var mon: Hyprland.focusedMonitor ? Hyprland.focusedMonitor.lastIpcObject : null
    readonly property real monW: (mon && mon.width) ? mon.width : 1920
    readonly property real monH: (mon && mon.height) ? mon.height : 1080
    readonly property real monX: (mon && mon.x) ? mon.x : 0
    readonly property real monY: (mon && mon.y) ? mon.y : 0

    readonly property real viewW: 340
    readonly property real viewH: Math.round(viewW * monH / monW)
    readonly property real pad: 16
    readonly property real labelH: 24
    readonly property real openW: viewW + pad * 2
    readonly property real openH: viewH + labelH + 10 + pad * 2

    readonly property real pillW: Math.max(1, Services.AppState.wsPreviewW)
    readonly property real pillH: Math.max(1, Services.AppState.wsPreviewH)
    readonly property real pillCX: Services.AppState.wsPreviewX + pillW / 2
    readonly property real pillCY: Services.AppState.wsPreviewY + pillH / 2

    // Every window living on the previewed workspace
    readonly property var wins: {
        if (heldId === 0) return []
        return Hyprland.toplevels.values.filter(t => t.workspace && t.workspace.id === root.heldId)
    }

    // The chip shows either a workspace number or an app glyph; the flying copy
    // has to be set in whichever font that was.
    readonly property bool labelIsGlyph: heldLabel.length > 0 && heldLabel.charCodeAt(0) >= 0xe000

    // ── The goo bridge, same as the other panels ────────────────────────
    Widgets.GooNeck {
        active: !Services.Sizes.barVertical
        pillCX: root.pillCX
        pillW: root.pillW
        fromBelow: Services.Sizes.barPosition === "bottom"
        barEdge: Services.Sizes.barPosition === "bottom"
            ? parent.height - Services.Sizes.barH : Services.Sizes.barH
        cardEdge: Services.Sizes.barPosition === "bottom"
            ? card.y + card.height : card.y
        cardHalfW: card.width / 2
        pinch: Math.max(0, Math.min(1, card.fall / 0.55))
        fillColor: Services.Colors.surfacePanel
    }

    Rectangle {
        id: card

        readonly property real openX: Services.Sizes.panelX(parent.width, root.openW, root.pillCX)
        readonly property real openY: Services.Sizes.panelY(parent.height, root.openH, root.pillCY)

        visible: root.opening || closeDelay.running

        function lerp(a, b, t) { return a + (b - a) * t }

        property real fall: 0
        property real stretch: 0
        property real spread: 0
        property real morph: 0
        property real contentAmt: 0

        // Quicker than the big panels: this is a glance, not a place you stay.
        ParallelAnimation {
            id: openAnim
            NumberAnimation {
                target: card; property: "fall"; to: 1
                duration: 380; easing.type: Services.Sizes.easeOut
            }
            NumberAnimation {
                target: card; property: "stretch"; to: 1
                duration: 300; easing.type: Services.Sizes.easeOut
            }
            NumberAnimation {
                target: card; property: "spread"; to: 1
                duration: 450; easing.type: Easing.OutBack; easing.overshoot: Services.Sizes.overshoot
            }
            // Box first, contents after — same order as everywhere else
            SequentialAnimation {
                PauseAnimation { duration: 160 }
                NumberAnimation {
                    target: card; property: "morph"; to: 1
                    duration: 280; easing.type: Services.Sizes.easeOut
                }
            }
            SequentialAnimation {
                PauseAnimation { duration: 260 }
                NumberAnimation { target: card; property: "contentAmt"; to: 1; duration: 180 }
            }
        }

        ParallelAnimation {
            id: closeAnim
            NumberAnimation { target: card; property: "contentAmt"; to: 0; duration: 80 }
            SequentialAnimation {
                PauseAnimation { duration: 30 }
                NumberAnimation {
                    target: card; property: "morph"; to: 0
                    duration: 220; easing.type: Services.Sizes.easeInOut
                }
            }
            SequentialAnimation {
                PauseAnimation { duration: 120 }
                ParallelAnimation {
                    NumberAnimation {
                        target: card; property: "fall"; to: 0
                        duration: 280; easing.type: Services.Sizes.easeInOut
                    }
                    NumberAnimation {
                        target: card; property: "stretch"; to: 0
                        duration: 250; easing.type: Services.Sizes.easeInOut
                    }
                    NumberAnimation {
                        target: card; property: "spread"; to: 0
                        duration: 250; easing.type: Services.Sizes.easeInOut
                    }
                }
            }
        }

        width: root.pillW + (root.openW - root.pillW) * spread
        height: root.pillH + (root.openH - root.pillH) * stretch
        x: root.pillCX + (openX + root.openW / 2 - root.pillCX) * fall - width / 2
        y: root.pillCY + (openY + root.openH / 2 - root.pillCY) * fall - height / 2

        radius: Services.Sizes.innerR + (16 - Services.Sizes.innerR) * Math.min(1, spread)
        color: Services.Colors.surfacePanel
        clip: true

        // ── The miniature ───────────────────────────────────────────────
        Rectangle {
            id: view
            x: root.pad
            y: root.pad
            width: root.viewW
            height: root.viewH
            radius: 10
            color: Services.Colors.abyss
            clip: true
            opacity: card.contentAmt

            Repeater {
                model: root.wins

                delegate: Item {
                    required property var modelData
                    readonly property var io: modelData.lastIpcObject
                    readonly property real sx: view.width / root.monW
                    readonly property real sy: view.height / root.monH
                    readonly property bool placed: io && io.at && io.size

                    visible: placed
                    x: placed ? (io.at[0] - root.monX) * sx : 0
                    y: placed ? (io.at[1] - root.monY) * sy : 0
                    width: placed ? io.size[0] * sx : 0
                    height: placed ? io.size[1] * sy : 0

                    ScreencopyView {
                        id: shot
                        anchors.fill: parent
                        captureSource: modelData.wayland
                        // Only while the preview is up: a live capture per
                        // window is real GPU work and there is no reason to
                        // pay for it against a closed panel.
                        live: root.shown
                        visible: hasContent
                    }

                    // Until the first frame lands — and for anything that
                    // never hands one over — the shape and the app are still
                    // most of what a preview is for.
                    Rectangle {
                        anchors.fill: parent
                        visible: !shot.hasContent
                        radius: 4
                        color: Services.Colors.surfacePanel
                        border.color: Services.Colors.ghostAlpha(0.25)
                        border.width: 1
                        Text {
                            anchors.centerIn: parent
                            text: Services.Windows.iconForClass(parent.parent.io ? parent.parent.io["class"] : "")
                            color: Services.Colors.ghost
                            font.family: "Material Symbols Rounded"
                            font.pixelSize: Math.max(10, Math.min(22, parent.height * 0.45))
                        }
                    }
                }
            }

            // An empty workspace never opens a preview, but a workspace can go
            // empty while one is open.
            Text {
                anchors.centerIn: parent
                visible: root.wins.length === 0
                text: "empty"
                color: Services.Colors.ash
                font.pixelSize: 11
                font.family: "JetBrainsMono NF"
            }
        }

        // ── Caption ─────────────────────────────────────────────────────
        // The chip's own label lands here, so the thing you were pointing at
        // is still the thing you are looking at.
        Item {
            id: labelRow
            x: root.pad
            y: root.pad + root.viewH + 10
            width: root.viewW
            height: root.labelH

            // Ghost slot: gives the flying label somewhere to land
            Text {
                id: labelSlot
                opacity: 0
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: root.heldLabel
                font.pixelSize: 13
                font.bold: true
                font.family: root.labelIsGlyph ? "Material Symbols Rounded" : "JetBrainsMono NF"
            }

            Text {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                opacity: card.contentAmt
                text: root.wins.length + (root.wins.length === 1 ? " window" : " windows")
                color: Services.Colors.ash
                font.pixelSize: 10
                font.family: "JetBrainsMono NF"
            }
        }

        // The travelling label: chip centre when closed, caption slot when open
        Text {
            id: flyLabel
            text: root.heldLabel
            color: Services.Colors.snow
            font.pixelSize: 13
            font.bold: true
            font.family: root.labelIsGlyph ? "Material Symbols Rounded" : "JetBrainsMono NF"
            x: card.lerp(card.width / 2, labelSlot.x + labelSlot.width / 2, card.morph) - width / 2
            y: card.lerp(card.height / 2,
                         labelRow.y + labelSlot.y + labelSlot.height / 2, card.morph) - height / 2
        }
    }
}
