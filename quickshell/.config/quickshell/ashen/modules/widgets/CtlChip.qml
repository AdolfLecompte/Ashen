import QtQuick
import "root:/services" as Services

// A transport button wearing the workspace strip's clothes: same square, same
// corner ratio, same two states. A dim plate is "here, but idle", a lit one is
// "this is the one". Used at three sizes -- bar pill, expanded card, and the
// copy that flies between them -- so every metric comes off `size`.
Rectangle {
    id: chip

    property string glyph: ""
    property real size: Services.Sizes.innerH
    property real glyphSize: 18
    property bool available: true
    property bool active: false
    // Laid out but not operated: the media morph parks an invisible copy in the
    // card's layout to reserve the slot, and that copy must not react to
    // anything — the real chip is flying above it.
    property bool inert: false
    signal triggered()

    // Lit means ON, not "the pointer is here". The two used to share the solid
    // accent fill, so a hovered pause button looked exactly like a playing one
    // and the state stopped carrying information. Hover is now its own step,
    // matching IconButton and the rest of the shell (see docs/DESIGN.md).
    readonly property bool lit: available && !inert && active
    readonly property bool warm: available && !inert && hover.containsMouse

    width: size
    height: size
    radius: size / 4
    // Hover does not touch the plate: the chip grows and its glyph lifts.
    color: !available ? Services.Colors.ghostAlpha(0.08)
         : lit ? Services.Colors.ghost
         : Services.Colors.fillRest
    gradient: Services.Prefs.useGradients && lit ? Services.Colors.accentGradient : null
    Behavior on color { ColorAnimation { duration: Services.Sizes.msStandard } }

    scale: available && !inert
        ? Services.Sizes.hoverScale(hover.containsMouse, hover.pressed) : 1.0
    Behavior on scale { NumberAnimation { duration: Services.Sizes.msMicro; easing.type: Services.Sizes.easeOut } }

    Text {
        anchors.centerIn: parent
        text: chip.glyph
        // On the accent fill, whichever of black and white can be read on it;
        // otherwise the ordinary rest/hover pair.
        color: chip.lit ? Services.Colors.accentText
             : (chip.warm ? Services.Colors.snow : Services.Colors.ash)
        font.family: "Material Symbols Rounded"
        font.pixelSize: chip.glyphSize
        Behavior on color { ColorAnimation { duration: Services.Sizes.msStandard } }
    }

    MouseArea {
        id: hover
        anchors.fill: parent
        hoverEnabled: !chip.inert
        cursorShape: Qt.PointingHandCursor
        enabled: chip.available && !chip.inert
        onClicked: chip.triggered()
    }
}
