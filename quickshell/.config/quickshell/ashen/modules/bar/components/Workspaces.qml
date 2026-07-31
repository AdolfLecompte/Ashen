import Quickshell
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts

import "root:/services" as Services

// One pill that turns into the other: entering a special swaps the numbers for
// the specials in place. The swap is staged — content out, box resizes, content
// in — because fading both rows at once left them lying on top of each other,
// which is plain to see now that the pill draws no full box around them.
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
        color: Services.Colors.surfacePill
        border.color: Services.Colors.fillRest
        border.width: 0

        // What the pill is showing right now. It lags `root.inSpecial` on
        // purpose: the swap only lands once the old row is gone, so the two
        // never share the pill for a single frame.
        property bool showSpecial: root.inSpecial
        property real contentOpacity: 1

        readonly property Item shownRow: showSpecial ? specialRow : wsRow
        width: root.vertical ? root.pillH : shownRow.width + root.pad * 2
        height: root.vertical ? shownRow.height + root.pad * 2 : root.pillH
        // The box travels to its new size while it is empty — same order as the
        // media island: box first, content after.
        Behavior on width { NumberAnimation { duration: 220; easing.type: Easing.OutQuint } }
        Behavior on height { NumberAnimation { duration: 220; easing.type: Easing.OutQuint } }

        Connections {
            target: root
            function onInSpecialChanged() { swap.restart() }
        }

        SequentialAnimation {
            id: swap
            NumberAnimation { target: pill; property: "contentOpacity"; to: 0; duration: 120 }
            ScriptAction { script: pill.showSpecial = root.inSpecial }
            // Long enough for the width Behavior above to land.
            PauseAnimation { duration: 180 }
            NumberAnimation { target: pill; property: "contentOpacity"; to: 1; duration: 160 }
        }

        Rectangle {
            id: slideIndicator
            width: root.innerH; height: root.innerH
            radius: root.innerR
            color: Services.Colors.ghost
            gradient: Services.Prefs.useGradients ? Services.Colors.accentGradient : null
            // Part of the numbers, so it leaves and comes back with them.
            opacity: pill.showSpecial ? 0 : pill.contentOpacity
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
            // Only one row is ever alive: `visible` is what keeps the hidden
            // one from catching the pointer meant for the other.
            visible: !pill.showSpecial
            opacity: pill.contentOpacity
            scale: 0.92 + 0.08 * pill.contentOpacity

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
                    // Guarded: the MouseArea is declared further down, so on the
                    // first evaluation the id is not resolved yet and a bare
                    // `.containsMouse` throws.
                    readonly property bool warm: chipHover && chipHover.containsMouse
                    scale: Services.Sizes.hoverScale(warm, chipHover && chipHover.pressed)
                    Behavior on scale { NumberAnimation { duration: Services.Sizes.pillHoverMs; easing.type: Easing.OutCubic } }

                    Rectangle {
                        anchors.fill: parent
                        radius: root.innerR
                        // The plate says whether the workspace has anything on
                        // it, and nothing else. Active chips are carried by the
                        // sliding indicator, so they stay bare. Hover is the
                        // chip growing and its number lifting -- it does not
                        // light up under them.
                        color: Services.Colors.fillRest
                        opacity: parent.isActive ? 0 : parent.hasWindows ? 1 : 0
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
                        color: parent.isActive ? Services.Colors.onColor(Services.Colors.ghost)
                             : parent.warm ? Services.Colors.snow : Services.Colors.ash
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

        // The specials take the pill over while one of them is on screen. The
        // shown one is filled; the rest are dimmed.
        BarStrip {
            id: specialRow
            anchors.centerIn: parent
            spacing: 4
            visible: pill.showSpecial
            opacity: pill.contentOpacity
            scale: 0.92 + 0.08 * pill.contentOpacity

            Repeater {
                model: root.specials

                delegate: Item {
                    required property var modelData
                    readonly property string shortName: modelData.name.replace("special:", "")
                    readonly property bool isShown: modelData.name === root.shownSpecial
                    width: root.innerH; height: root.innerH
                    readonly property bool warm: spHover && spHover.containsMouse
                    scale: Services.Sizes.hoverScale(warm, spHover && spHover.pressed)
                    Behavior on scale { NumberAnimation { duration: Services.Sizes.pillHoverMs; easing.type: Easing.OutCubic } }

                    Rectangle {
                        anchors.fill: parent
                        radius: root.innerR
                        color: parent.isShown ? Services.Colors.ghost : Services.Colors.fillRest
                        gradient: Services.Prefs.useGradients && (parent.isShown) ? Services.Colors.accentGradient : null
                        Behavior on color { ColorAnimation { duration: 200 } }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: root.specialIcon(parent.shortName)
                        color: parent.isShown ? Services.Colors.onColor(Services.Colors.ghost)
                             : parent.warm ? Services.Colors.snow : Services.Colors.ash
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
