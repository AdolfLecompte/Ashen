import QtQuick

import "root:/services" as Services
import "root:/modules/widgets" as Widgets

// The battery's card on the lock screen: the power profiles, and nothing the
// capsule already says. It sits beside its capsule, so it covers nothing above
// it. An Item and not a window -- the lock is one surface.
Item {
    id: root

    property bool shown: false
    // The capsule it grows out of.
    property real pillCX: 0
    property real pillCY: 0
    property real pillW: 1
    property real pillH: 1

    property int battery: 0
    property bool charging: false
    property var profiles: []
    property string activeProfile: ""

    signal dismissed()
    signal profilePicked(string id)

    // Three choices at 32 px, 4 apart, 10 of air each side -- and exactly as
    // tall as the capsule it grows out of. A card taller than its own capsule
    // stops reading as that capsule, grown.
    readonly property int cardW: 3 * 32 + 2 * 4 + 20
    readonly property int cardH: root.pillH
    // How far off the capsule it sits.
    readonly property int gap: 12

    // Anywhere off the card puts it away again.
    MouseArea {
        anchors.fill: parent
        enabled: root.shown
        onClicked: root.dismissed()
    }

    // Where it lives when open: to the LEFT of its capsule and level with it --
    // upwards is where the clock and the music live.
    readonly property real openX: root.pillCX - root.pillW / 2 - root.gap - root.cardW
    readonly property real openY: root.pillCY - root.cardH / 2

    // It unfolds from its own centre, like the power menu, instead of sweeping
    // out of the capsule -- which stays put.
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
        color: Services.Colors.surfacePill
        opacity: arrive.fade
        visible: opacity > 0.01
        clip: true

        Item {
            anchors.centerIn: parent
            width: root.cardW
            height: root.cardH
            opacity: arrive.contentAmt

            // The same capsule the bar uses for a set of choices: one plate,
            // one accent that slides to the pick.
            Rectangle {
                id: profCapsule
                anchors.centerIn: parent
                width: profRow.width + 20
                height: root.cardH
                radius: Services.Sizes.innerR
                // The blob behind it is already this plate.
                color: "transparent"

                readonly property var model_: [
                    { id: "power-saver", icon: "" },
                    { id: "balanced", icon: "" },
                    { id: "performance", icon: "" },
                ]
                readonly property int activeIdx: {
                    for (let i = 0; i < model_.length; i++)
                        if (model_[i].id === root.activeProfile) return i
                    return -1
                }

                Rectangle {
                    width: 32; height: 32
                    radius: Services.Sizes.innerR
                    color: Services.Colors.ghost
                    gradient: Services.Prefs.useGradients ? Services.Colors.accentGradient : null
                    y: (parent.height - height) / 2
                    x: 10 + profCapsule.activeIdx * (32 + 4)
                    opacity: profCapsule.activeIdx >= 0 ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: Services.Sizes.msStandard } }
                    Behavior on x { SmoothedAnimation { duration: Services.Sizes.msPronounced } }
                }

                Row {
                    id: profRow
                    anchors.centerIn: parent
                    spacing: 4
                    Repeater {
                        model: profCapsule.model_
                        delegate: Item {
                            id: profItem
                            required property var modelData
                            readonly property bool available: root.profiles.includes(modelData.id)
                            readonly property bool isActive: root.activeProfile === modelData.id
                            width: 32; height: 32
                            opacity: available ? 1.0 : 0.3

                            Text {
                                anchors.centerIn: parent
                                text: profItem.modelData.icon
                                font.family: "Material Symbols Rounded"
                                font.pixelSize: 16
                                color: profItem.isActive ? Services.Colors.accentText
                                     : (profHover.containsMouse ? Services.Colors.snow
                                                                : Services.Colors.mist)
                                Behavior on color { ColorAnimation { duration: Services.Sizes.msMicro } }
                                // Hover grows and brightens; the plate never changes.
                                scale: Services.Sizes.hoverScale(profHover.containsMouse, profHover.pressed)
                                Behavior on scale { NumberAnimation { duration: Services.Sizes.pillHoverMs; easing.type: Services.Sizes.easeOut } }
                            }

                            MouseArea {
                                id: profHover
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: profItem.available ? Qt.PointingHandCursor : Qt.ForbiddenCursor
                                enabled: profItem.available
                                onClicked: root.profilePicked(profItem.modelData.id)
                            }
                        }
                    }
                }
            }
        }
    }
}
