import QtQuick
import QtQuick.Layouts

import "root:/services" as Services

// The title a panel column opens with: icon in a soft box, name, detail
// under it. Both columns of a two-column panel wear one, and it is what
// the utility pill's chip flies its icon into.
RowLayout {
    id: sh

    property string glyph: ""
    property string title: ""
    property string detail: ""

    // What the drop aims its flying copy at, and how the real one gets out of
    // the way while that copy is still in the air. A plain property rather
    // than writing through the alias: QML has no way to set `alias.property`
    // from an initialiser.
    property alias glyphItem: shGlyph
    property real glyphOpacity: 1

    spacing: 10

    Rectangle {
        Layout.preferredWidth: 40
        Layout.preferredHeight: 40
        radius: 13
        color: Services.Colors.ghostAlpha(0.14)
        Text {
            id: shGlyph
            anchors.centerIn: parent
            text: sh.glyph
            opacity: sh.glyphOpacity
            color: Services.Colors.ghost
            font.pixelSize: 21
            font.family: "Material Symbols Rounded"
        }
    }

    ColumnLayout {
        spacing: 0
        Layout.fillWidth: true
        Text {
            text: sh.title
            color: Services.Colors.snow
            font.pixelSize: 17
            font.bold: true
            font.family: "JetBrainsMono NF"
        }
        Text {
            text: sh.detail
            color: Services.Colors.ash
            font.pixelSize: 9
            font.family: "JetBrainsMono NF"
            elide: Text.ElideRight
            Layout.fillWidth: true
        }
    }
}
