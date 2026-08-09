import QtQuick

import "root:/services" as Services
import "root:/modules/widgets" as Widgets

// The battery's card on the lock screen: the power profiles, and nothing the
// capsule already says. Opens sideways, so it covers nothing above it. An Item
// and not a window -- the lock is one surface -- morphing out of its capsule.
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

    // True while the card is on screen wearing the capsule's face -- which in
    // "window" style it never is, so the capsule stays put.
    readonly property alias wearingFace: card.wearingFace

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

    Widgets.MorphCard {
        id: card
        anchors.fill: parent
        shown: root.shown
        // No bar to hang from, so no goo neck and no bar-relative landing.
        neck: false
        // It leaves the capsule out of its side, so it sweeps sideways.
        sideways: true
        pillCX: root.pillCX
        pillCY: root.pillCY
        pillW: root.pillW
        pillH: root.pillH
        openW: root.cardW
        openH: root.cardH
        // No container around it: the capsule of profiles IS the card, so the
        // blob wears that plate and grows straight into it. Transparent would
        // have worked too, but then the morph would have nothing to draw.
        plateColor: Services.Colors.surfacePill
        // Out to the LEFT of its capsule and level with it: upwards is where
        // the clock and the music live.
        openXOverride: root.pillCX - root.pillW / 2 - root.gap - root.cardW
        openYOverride: root.pillCY - root.cardH / 2

        Item {
            anchors.centerIn: parent
            width: root.cardW
            height: root.cardH
            opacity: card.contentAmt

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
