import QtQuick

import "root:/services" as Services
import "root:/modules/widgets" as Widgets

// The weather's card on the lock screen: today's readings -- temperature,
// humidity, wind -- and nothing the capsule already says. No forecast: the days
// need a card twice the height of the capsule they come out of, and a card
// taller than its own capsule stops looking like it grew from it.
// An Item and not a window, because the lock is one surface.
Item {
    id: root

    property bool shown: false
    property real pillCX: 0
    property real pillCY: 0
    property real pillW: 1
    property real pillH: 1

    // True while the card is on screen wearing the capsule's face -- which in
    // "window" style it never is, so the capsule stays put.
    readonly property alias wearingFace: card.wearingFace

    signal dismissed()

    // Level with the capsule and exactly as tall: it opens sideways out of it.
    readonly property int cardW: statRow.width + 28
    readonly property int cardH: root.pillH
    readonly property int gap: 12

    MouseArea {
        anchors.fill: parent
        enabled: root.shown
        onClicked: root.dismissed()
    }

    Widgets.MorphCard {
        id: card
        anchors.fill: parent
        shown: root.shown
        neck: false
        sideways: true
        pillCX: root.pillCX
        pillCY: root.pillCY
        pillW: root.pillW
        pillH: root.pillH
        openW: root.cardW
        openH: root.cardH
        // One plate, like the capsule it comes out of.
        plateColor: Services.Colors.surfacePill
        // Out to the RIGHT of its capsule and level with it.
        openXOverride: root.pillCX + root.pillW / 2 + root.gap
        openYOverride: root.pillCY - root.cardH / 2

        Item {
            anchors.centerIn: parent
            width: root.cardW
            height: root.cardH
            opacity: card.contentAmt

            Row {
                id: statRow
                anchors.centerIn: parent
                spacing: 16

                Repeater {
                    model: [
                        { glyph: "", text: Services.Weather.feels },
                        { glyph: "", text: Services.Weather.humidity + "%" },
                        { glyph: "", text: Services.Weather.windKph + " "
                                 + Services.Weather.windCompass(Services.Weather.windDir) }
                    ]
                    delegate: Row {
                        required property var modelData
                        spacing: 6
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: parent.modelData.glyph
                            color: Services.Colors.mist
                            font.pixelSize: 16
                            font.family: "Material Symbols Rounded"
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: parent.modelData.text
                            color: Services.Colors.snow
                            font.pixelSize: Services.Sizes.fsInput
                            font.bold: true
                            font.family: "JetBrainsMono NF"
                        }
                    }
                }
            }
        }
    }
}
