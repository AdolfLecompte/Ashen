import QtQuick
import QtQuick.Layouts
import "root:/services" as Services
import "root:/modules/widgets" as Widgets

// Volume, mic and brightness are the same widget with a different backend, so
// the row lives here once. The track itself is shared with the bar pills
// (modules/widgets/SliderTrack) so drag behaviour cannot drift apart.
ColumnLayout {
    id: sliderRow
    property string glyph: ""
    property string label: ""
    property int value: 0                 // authoritative, from the service
    // What is on screen right now: follows the drag, not the 1s service poll
    readonly property int shownPct: Math.round(bar.shown * 100)
    property string valueText: shownPct + "%"
    property bool dimmed: false
    property bool muted: false
    // Brightness has nothing to mute, so its glyph must not pretend to be
    // a button (no hover, no hand cursor).
    property bool glyphInteractive: false
    signal moved(int pct)
    signal glyphClicked()

    Layout.fillWidth: true
    spacing: 6

    RowLayout {
        spacing: 10
        Rectangle {
            width: 26; height: 26
            radius: 8
            color: glyphArea.containsMouse && sliderRow.glyphInteractive
                ? Services.Colors.ghostAlpha(0.2) : "transparent"
            Behavior on color { ColorAnimation { duration: 120 } }
            Text {
                anchors.centerIn: parent
                text: sliderRow.glyph
                font.family: "Material Symbols Rounded"
                font.pixelSize: 18
                color: sliderRow.muted ? Services.Colors.mist : Services.Colors.ghost
                Behavior on color { ColorAnimation { duration: 120 } }
            }
            MouseArea {
                id: glyphArea
                anchors.fill: parent
                enabled: sliderRow.glyphInteractive
                hoverEnabled: sliderRow.glyphInteractive
                cursorShape: Qt.PointingHandCursor
                onClicked: sliderRow.glyphClicked()
            }
        }
        Text {
            text: sliderRow.label
            color: Services.Colors.snow
            font.pixelSize: 13
            font.family: "JetBrainsMono NF"
            Layout.fillWidth: true
        }
        Text {
            text: sliderRow.valueText
            color: Services.Colors.mist
            font.pixelSize: 12
            font.family: "JetBrainsMono NF"
        }
    }
    Widgets.SliderTrack {
        id: bar
        Layout.fillWidth: true
        value: sliderRow.value / 100
        dimmed: sliderRow.dimmed
        onMoved: r => sliderRow.moved(Math.round(r * 100))
    }
}
