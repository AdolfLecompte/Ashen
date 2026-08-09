import QtQuick
import QtQuick.Layouts
import "root:/services" as Services

// The box every settings section sits in: a titled, rounded panel that grows
// with its content. Children go straight inside it, no wrapper needed.
Rectangle {
    id: cardRoot
    default property alias content: cardInner.data
    property string title: ""
    Layout.fillWidth: true
    radius: Services.Sizes.cardR
    color: Services.Colors.fillInset
    implicitHeight: cardInner.implicitHeight + 32
    ColumnLayout {
        id: cardInner
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 16
        spacing: 12
        Text {
            text: cardRoot.title
            visible: cardRoot.title !== ""
            color: Services.Colors.mist
            font.pixelSize: Services.Sizes.fsBody
            font.family: "JetBrainsMono NF"
            Layout.bottomMargin: 4
        }
    }
}
