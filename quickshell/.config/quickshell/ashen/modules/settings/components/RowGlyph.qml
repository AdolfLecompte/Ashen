import QtQuick
import "root:/services" as Services

// Fixed-size glyph box so every setting row's label starts at the same x
// (matches the boxed glyph SliderRow uses).
Rectangle {
    id: rg
    property string glyph: ""
    implicitWidth: 26; implicitHeight: 26; radius: Services.Sizes.innerR; color: "transparent"
    Text {
        anchors.centerIn: parent
        text: rg.glyph
        font.family: "Material Symbols Rounded"
        font.pixelSize: 18
        color: Services.Colors.ghost
    }
}
