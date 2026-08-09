import QtQuick
import Qt5Compat.GraphicalEffects

// The part of a caption that is under the liquid: a re-inked copy of the very
// same item, shown only where the liquid is, so a letter the surface crosses is
// cut exactly at the wave. `source` and `mask` must cover the same rect as this
// item, or the mask arrives stretched.
Item {
    id: root

    // The lettering to re-ink. Stays visible and draws normally underneath.
    property Item source: null
    // The LiquidFill (or anything else) whose shape decides what is submerged.
    property Item mask: null
    // What can be read on the liquid.
    property color ink: "black"

    ColorOverlay {
        id: tinted
        anchors.fill: parent
        source: root.source
        color: root.ink
        // Only ever seen through the mask below.
        visible: false
        layer.enabled: true
    }

    OpacityMask {
        anchors.fill: parent
        source: tinted
        maskSource: root.mask
        visible: root.source !== null && root.mask !== null
    }
}
