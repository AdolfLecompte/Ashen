import QtQuick
import QtQuick.Layouts

import "root:/services" as Services

// The 3x3 board Settings > Display arranges monitors on. Nine slots instead of
// a free canvas: the eight around the centre are exactly the eight ways a
// second screen can touch the first, and snapping to them means no gap can ever
// open up -- Hyprland allows gaps, but a gap is a strip the cursor cannot cross.
//
// Monitors that have no place yet, and mirrors, wait in the tray underneath:
// a mirrored output has no geometry of its own, so it has no business on a
// board that is only about position.
Item {
    id: grid

    property string selected: ""
    signal picked(string key)

    // 16:9, so a cell reads as a screen rather than a button.
    readonly property int cellW: 132
    readonly property int cellH: 76
    readonly property int gap: 8

    implicitWidth: cellW * 3 + gap * 2
    implicitHeight: board.height + tray.height + (tray.visible ? 16 : 0)

    // Everything Hyprland currently reports, split by where it belongs.
    readonly property var placed: {
        const out = {}
        for (const m of Services.Displays.monitors) {
            const k = Services.Displays.keyOf(m)
            const e = Services.Displays.entry(k)
            if (e.mirror === "" && e.cell >= 0 && e.cell <= 8) out[e.cell] = k
        }
        return out
    }
    readonly property var loose: {
        const out = []
        for (const m of Services.Displays.monitors) {
            const k = Services.Displays.keyOf(m)
            const e = Services.Displays.entry(k)
            if (e.mirror !== "" || e.cell < 0 || e.cell > 8) out.push(k)
        }
        return out
    }

    function shortName(key) {
        const m = Services.Displays.byKey(key)
        return m ? m.name : key
    }
    function sizeLabel(key) {
        const m = Services.Displays.byKey(key)
        if (!m) return ""
        const e = Services.Displays.entry(key)
        const s = Services.Displays.logicalSize(m, e)
        return s.w + "×" + s.h
    }

    Grid {
        id: board
        columns: 3
        spacing: grid.gap
        anchors.horizontalCenter: parent.horizontalCenter

        Repeater {
            model: 9
            delegate: Rectangle {
                id: cell
                required property int index
                readonly property string key: grid.placed[index] !== undefined ? grid.placed[index] : ""
                readonly property bool empty: key === ""
                readonly property bool isCentre: index === 4

                width: grid.cellW
                height: grid.cellH
                radius: Services.Sizes.cardR
                // An empty slot is a recess in the card, not a control.
                color: Services.Colors.fillInset

                // Only the border moves while something is dragged over it. A
                // drop target is a state, not a hover, and the hover language is
                // reserved for the pointer resting on a thing you can press.
                border.width: 1
                border.color: drop.containsDrag ? Services.Colors.ghost
                    : (cell.isCentre ? Services.Colors.fillRest : Services.Colors.fillLine)
                Behavior on border.color { ColorAnimation { duration: Services.Sizes.msMicro } }

                DropArea {
                    id: drop
                    anchors.fill: parent
                    onDropped: function (drag) {
                        if (drag.source && drag.source.monKey)
                            Services.Displays.moveToCell(drag.source.monKey, cell.index)
                    }
                }

                // The centre says it is the middle even while it is empty, so
                // the board reads as a place before anything is on it.
                Text {
                    anchors.centerIn: parent
                    visible: cell.empty
                    text: cell.isCentre ? "" : ""
                    font.family: "Material Symbols Rounded"
                    font.pixelSize: cell.isCentre ? 18 : 14
                    color: cell.isCentre ? Services.Colors.ash : Services.Colors.fillLine
                }

                MonitorCard {
                    visible: !cell.empty
                    monKey: cell.key
                    anchors.fill: parent
                    anchors.margins: 4
                    onTapped: grid.picked(cell.key)
                }
            }
        }
    }

    // Not on the board: never arranged, or mirroring something else.
    ColumnLayout {
        id: tray
        anchors.top: board.bottom
        anchors.topMargin: 16
        anchors.horizontalCenter: parent.horizontalCenter
        width: board.width
        spacing: 6
        visible: grid.loose.length > 0

        Text {
            text: "Not placed"
            color: Services.Colors.mist
            font.pixelSize: Services.Sizes.fsMeta
            font.family: "JetBrainsMono NF"
        }
        Flow {
            Layout.fillWidth: true
            spacing: grid.gap
            Repeater {
                model: grid.loose
                delegate: Item {
                    required property string modelData
                    width: grid.cellW
                    height: grid.cellH - 20
                    MonitorCard {
                        anchors.fill: parent
                        monKey: parent.modelData
                        onTapped: grid.picked(parent.modelData)
                    }
                }
            }
        }
    }

    // One monitor, wherever it is standing. Draggable by the same internal-drag
    // route the bar layout editor uses: the id has to ride on the item, because
    // an internal drag carries the item and nothing else.
    component MonitorCard: Item {
        id: card
        property string monKey: ""
        signal tapped()

        readonly property var ent: Services.Displays.entry(card.monKey)
        readonly property bool mirrored: card.ent.mirror !== ""
        readonly property bool off: card.ent.disabled
        readonly property bool chosen: grid.selected === card.monKey
        readonly property bool warm: dragArea.containsMouse

        // Hover grows it and its letters brighten; the plate never lights up.
        scale: Services.Sizes.hoverScale(card.warm, dragArea.pressed)
        Behavior on scale { NumberAnimation { duration: Services.Sizes.pillHoverMs; easing.type: Services.Sizes.easeOut } }

        Rectangle {
            id: face
            width: card.width
            height: card.height
            radius: Services.Sizes.pillR
            // Selected wears the accent, which is what "this is the one" looks
            // like everywhere else in the shell. A mirror or a screen that is
            // off is not a place, and says so by going quiet.
            color: card.chosen ? Services.Colors.ghost : Services.Colors.fillRest
            gradient: Services.Prefs.useGradients && card.chosen ? Services.Colors.accentGradient : null
            opacity: card.mirrored || card.off ? 0.45 : 1.0
            Behavior on color { ColorAnimation { duration: Services.Sizes.msStandard } }

            // What the drop target reads off the dragged item
            property string monKey: card.monKey

            Drag.active: dragArea.drag.active
            Drag.dragType: Drag.Internal
            Drag.hotSpot.x: width / 2
            Drag.hotSpot.y: height / 2
            Behavior on x { enabled: !dragArea.drag.active; NumberAnimation { duration: Services.Sizes.msMicro; easing.type: Services.Sizes.easeOut } }
            Behavior on y { enabled: !dragArea.drag.active; NumberAnimation { duration: Services.Sizes.msMicro; easing.type: Services.Sizes.easeOut } }

            ColumnLayout {
                anchors.centerIn: parent
                width: face.width - 8
                spacing: 1
                Text {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    text: grid.shortName(card.monKey)
                    color: card.chosen ? Services.Colors.accentText
                         : card.warm ? Services.Colors.snow : Services.Colors.surfaceText
                    font.pixelSize: Services.Sizes.fsBody
                    font.bold: true
                    font.family: "JetBrainsMono NF"
                    Behavior on color { ColorAnimation { duration: Services.Sizes.msStandard } }
                }
                Text {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    text: card.mirrored ? "mirror" : (card.off ? "off" : grid.sizeLabel(card.monKey))
                    color: card.chosen ? Services.Colors.accentBody : Services.Colors.surfaceBody
                    font.pixelSize: Services.Sizes.fsCaption
                    font.family: "JetBrainsMono NF"
                    Behavior on color { ColorAnimation { duration: Services.Sizes.msStandard } }
                }
            }

            MouseArea {
                id: dragArea
                anchors.fill: parent
                hoverEnabled: true
                drag.target: face
                drag.smoothed: false
                cursorShape: drag.active ? Qt.ClosedHandCursor : Qt.PointingHandCursor

                // A card sits INSIDE the cell that owns it, so a Drag.drop() on
                // a plain click lands on a DropArea straight away and re-places
                // the monitor nobody asked to move. Only a release that actually
                // travelled counts as a drop; everything else is a tap.
                property bool travelled: false
                onPressed: dragArea.travelled = false
                onPositionChanged: if (dragArea.drag.active) dragArea.travelled = true
                onReleased: {
                    if (dragArea.travelled) face.Drag.drop()
                    else card.tapped()
                    // Home again: reached when nothing caught it, and after a tap.
                    face.x = 0
                    face.y = 0
                }
            }
        }
    }
}
