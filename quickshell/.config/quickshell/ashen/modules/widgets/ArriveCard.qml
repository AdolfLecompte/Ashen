import QtQuick

import "root:/services" as Services

// The card for a panel with no pill to grow out of: it appears where it lives
// and unfolds from its centre. Same container contract as DropCard, so a panel
// can be handed either one. Timing lives in PanelArrive.
Item {
    id: root
    anchors.fill: parent

    property bool shown: false
    property real openW: 400
    property real openH: 300
    property real cardRadius: Services.Sizes.panelR
    // Pixels below its resting place to come up from.
    property int rise: 0
    // Which part of the screen it unfolds on when nobody names a position:
    // "center", "left", "right", "top" or "bottom". A panel with no pill has
    // no chip to line up with, so it takes a side of its own.
    property string restSide: "center"
    property real openXOverride: NaN
    property real openYOverride: NaN
    // Ignored here; a panel wired for both arrivals sets them either way.
    property string pillGlyph: ""
    property string pillLabel: ""
    property Item glyphTarget: null
    property Item labelTarget: null
    property bool pillActive: false

    readonly property real openX: !isNaN(openXOverride) ? openXOverride
        : root.restSide === "left" ? Services.Sizes.marginLeft
        : root.restSide === "right" ? width - root.openW - Services.Sizes.marginRight
        : (width - root.openW) / 2
    readonly property real openY: !isNaN(openYOverride) ? openYOverride
        : root.restSide === "top" ? Services.Sizes.marginTop
        : root.restSide === "bottom" ? height - root.openH - Services.Sizes.marginBottom
        : (height - root.openH) / 2

    // Nothing flies, so the panel never hides its own pieces.
    readonly property bool morphing: false
    readonly property bool morphingGlyph: false
    readonly property bool morphingLabel: false

    readonly property alias contentAmt: arrive.contentAmt
    // Nothing travels here, so shared pieces are at their panel place already.
    readonly property real morph: 1
    readonly property alias arrive: arrive
    readonly property int closeMs: arrive.closeMs
    readonly property int holdMs: arrive.holdMs

    default property alias content: body.data

    PanelArrive {
        id: arrive
        shown: root.shown
        rise: root.rise
    }

    Rectangle {
        id: card
        x: arrive.boxX(root.openX, root.openW)
        y: arrive.boxY(root.openY, root.openH)
        width: arrive.boxW(root.openW)
        height: arrive.boxH(root.openH)
        radius: root.cardRadius
        color: Services.Colors.surfacePanel
        clip: true
        opacity: arrive.fade
        transform: Translate { y: arrive.offY }

        // Clicks inside must not reach the dismiss layer behind the panel.
        MouseArea { anchors.fill: parent; onClicked: {} }

        // Laid out at the open size from the first frame, so nothing reflows
        // while the box unfolds.
        Item {
            id: body
            width: root.openW
            height: root.openH
            anchors.centerIn: parent
            opacity: arrive.contentAmt
            visible: opacity > 0.01
        }
    }
}
