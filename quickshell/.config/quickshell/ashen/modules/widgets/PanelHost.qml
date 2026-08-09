import QtQuick

import "root:/services" as Services

// Picks how a panel arrives: out of its pill when that pill is on screen
// (DropCard), unfolding where it lives when it is not (ArriveCard). The panel
// writes its contents once as `body`, which may publish glyphTarget /
// labelTarget for the pieces that fly out of the chip.
Item {
    id: host
    anchors.fill: parent

    property bool shown: false
    // Which pill this panel belongs to, as named in Pills.qml. Empty means the
    // panel never had one and always unfolds.
    property string pillKey: ""
    // A tool is fixed to the utility pill, so it always has a chip to grow
    // from; only bar pills can be taken away.
    // Does this panel have a capsule on screen at all?
    readonly property bool hasPill: pillKey !== ""
        && (Services.Pills.isTool(pillKey) || Services.Prefs.pillVisible(pillKey))
    // …and should it transform out of it, or just appear where it would have?
    readonly property bool fromPill: hasPill && Services.Pills.wearsFace
    // Is the capsule's face on this card right now? What a chip asks before it
    // steps aside.
    readonly property bool wearingFace: host.fromPill && host.shown

    // The pill's rect, for the drop.
    property real pillCX: 0
    property real pillCY: 0
    property real pillW: 44
    property real pillH: 32
    property bool pillActive: false
    property color pillColor: pillActive ? Services.Colors.ghost
                                         : Services.Colors.fillRest
    property string pillGlyph: ""
    property string pillLabel: ""

    property real openW: 400
    property real openH: 300
    property real cardRadius: Services.Sizes.panelR
    // Only honoured when it unfolds; a panel that drops out of a chip carries
    // that chip's colour across instead.
    property color cardColor: Services.Colors.surfacePanel
    property real openXOverride: NaN
    property real openYOverride: NaN
    property string sourceEdge: ""
    // Only used when it unfolds: where on screen, and how far it comes up.
    property string restSide: "center"
    property int rise: 0

    property Component body: null

    readonly property Item cardItem: dropLoader.active ? dropLoader.item : arriveLoader.item
    readonly property int closeMs: cardItem ? cardItem.closeMs : Services.Sizes.panelCloseMs
    readonly property int holdMs: closeMs + 60
    readonly property real contentAmt: cardItem ? cardItem.contentAmt : 0
    readonly property real morph: cardItem ? cardItem.morph : 0
    readonly property bool morphingGlyph: cardItem ? cardItem.morphingGlyph : false
    readonly property bool morphingLabel: cardItem ? cardItem.morphingLabel : false
    // What the body loaded inside, for a panel that needs to reach into it.
    readonly property Item bodyItem: cardItem && cardItem.bodyItem ? cardItem.bodyItem : null
    // Staggered arrival for the body's pieces. A card that drops out of a chip
    // brings its own choreography, so there it is just the content fade.
    function stage(i) {
        if (cardItem && cardItem.stage) return cardItem.stage(i)
        return host.contentAmt
    }

    Loader {
        id: dropLoader
        anchors.fill: parent
        active: host.fromPill
        sourceComponent: DropCard {
            shown: host.shown
            pillCX: host.pillCX
            pillCY: host.pillCY
            pillW: host.pillW
            pillH: host.pillH
            pillActive: host.pillActive
            pillColor: host.pillColor
            pillGlyph: host.pillGlyph
            pillLabel: host.pillLabel
            glyphTarget: (bodyHolder.item && bodyHolder.item.glyphTarget) || null
            labelTarget: (bodyHolder.item && bodyHolder.item.labelTarget) || null
            openW: host.openW
            openH: host.openH
            cardRadius: host.cardRadius
            openXOverride: host.openXOverride
            openYOverride: host.openYOverride
            sourceEdge: host.sourceEdge
            readonly property alias bodyItem: bodyHolder.item
            Loader { id: bodyHolder; anchors.fill: parent; sourceComponent: host.body }
        }
    }

    Loader {
        id: arriveLoader
        anchors.fill: parent
        active: !host.fromPill
        sourceComponent: ArriveCard {
            cardColor: host.cardColor
            fromPill: host.hasPill
            pillCX: host.pillCX
            pillCY: host.pillCY
            shown: host.shown
            openW: host.openW
            openH: host.openH
            cardRadius: host.cardRadius
            openXOverride: host.openXOverride
            openYOverride: host.openYOverride
            restSide: host.restSide
            rise: host.rise
            readonly property alias bodyItem: bodyHolder2.item
            Loader { id: bodyHolder2; anchors.fill: parent; sourceComponent: host.body }
        }
    }
}
