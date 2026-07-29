import QtQuick
import QtQuick.Layouts
import "root:/services" as Services

// One-of-many picker with the sliding highlight the workspace pill uses: the
// accent never jumps between options, it travels. Every exclusive choice in
// Settings goes through this, so they all behave the same.
//
// Cells are equal width, so the indicator only has to move — with content-width
// cells it would have to resize mid-flight and the travel reads as a stretch.
Item {
    id: root

    // [{ id, label, icon (optional), available (optional, default true) }]
    property var options: []
    property string current: ""
    // Icon above label instead of a single line of text
    property bool stacked: false
    // Icon only: for rails where the label has no room
    property bool iconOnly: false
    property int cellHeight: stacked ? 64 : 32
    property int pad: 4
    property int iconSize: stacked || iconOnly ? 20 : 15
    property int labelSize: stacked ? 10 : 11
    signal picked(string id)

    readonly property int count: Math.max(1, options.length)
    readonly property real cellWidth: (width - pad * 2) / count
    readonly property int currentIndex: {
        for (let i = 0; i < options.length; i++)
            if (options[i].id === root.current) return i
        return -1
    }

    Layout.fillWidth: true
    implicitHeight: cellHeight + pad * 2
    implicitWidth: 200

    Rectangle {
        anchors.fill: parent
        radius: 12
        color: Services.Colors.ghostAlpha(0.12)
    }

    // The travelling accent. Hidden rather than parked at 0 when nothing is
    // selected, so it never slides in from a cell the user did not pick.
    Rectangle {
        id: indicator
        visible: root.currentIndex >= 0
        width: root.cellWidth
        height: root.cellHeight
        radius: 9
        x: root.pad + Math.max(0, root.currentIndex) * root.cellWidth
        y: root.pad
        color: Services.Colors.ghost
        gradient: Services.Prefs.useGradients ? Services.Colors.accentGradient : null
        Behavior on x { SmoothedAnimation { duration: 250 } }
        Behavior on width { SmoothedAnimation { duration: 250 } }
    }

    Row {
        anchors.fill: parent
        anchors.margins: root.pad

        Repeater {
            model: root.options
            delegate: Item {
                id: cell
                required property var modelData
                required property int index
                readonly property bool active: root.current === modelData.id
                // Profiles the machine does not support are shown, not hidden:
                // their absence is information too.
                readonly property bool available: modelData.available === undefined || modelData.available
                width: root.cellWidth
                height: root.cellHeight
                opacity: available ? 1.0 : 0.35

                readonly property bool hasIcon: modelData.icon !== undefined && modelData.icon !== ""
                readonly property bool hasLabel: !root.iconOnly
                    && modelData.label !== undefined && modelData.label !== ""

                // Stacked puts the icon over the label, flat puts them side by
                // side. Columns must match what is actually drawn: a Grid with
                // spare columns reserves a trailing gap and the content stops
                // being centred.
                Grid {
                    anchors.centerIn: parent
                    columns: root.stacked ? 1 : ((cell.hasIcon ? 1 : 0) + (cell.hasLabel ? 1 : 0))
                    horizontalItemAlignment: Grid.AlignHCenter
                    verticalItemAlignment: Grid.AlignVCenter
                    spacing: root.stacked ? 3 : 7

                    Text {
                        visible: cell.hasIcon
                        text: cell.hasIcon ? cell.modelData.icon : ""
                        font.family: "Material Symbols Rounded"
                        font.pixelSize: root.iconSize
                        color: cell.active ? Services.Colors.abyss : Services.Colors.mist
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }
                    Text {
                        visible: cell.hasLabel
                        text: cell.hasLabel ? cell.modelData.label : ""
                        font.pixelSize: root.labelSize
                        font.family: "JetBrainsMono NF"
                        color: cell.active ? Services.Colors.abyss : Services.Colors.snow
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: cell.available ? Qt.PointingHandCursor : Qt.ForbiddenCursor
                    enabled: cell.available
                    onClicked: root.picked(cell.modelData.id)
                }
            }
        }
    }
}
