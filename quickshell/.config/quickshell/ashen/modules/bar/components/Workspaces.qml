import Quickshell
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts

import "root:/services" as Services

Item {
    id: root
    // Hidden from Settings > Bar > Pills
    visible: Services.Prefs.pillVisible("workspaces")

    // The bar flips the whole strip: chips stack instead of running across.
    readonly property bool vertical: Services.Sizes.barVertical
    width: pill.width
    height: pill.height

    readonly property int pillH: Services.Sizes.pillH
    readonly property int innerH: Services.Sizes.innerH
    readonly property int innerR: Services.Sizes.innerR
    readonly property int pillR: Services.Sizes.pillR
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
        if (name === "fav")     return ""
        return ""
    }


    // Hold the pointer still on a chip and that workspace opens a preview of
    // itself. 600 ms: long enough that sweeping across the strip never trips
    // it, short enough that it does not feel like waiting.
    component PreviewHover: MouseArea {
        id: ph
        property int wsId: 0
        property string label: ""
        // Nothing to preview on an empty workspace, so it never opens
        property bool previewable: false
        signal activated()

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        z: 10
        onClicked: ph.activated()

        onEntered: if (ph.previewable) dwell.restart()
        onExited: {
            dwell.stop()
            if (Services.AppState.wsPreviewId === ph.wsId)
                Services.AppState.wsPreviewId = 0
        }

        Timer {
            id: dwell
            interval: 600
            onTriggered: {
                const g = ph.mapToGlobal(0, 0)
                Services.AppState.setWsPreview(ph.wsId, ph.label, g.x, g.y, ph.width, ph.height)
            }
        }
    }

    // Workspaces normales
    Rectangle {
        id: pill
        radius: root.pillR
        color: Services.Colors.surfaceAlpha(0.82)
        border.color: Services.Colors.ghostAlpha(0.2)
        border.width: 0
        width: root.vertical ? root.pillH : wsRow.width + root.pad * 2
        height: root.vertical ? wsRow.height + root.pad * 2 : root.pillH

        Rectangle {
            id: slideIndicator
            width: root.innerH; height: root.innerH
            radius: root.innerR
            color: Services.Colors.ghost
            gradient: Services.Prefs.useGradients ? Services.Colors.accentGradient : null
            opacity: root.inSpecial ? 0 : 1
            Behavior on opacity { NumberAnimation { duration: 200 } }
            readonly property real slot: {
                let base = Math.floor((root.lastNormalId - 1) / 5) * 5
                let idx = root.lastNormalId - base - 1
                return root.pad + idx * (root.innerH + 4)
            }
            readonly property real centred: (root.pillH - root.innerH) / 2
            x: root.vertical ? centred : slot
            y: root.vertical ? slot : centred
            Behavior on x { SmoothedAnimation { duration: 250 } }
            Behavior on y { SmoothedAnimation { duration: 250 } }
        }

        BarStrip {
            id: wsRow
            anchors.centerIn: parent
            spacing: 4
            opacity: root.inSpecial ? 0 : 1
            enabled: !root.inSpecial
            // Both rows sit centred on the same spot, so the hidden one is
            // still lying over the visible one. Transparent is not gone:
            // `visible` is what actually removes it from the scene, and
            // without it the special chips kept catching the pointer meant
            // for the numbers underneath. Driven off opacity so the fade
            // still plays out before it disappears.
            visible: opacity > 0.01
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
                    // Hyprland lists the workspace you are standing on even when
                    // it is empty, so `hasWindows` says yes for the one you are
                    // on and the preview opened onto nothing. Count real windows.
                    readonly property int winCount:
                        Hyprland.toplevels.values.filter(t => t.workspace && t.workspace.id === wsId).length
                    width: root.innerH; height: root.innerH

                    Rectangle {
                        anchors.fill: parent
                        radius: root.innerR
                        color: Services.Colors.ghost
                        gradient: Services.Prefs.useGradients ? Services.Colors.accentGradient : null
                        // Active chips are already carried by the sliding
                        // indicator, so they stay bare; the rest light a little
                        // under the pointer, occupied or not.
                        opacity: parent.isActive ? 0
                            : chipHover.containsMouse ? 0.38
                            : parent.hasWindows ? 0.2 : 0
                        Behavior on opacity { NumberAnimation { duration: 200 } }
                    }

                    // A workspace with something on it shows what that is; an
                    // empty one keeps its number, which is the only thing left
                    // to identify it by.
                    readonly property string appIcon: Services.Prefs.workspaceIcons
                        ? Services.Windows.workspaceIcon(wsId) : ""

                    Text {
                        anchors.centerIn: parent
                        text: parent.appIcon !== "" ? parent.appIcon : wsId
                        color: parent.isActive ? Services.Colors.abyss : Services.Colors.ash
                        font.pixelSize: parent.appIcon !== "" ? 15 : 13
                        font.family: parent.appIcon !== "" ? "Material Symbols Rounded" : "JetBrainsMono NF"
                        font.bold: true
                        z: 1
                        // The preview flies this very label into its caption, so
                        // the chip lets go of it: two copies at once would give
                        // the trick away.
                        opacity: Services.AppState.wsPreviewMorphing
                            && Services.AppState.wsPreviewId === parent.wsId ? 0 : 1
                        Behavior on opacity { NumberAnimation { duration: 140 } }
                        Behavior on color { ColorAnimation { duration: 200 } }
                    }

                    PreviewHover {
                        id: chipHover
                        wsId: parent.wsId
                        label: parent.appIcon !== "" ? parent.appIcon : String(parent.wsId)
                        previewable: parent.winCount > 0
                        onActivated: {
                            var id = parent.wsId
                            Quickshell.execDetached(["sh", "-c", "hyprctl dispatch 'hl.dsp.focus({ workspace = " + id + " })'"])
                        }
                    }
                }
            }
        }

        // Special workspaces: they overlay the numbers while one is being shown.
        // The shown one is filled; the rest are dimmed.
        BarStrip {
            id: specialRow
            anchors.centerIn: parent
            spacing: 4
            opacity: root.inSpecial ? 1 : 0
            enabled: root.inSpecial
            z: 2
            // Same reason as the row above, and this is the one that was
            // doing the damage: it sits on top (z: 2) of the numbers.
            visible: opacity > 0.01
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
                        color: parent.isShown ? Services.Colors.ghost
                            : spHover.containsMouse ? Services.Colors.ghostAlpha(0.38)
                            : Services.Colors.ghostAlpha(0.2)
                        gradient: Services.Prefs.useGradients && (parent.isShown) ? Services.Colors.accentGradient : null
                        Behavior on color { ColorAnimation { duration: 200 } }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: root.specialIcon(parent.shortName)
                        color: parent.isShown ? Services.Colors.abyss : Services.Colors.ash
                        font.pixelSize: 18
                        font.family: "Material Symbols Rounded"
                        z: 1
                        // Handed over to the preview's caption while it is open
                        opacity: Services.AppState.wsPreviewMorphing
                            && Services.AppState.wsPreviewId === parent.modelData.id ? 0 : 1
                        Behavior on opacity { NumberAnimation { duration: 140 } }
                        Behavior on color { ColorAnimation { duration: 200 } }
                    }

                    PreviewHover {
                        id: spHover
                        wsId: parent.modelData.id
                        label: root.specialIcon(parent.shortName)
                        previewable: Hyprland.toplevels.values.filter(
                            t => t.workspace && t.workspace.id === parent.modelData.id).length > 0
                        onActivated: {
                            var n = parent.shortName
                            Quickshell.execDetached(["sh", "-c", "hyprctl dispatch 'hl.dsp.workspace.toggle_special(\"" + n + "\")'"])
                        }
                    }
                }
            }
        }
    }
}
