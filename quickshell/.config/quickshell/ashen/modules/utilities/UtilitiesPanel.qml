import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts

import "root:/modules/widgets" as Widgets
import "root:/services" as Services

// The shell's own actions, in one place.
//
// These used to live inside the launcher, reachable only by typing ">" first —
// which meant the launcher was two programs sharing a text field, and the whole
// list was invisible unless you already knew it was there. The launcher is for
// applications now; this is for the shell.
//
// It grows out of the round chip on the utility pill. That chip is the only
// circle on the pill precisely because this is not one more tool: it is the way
// in to all of them.
PanelWindow {
    id: root
    anchors { top: true; left: true; right: true; bottom: true }
    screen: Services.Screens.active
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    visible: Services.AppState.utilitiesVisible || closeDelay.running

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    readonly property bool shown: Services.AppState.utilitiesVisible
    onShownChanged: if (!shown) closeDelay.restart()
    Timer { id: closeDelay; interval: card.closeMs }

    function close() { Services.AppState.utilitiesVisible = false }

    // Three kinds of thing live here and they behave differently, so each says
    // which it is rather than the panel guessing from its name:
    //   panel  — opens something and stands down
    //   toggle — flips a state, and shows that state
    //   act    — does it once, no state to show
    readonly property var actions: [
        { id: "settings",   glyph: "\ue8b8", label: "Settings",      kind: "panel"  },
        { id: "wallpaper",  glyph: "\ue1bc", label: "Wallpaper",     kind: "panel"  },
        { id: "theme",      glyph: "\ue40a", label: "Theme",         kind: "panel"  },
        { id: "clipboard",  glyph: "\ue14f", label: "Clipboard",     kind: "panel"  },
        { id: "processes",  glyph: "\ue322", label: "Processes",     kind: "panel"  },
        { id: "power",      glyph: "\uf8c7", label: "Power",         kind: "panel"  },
        { id: "record",     glyph: "\uf679", label: "Record",        kind: "toggle" },
        { id: "caffeine",   glyph: "\uefef", label: "Keep Awake",    kind: "toggle" },
        { id: "dnd",        glyph: "\uf08f", label: "Do Not Disturb", kind: "toggle" },
        { id: "nightlight", glyph: "\ue51c", label: "Night Light",   kind: "toggle" },
        { id: "lock",       glyph: "\ue899", label: "Lock",          kind: "act"    },
    ]

    // Whether a toggle is currently on. The launcher fired these blind — you
    // had to go and look at the bar to find out whether it had worked.
    function stateOf(id) {
        switch (id) {
            case "record":     return Services.AppState.recording
            case "caffeine":   return Services.AppState.keepAwake
            case "dnd":        return Services.AppState.doNotDisturb
            case "nightlight": return Services.NightLight.enabled
        }
        return false
    }

    function run(a) {
        // A toggle leaves the drawer open, so you can see it flip and throw
        // another one. Anything that opens a panel or acts closes it.
        if (a.kind !== "toggle") root.close()
        switch (a.id) {
            case "settings":   Services.AppState.settingsVisible = true; break
            case "theme":      Services.AppState.settingsTab = "theme"
                               Services.AppState.settingsVisible = true; break
            case "wallpaper":  Services.AppState.wallpaperVisible = true; break
            case "clipboard":  Services.AppState.clipboardVisible = true; break
            case "processes":  Services.AppState.processVisible = true; break
            case "power":      Services.AppState.powerMenuVisible = true; break
            case "lock":       Quickshell.execDetached(["loginctl", "lock-session"]); break
            case "record":     Services.AppState.toggleRecording(); break
            case "caffeine":   Services.AppState.keepAwake = !Services.AppState.keepAwake; break
            case "dnd":        Services.AppState.doNotDisturb = !Services.AppState.doNotDisturb; break
            case "nightlight": Services.NightLight.toggle(); break
        }
    }

    MouseArea {
        anchors.fill: parent
        z: -1
        onClicked: root.close()
    }

    FocusScope {
        anchors.fill: parent
        focus: root.shown
        Keys.onEscapePressed: root.close()
    }

    readonly property string srcEdge: Services.AppState.utilitiesSourceEdge
    readonly property real openXCalc: srcEdge === "left" ? Services.Sizes.panelTop
        : srcEdge === "right" ? root.width - card.openW - Services.Sizes.panelTop
        : (root.width - card.openW) / 2
    readonly property real openYCalc: srcEdge === "top" ? Services.Sizes.panelTop
        : srcEdge === "bottom" ? root.height - card.openH - Math.max(68, Services.Sizes.marginBottom + 18)
        : (root.height - card.openH) / 2

    Widgets.DropCard {
        id: card
        shown: root.shown
        sourceEdge: root.srcEdge
        openXOverride: root.openXCalc
        openYOverride: root.openYCalc

        pillCX: Services.AppState.utilitiesPillCX
        pillCY: Services.AppState.utilitiesPillCY
        pillW: Services.AppState.utilitiesPillW
        pillH: Services.AppState.utilitiesPillH

        readonly property int cols: 3
        readonly property int tileW: 168
        readonly property int tileH: 86
        openW: cols * tileW + (cols - 1) * 12 + 36
        openH: Math.ceil(root.actions.length / cols) * tileH
               + (Math.ceil(root.actions.length / cols) - 1) * 12 + 40 + 12 + 36
        cardRadius: Services.Sizes.panelR

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 18
            spacing: 12

            // No head. The tiles name themselves, and the drawer is
            // reached from a chip that already wears this icon.

            Grid {
                Layout.fillWidth: true
                columns: card.cols
                spacing: 12

                Repeater {
                    model: root.actions

                    delegate: Rectangle {
                        id: tile
                        required property var modelData
                        readonly property bool on: modelData.kind === "toggle"
                                                   && root.stateOf(modelData.id)

                        width: card.tileW
                        height: card.tileH
                        radius: Services.Sizes.cardR
                        color: on ? Services.Colors.ghost
                             : (tileHover.containsMouse ? Services.Colors.fillHover
                                                        : Services.Colors.fillInset)
                        gradient: Services.Prefs.useGradients && on
                            ? Services.Colors.accentGradient : null
                        Behavior on color { ColorAnimation { duration: Services.Sizes.msMicro } }

                        scale: Services.Sizes.hoverScale(tileHover.containsMouse, tileHover.pressed)
                        Behavior on scale { NumberAnimation { duration: Services.Sizes.pillHoverMs; easing.type: Easing.OutCubic } }

                        readonly property color fg: on
                            ? Services.Colors.onColor(Services.Colors.ghost)
                            : (tileHover.containsMouse ? Services.Colors.snow : Services.Colors.mist)

                        Column {
                            anchors.centerIn: parent
                            spacing: 6
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: tile.modelData.glyph
                                color: tile.fg
                                font.pixelSize: 22
                                font.family: "Material Symbols Rounded"
                                Behavior on color { ColorAnimation { duration: Services.Sizes.msMicro } }
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: tile.modelData.label
                                color: tile.fg
                                font.pixelSize: Services.Sizes.fsBody
                                font.bold: true
                                font.family: "JetBrainsMono NF"
                                Behavior on color { ColorAnimation { duration: Services.Sizes.msMicro } }
                            }
                        }

                        // A toggle says which way it is set even when it is off,
                        // so the tile is never ambiguous about having a state.
                        Rectangle {
                            visible: tile.modelData.kind === "toggle"
                            anchors.top: parent.top
                            anchors.right: parent.right
                            anchors.margins: 10
                            width: 6; height: 6
                            radius: 3
                            color: tile.on ? tile.fg : Services.Colors.fillLine
                            Behavior on color { ColorAnimation { duration: Services.Sizes.msMicro } }
                        }

                        MouseArea {
                            id: tileHover
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.run(tile.modelData)
                        }
                    }
                }
            }
        }
    }
}
