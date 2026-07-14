import Quickshell
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts

import "root:/services" as Services

Row {
    id: root
    spacing: 6

    readonly property int pillH: 44
    readonly property int innerH: 32
    readonly property int innerR: 8
    readonly property int pillR: 10
    readonly property int pad: 8

    // Hyprland does not emit the `workspace` event when entering a special, so
    // focusedWorkspace is useless: the monitor is what knows which one is shown.
    readonly property string shownSpecial: {
        const mon = Hyprland.focusedMonitor
        const ipc = mon ? mon.lastIpcObject : null
        const sw = ipc ? ipc.specialWorkspace : null
        return (sw && sw.name) ? sw.name : ""
    }
    readonly property bool inSpecial: shownSpecial !== ""

    // Every special that exists (has windows), not just the one being shown.
    readonly property var specials: Hyprland.workspaces.values
        .filter(w => w.id < 0)
        .sort((a, b) => b.id - a.id)

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name.startsWith("activespecial"))
                Hyprland.refreshMonitors()
        }
    }

    // Last focused normal workspace: specials have a negative id and would break
    // the group-of-5 calculation.
    property int lastNormalId: 1
    Connections {
        target: Hyprland
        function onFocusedWorkspaceChanged() {
            const f = Hyprland.focusedWorkspace
            if (f && f.id > 0)
                root.lastNormalId = f.id
        }
    }

    function specialIcon(name) {
        if (name === "music")   return ""
        if (name === "discord") return ""
        if (name === "notes")   return ""
        if (name === "term")    return ""
        if (name === "fav")     return ""
        return ""
    }

    // Workspaces normales
    Rectangle {
        height: root.pillH
        radius: root.pillR
        color: Services.Colors.surfaceAlpha(0.82)
        border.color: Services.Colors.ghostAlpha(0.2)
        border.width: 1
        width: wsRow.width + root.pad * 2

        Rectangle {
            id: slideIndicator
            width: root.innerH; height: root.innerH
            radius: root.innerR
            color: Services.Colors.ghost
            opacity: root.inSpecial ? 0 : 1
            Behavior on opacity { NumberAnimation { duration: 200 } }
            y: (root.pillH - root.innerH) / 2
            x: {
                let base = Math.floor((root.lastNormalId - 1) / 5) * 5
                let idx = root.lastNormalId - base - 1
                return root.pad + idx * (root.innerH + 4)
            }
            Behavior on x { SmoothedAnimation { duration: 250 } }
        }

        Row {
            id: wsRow
            anchors.centerIn: parent
            spacing: 4
            opacity: root.inSpecial ? 0 : 1
            enabled: !root.inSpecial
            Behavior on opacity { NumberAnimation { duration: 200 } }

            Repeater {
                model: 5
                delegate: Item {
                    required property int index
                    property int wsId: {
                        let base = Math.floor((root.lastNormalId - 1) / 5) * 5
                        return base + index + 1
                    }
                    property bool isActive: root.lastNormalId === wsId
                    property bool hasWindows: Hyprland.workspaces.values.find(w => w.id === wsId) !== undefined
                    width: root.innerH; height: root.innerH

                    Rectangle {
                        anchors.fill: parent
                        radius: root.innerR
                        color: Services.Colors.ghost
                        opacity: parent.hasWindows && !parent.isActive ? 0.2 : 0
                        Behavior on opacity { NumberAnimation { duration: 200 } }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: wsId
                        color: parent.isActive ? Services.Colors.abyss : Services.Colors.ash
                        font.pixelSize: 13
                        font.family: "JetBrainsMono NF"
                        font.bold: parent.isActive
                        z: 1
                        Behavior on color { ColorAnimation { duration: 200 } }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        z: 10
                        onClicked: { var id = wsId; Quickshell.execDetached(["sh", "-c", "hyprctl dispatch 'hl.dsp.focus({ workspace = " + id + " })'"]) }
                    }
                }
            }
        }

        // Special workspaces: they overlay the numbers while one is being shown.
        // The shown one is filled; the rest are dimmed.
        Row {
            id: specialRow
            anchors.centerIn: parent
            spacing: 4
            opacity: root.inSpecial ? 1 : 0
            enabled: root.inSpecial
            z: 2
            Behavior on opacity { NumberAnimation { duration: 200 } }

            Repeater {
                model: root.specials

                delegate: Item {
                    required property var modelData
                    readonly property string shortName: modelData.name.replace("special:", "")
                    readonly property bool isShown: modelData.name === root.shownSpecial
                    width: root.innerH; height: root.innerH

                    Rectangle {
                        anchors.fill: parent
                        radius: root.innerR
                        color: parent.isShown ? Services.Colors.ghost : Services.Colors.ghostAlpha(0.2)
                        Behavior on color { ColorAnimation { duration: 200 } }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: root.specialIcon(parent.shortName)
                        color: parent.isShown ? Services.Colors.abyss : Services.Colors.ash
                        font.pixelSize: 18
                        font.family: "Material Symbols Rounded"
                        z: 1
                        Behavior on color { ColorAnimation { duration: 200 } }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        z: 10
                        onClicked: {
                            var n = parent.shortName
                            Quickshell.execDetached(["sh", "-c", "hyprctl dispatch 'hl.dsp.workspace.toggle_special(\"" + n + "\")'"])
                        }
                    }
                }
            }
        }
    }
}
