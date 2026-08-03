import QtQuick
import Qt5Compat.GraphicalEffects
import QtQuick.Layouts
import "root:/services" as Services

// Profile picture and Wallpaper are the same card: a rounded preview of an
// image, a glyph while there is none, a label pinned beside it and one
// action button.
Rectangle {
    id: card
    property string source: ""
    property string fallbackGlyph: ""
    property string title: ""
    property string subtitle: ""
    property string action: ""
    // Square + crop suits a face; a wallpaper needs a wide tile and a fit,
    // since they run from near-square to 2.76 ultrawide and cropping would
    // hide most of the picture.
    property int previewWidth: 80
    property int previewFill: Image.PreserveAspectCrop
    signal triggered()

    Layout.fillWidth: true
    height: 110
    radius: 12
    color: cardHover.containsMouse ? Services.Colors.ghostAlpha(0.18) : Services.Colors.ghostAlpha(0.1)
    Behavior on color { ColorAnimation { duration: Services.Sizes.msMicro } }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        // Small gap only: the label belongs to the picture, so it sits next
        // to it rather than drifting into the middle of the card.
        spacing: 12

        Rectangle {
            id: preview
            width: card.previewWidth; height: 80
            radius: 12
            color: Services.Colors.ghostAlpha(0.2)
            clip: true

            // Masked through the image's own layer: a separate OpacityMask
            // item left the picture poking out of one rounded corner.
            Image {
                id: previewImg
                anchors.fill: parent
                source: card.source
                fillMode: card.previewFill
                asynchronous: true
                visible: status === Image.Ready
                // paths are stable while the file behind them changes
                cache: false
                layer.enabled: true
                layer.smooth: true
                layer.effect: OpacityMask {
                    maskSource: Rectangle {
                        width: preview.width
                        height: preview.height
                        radius: preview.radius
                    }
                }
            }
            Text {
                anchors.centerIn: parent
                text: card.fallbackGlyph
                color: Services.Colors.ghost
                font.pixelSize: 40
                font.family: "Material Symbols Rounded"
                visible: previewImg.status !== Image.Ready
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 3
            Text {
                text: card.title
                color: Services.Colors.snow
                font.pixelSize: 15
                font.bold: true
                font.family: "JetBrainsMono NF"
                Layout.alignment: Qt.AlignLeft
            }
            Text {
                text: card.subtitle
                color: Services.Colors.mist
                font.pixelSize: 10
                font.family: "JetBrainsMono NF"
                elide: Text.ElideMiddle
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignLeft
            }
        }

        Rectangle {
            width: 90; height: 36
            radius: 8
            color: Services.Colors.ghost
            gradient: Services.Prefs.useGradients ? Services.Colors.accentGradient : null
            Text {
                anchors.centerIn: parent
                text: card.action
                color: Services.Colors.accentText
                font.pixelSize: 12
                font.bold: true
                font.family: "JetBrainsMono NF"
            }
        }
    }
    MouseArea {
        id: cardHover
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        hoverEnabled: true
        onClicked: card.triggered()
    }
}
