import QtQuick

import "root:/services" as Services

Rectangle {
    id: root
    property bool capsActive: Services.Notifications.lastCapsLock
    property bool numActive: Services.Notifications.lastNumLock
    property bool anyActive: capsActive || numActive

    readonly property bool vertical: Services.Sizes.barVertical

    height: root.vertical ? (anyActive ? Math.max(Services.Sizes.pillH, locksCol.height + 18) : 0)
                          : Services.Sizes.pillH
    radius: Services.Sizes.pillR
    // Solid-accent containment pill with dark glyphs, so the locks read clearly.
    // Glyphs sit at a middle size: big enough to fill the pill squarely, not the
    // oversized 24px that dominated the bar.
    color: Services.Colors.ghost
    gradient: Services.Prefs.useGradients ? Services.Colors.accentGradient : null
    border.width: 0
    width: root.vertical ? Services.Sizes.pillH
                         : (anyActive ? Math.max(Services.Sizes.pillH, locksRow.width + 18) : 0)
    opacity: anyActive ? 1.0 : 0.0
    // How much room it is taking along the bar's own axis.
    readonly property real extent: root.vertical ? height : width
    // Stays until the collapse has finished, not until the fade has: keyed on
    // opacity alone it left the layout with 50 ms of width still to give back,
    // and the gap slammed shut under the pills next to it.
    visible: Services.Prefs.pillVisible("locks") && (root.anyActive || root.extent > 1)
    clip: true
    Behavior on width { NumberAnimation { duration: Services.Sizes.msStandard; easing.type: Services.Sizes.easeOut } }
    Behavior on height { NumberAnimation { duration: Services.Sizes.msStandard; easing.type: Services.Sizes.easeOut } }
    Behavior on opacity { NumberAnimation { duration: Services.Sizes.msMicro } }


    // Material Symbols draw their ink inside a wider advance box, so a plain
    // Text sits left of centre and leaves a gap on the right. This wraps the
    // glyph in an item the size of the ink itself, so the pill can centre it.
    component LockGlyph: Item {
        id: cellRoot
        property alias text: label.text
        property bool on: false
        visible: on
        implicitWidth: Math.max(1, ink.tightBoundingRect.width)
        implicitHeight: Math.max(1, ink.tightBoundingRect.height)
        width: implicitWidth
        height: implicitHeight

        Text {
            id: label
            x: -ink.tightBoundingRect.x
            y: -(fm.ascent + ink.tightBoundingRect.y)
            color: Services.Colors.accentText
            font.pixelSize: 20
            font.bold: true
            font.family: "Material Symbols Rounded"
        }

        TextMetrics { id: ink; font: label.font; text: label.text }
        FontMetrics { id: fm; font: label.font }
    }

    // Side by side on a horizontal bar…
    Row {
        id: locksRow
        visible: !root.vertical
        anchors.centerIn: parent
        spacing: 8

        LockGlyph {
            on: root.capsActive
            text: "\ue318"                 // keyboard_capslock
            anchors.verticalCenter: parent.verticalCenter
        }
        LockGlyph {
            on: root.numActive
            text: "\ue400"                 // looks_one
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    // …stacked on a side bar, where there is no width to share
    Column {
        id: locksCol
        visible: root.vertical
        anchors.centerIn: parent
        spacing: 6

        LockGlyph {
            on: root.capsActive
            text: "\ue318"                 // keyboard_capslock
            anchors.horizontalCenter: parent.horizontalCenter
        }
        LockGlyph {
            on: root.numActive
            text: "\ue400"                 // looks_one
            anchors.horizontalCenter: parent.horizontalCenter
        }
    }
}
