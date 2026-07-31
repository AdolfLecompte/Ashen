import QtQuick

import "root:/services" as Services

// The small square button, everywhere. Close a panel, dismiss a notification,
// delete a row, step a value, toggle do-not-disturb: one component, one look.
//
// There used to be six of these -- IconBtn, CloseBtn, StepBtn, DeleteBtn and
// two inline copies -- at six sides (22, 24, 26, 28, 30, 32), five hover
// opacities and four glyph sizes. None of the differences meant anything.
//
// It is always a filled plate, never transparent-until-touched: a control you
// have to hunt for is a control that reads as decoration. See docs/DESIGN.md.
Rectangle {
    id: btn

    property string glyph: ""
    // 24, 28 or 32. Nothing else -- if a layout needs another number, the
    // layout is wrong, not the button.
    property int size: 28
    // On, held, selected. Takes the accent fill.
    property bool active: false
    // There but not usable: dimmed, and it does not react.
    property bool available: true

    // For a row that only reveals its button on hover: the row has to keep the
    // button shown while the pointer is on the button itself.
    readonly property alias hovered: hover.containsMouse

    signal activated()

    width: size
    height: size
    radius: Services.Sizes.innerR

    // The glyph rides with the plate rather than being set by hand.
    readonly property int glyphSize: size <= 24 ? 14 : (size <= 28 ? 16 : 18)

    // Hover does not touch the plate: the button grows and its glyph lifts.
    color: !available ? Services.Colors.ghostAlpha(0.08)
         : active ? Services.Colors.ghost
         : Services.Colors.fillRest
    gradient: Services.Prefs.useGradients && active && available
        ? Services.Colors.accentGradient : null
    Behavior on color { ColorAnimation { duration: Services.Sizes.pillHoverMs } }

    // The bar's one hover language. Never a local scale number.
    scale: available ? Services.Sizes.hoverScale(hover.containsMouse, hover.pressed) : 1.0
    Behavior on scale { NumberAnimation { duration: Services.Sizes.pillHoverMs; easing.type: Easing.OutCubic } }

    Text {
        anchors.centerIn: parent
        text: btn.glyph
        // Lit, the glyph is whichever of black and white can be read on the
        // accent -- matugen hands the shell whatever the wallpaper had in it,
        // so "the accent is light" is not something we get to assume.
        color: !btn.available ? Services.Colors.ash
             : btn.active ? Services.Colors.onColor(Services.Colors.ghost)
             : (hover.containsMouse ? Services.Colors.snow : Services.Colors.ash)
        opacity: btn.available ? 1.0 : 0.4
        font.pixelSize: btn.glyphSize
        font.family: "Material Symbols Rounded"
        Behavior on color { ColorAnimation { duration: Services.Sizes.pillHoverMs } }
    }

    MouseArea {
        id: hover
        anchors.fill: parent
        hoverEnabled: true
        enabled: btn.available
        cursorShape: Qt.PointingHandCursor
        onClicked: btn.activated()
    }
}
