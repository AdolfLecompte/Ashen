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

    // Where it lives when open: to the RIGHT of its capsule and level with it.
    readonly property real openX: root.pillCX + root.pillW / 2 + root.gap
    readonly property real openY: root.pillCY - root.cardH / 2

    // It no longer sweeps out of the capsule -- it unfolds from its own centre,
    // the way the power menu does, and the capsule stays where it is.
    Widgets.PanelArrive {
        id: arrive
        shown: root.shown
    }

    Rectangle {
        id: card
        // Its own fold, not PanelArrive's: in "plain" style that one collapses
        // to a fade, and this card is small enough that a fade reads as the card
        // simply being there. It grows from its middle in both styles -- that is
        // the whole point of the gesture.
        readonly property real fold: 0.55 + 0.45 * arrive.boxAmt
        width: root.cardW * card.fold
        height: root.cardH * card.fold
        x: root.openX + (root.cardW - width) / 2
        y: root.openY + (root.cardH - height) / 2
        radius: Services.Sizes.panelR
        // One plate, like the capsule beside it.
        color: Services.Colors.surfacePill
        opacity: arrive.fade
        visible: opacity > 0.01
        clip: true

        Item {
            anchors.centerIn: parent
            width: root.cardW
            height: root.cardH
            opacity: arrive.contentAmt

            Row {
                id: statRow
                anchors.centerIn: parent
                spacing: 16

                Repeater {
                    model: [
                        { glyph: "", text: Services.Weather.feels },
                        { glyph: "", text: Services.Weather.humidity + "%" },
                        { glyph: "", text: Services.Weather.windKph + " km/h" }
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
