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

    // Human label for the currently active device.
    function currentDesc() {
        for (let i = 0; i < devices.length; i++)
            if (devices[i].name === current) return devices[i].desc
        return "—"
    }

    spacing: 4

    // ── Header (current device + chevron) ──────────────────────────────────
    Rectangle {
        width: parent.width
        height: picker.rowH
        radius: 8
        color: headArea.containsMouse ? Services.Colors.ghostAlpha(0.14) : Services.Colors.ghostAlpha(0.06)
        Behavior on color { ColorAnimation { duration: 120 } }

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
            Behavior on rotation { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
        }

        MouseArea {
            id: headArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: picker.expanded = !picker.expanded
        }
    }

    // ── Options (slide open) ───────────────────────────────────────────────
    Item {
        width: parent.width
        clip: true
        height: picker.expanded ? optsCol.implicitHeight : 0
        Behavior on height { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
        opacity: picker.expanded ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 160 } }

        Column {
            id: optsCol
            width: parent.width
            spacing: 2

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
                    Behavior on color { ColorAnimation { duration: 120 } }

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
