import QtQuick
import "root:/services" as Services

// A reading held as water in a box: the level IS the number, and the thin
// outline is the glass holding it. Sound and brightness use it; the battery
// keeps its ring, where the sweep from empty is the whole point.
Item {
    id: box

    property int size: 120
    // 0..1. Eased into `frac`, which is what the water follows.
    property real value: 0
    property int easeMs: 220

    property string glyph: ""
    property string label: ""
    property int glyphSize: 18
    property int labelSize: 22
    // The bar pill flies its own copies during a morph; the box hides its own
    // so there are never two of the same glyph on screen.
    property bool hideGlyph: false
    property bool hideLabel: false

    property color fillColor: Services.Colors.ghost
    property bool running: true

    // What a DropCard hands over to, same names the dial answers to.
    readonly property alias glyphItem: glyphText
    readonly property alias labelItem: labelText

    signal tapped()

    property real frac: 0
    onValueChanged: box.frac = Math.max(0, Math.min(1, box.value))
    Component.onCompleted: box.frac = Math.max(0, Math.min(1, box.value))
    Behavior on frac {
        NumberAnimation { duration: box.easeMs; easing.type: Services.Sizes.easeOut }
    }

    implicitWidth: box.size
    implicitHeight: box.size
    width: implicitWidth
    height: implicitHeight

    scale: Services.Sizes.hoverScale(hover.containsMouse, hover.pressed)
    Behavior on scale {
        NumberAnimation { duration: Services.Sizes.pillHoverMs; easing.type: Services.Sizes.easeOut }
    }

    Rectangle {
        id: vessel
        anchors.fill: parent
        radius: Services.Sizes.panelR
        color: Services.Colors.fillInset
        border.width: 1
        border.color: hover.containsMouse ? Services.Colors.ghostAlpha(0.4)
                                          : Services.Colors.ghostAlpha(0.22)
        Behavior on border.color { ColorAnimation { duration: Services.Sizes.msStandard } }
    }

    LiquidFill {
        id: water
        anchors.fill: parent
        shape: "rect"
        radius_: vessel.radius
        level: box.frac
        // Fuller means livelier, the same rule the system board reads by.
        waveAmp: 2.6 + box.frac * 3.4
        periodMs: Math.round(5200 - box.frac * 2200)
        running: box.running && box.visible
        color_: box.fillColor
        layer.enabled: true
    }

    Item {
        id: face
        anchors.fill: parent

        Column {
            anchors.centerIn: parent
            spacing: 2

            Text {
                id: glyphText
                anchors.horizontalCenter: parent.horizontalCenter
                text: box.glyph
                visible: !box.hideGlyph && box.glyphSize > 0
                color: Services.Colors.mist
                font.pixelSize: box.glyphSize
                font.family: "Material Symbols Rounded"
            }
            Text {
                id: labelText
                anchors.horizontalCenter: parent.horizontalCenter
                text: box.label
                visible: !box.hideLabel && box.labelSize > 0
                color: Services.Colors.snow
                font.pixelSize: box.labelSize
                font.bold: true
                font.family: "JetBrainsMono NF"
            }
        }
    }

    // The part of the face the water has reached, re-inked so it never sits on
    // a tone it shares.
    Submerged {
        anchors.fill: parent
        source: face
        mask: water
        ink: Services.Colors.onColor(box.fillColor)
    }

    MouseArea {
        id: hover
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: box.tapped()
    }
}
