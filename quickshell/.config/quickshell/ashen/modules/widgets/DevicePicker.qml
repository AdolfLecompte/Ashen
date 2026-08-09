import QtQuick
import "root:/services" as Services

// Collapsible output/input device selector, shared by the volume panel for the
// sink (speakers/headphones) and the source (microphone). The caller passes the
// device list, the active device's node name, and a label glyph; picking a row
// emits picked(name). Same slide-open pattern used across the shell.
Column {
    id: picker

    property var devices: []
    property string current: ""
    property string glyph: ""
    signal picked(string name)

    property bool expanded: false
    readonly property int rowH: 28

    // Float the list over what is under it instead of pushing it down. The
    // volume panel wants the inline behaviour -- its picker IS the bottom of the
    // card -- but in a column of settings a list that shoves five rows down the
    // page loses you your place.
    property bool overlay: false

    // Human label for the currently active device.
    function currentDesc() {
        for (let i = 0; i < devices.length; i++)
            if (devices[i].name === current) return devices[i].desc
        return "—"
    }

    spacing: 4

    // The lift has to be on the picker ITSELF: z only orders an item against
    // its own siblings, and the rows this list has to cover are siblings of the
    // picker, not of the list inside it.
    z: picker.overlay && picker.expanded ? 50 : 0

    // ── Header (current device + chevron) ──────────────────────────────────
    Rectangle {
        id: head
        width: parent.width
        height: picker.rowH
        radius: 8
        color: headArea.containsMouse ? Services.Colors.ghostAlpha(0.14) : Services.Colors.ghostAlpha(0.06)
        Behavior on color { ColorAnimation { duration: Services.Sizes.msMicro } }

        Row {
            anchors.left: parent.left
            anchors.leftMargin: 8
            anchors.right: chevron.left
            anchors.rightMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: picker.glyph
                font.family: "Material Symbols Rounded"
                font.pixelSize: 15
                color: Services.Colors.mist
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 26
                text: picker.currentDesc()
                elide: Text.ElideRight
                color: Services.Colors.snow
                font.pixelSize: 11
                font.family: "JetBrainsMono NF"
            }
        }

        Text {
            id: chevron
            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            text: "\ue5cf"
            font.family: "Material Symbols Rounded"
            font.pixelSize: 16
            color: Services.Colors.mist
            rotation: picker.expanded ? 180 : 0
            Behavior on rotation { NumberAnimation { duration: Services.Sizes.msStandard; easing.type: Services.Sizes.easeOut } }
        }

        MouseArea {
            id: headArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: picker.expanded = !picker.expanded
        }

        Item {
            id: listBox
            y: head.height + 4
            width: head.width
            clip: !picker.overlay
            height: picker.expanded ? optsCol.implicitHeight : 0
            Behavior on height { NumberAnimation { duration: Services.Sizes.msStandard; easing.type: Services.Sizes.easeOut } }
            opacity: picker.expanded ? 1.0 : 0.0
            Behavior on opacity { NumberAnimation { duration: Services.Sizes.msMicro } }
            visible: opacity > 0.01

            // A floating list needs its own back, or the rows underneath show
            // through it.
            Rectangle {
                visible: picker.overlay
                anchors.fill: optsCol
                anchors.margins: -4
                radius: Services.Sizes.cardR
                color: Services.Colors.surfacePanel
                border.width: 1
                border.color: Services.Colors.fillLine
            }

            Column {
                id: optsCol
                width: parent.width
                spacing: 2
                // Slides down from under the header rather than appearing whole.
                y: picker.expanded ? 0 : -6
                Behavior on y { NumberAnimation { duration: Services.Sizes.msStandard; easing.type: Services.Sizes.easeOut } }

                Repeater {
                    model: picker.devices
                    delegate: Rectangle {
                        required property var modelData
                        readonly property bool active: modelData.name === picker.current
                        width: optsCol.width
                        height: picker.rowH
                        radius: 8
                        color: active ? Services.Colors.ghostAlpha(0.2)
                             : optArea.containsMouse ? Services.Colors.ghostAlpha(0.1)
                             : "transparent"
                        Behavior on color { ColorAnimation { duration: Services.Sizes.msMicro } }

                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 8
                            anchors.right: mark.left
                            anchors.rightMargin: 6
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.desc
                            elide: Text.ElideRight
                            color: active ? Services.Colors.snow : Services.Colors.mist
                            font.pixelSize: 11
                            font.family: "JetBrainsMono NF"
                            font.bold: active
                        }
                        Text {
                            id: mark
                            anchors.right: parent.right
                            anchors.rightMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            visible: active
                            text: "\ue5ca"
                            font.family: "Material Symbols Rounded"
                            font.pixelSize: 15
                            color: Services.Colors.ghost
                        }
                        MouseArea {
                            id: optArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                picker.picked(modelData.name)
                                picker.expanded = false
                            }
                        }
                    }
                }
            }
        }
    }

    // ── Options (slide open) ───────────────────────────────────────────────
    // Room for the list when it is inline; nothing at all when it floats.
    Item {
        width: 1
        height: picker.overlay ? 0 : listBox.height
    }
}
