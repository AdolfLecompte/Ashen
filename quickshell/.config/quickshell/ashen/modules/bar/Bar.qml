import Quickshell
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts

import "root:/modules/bar/components"
import "root:/services" as Services

Scope {
    id: root

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: bar
            property var modelData
            screen: modelData

            readonly property bool vertical: Services.Sizes.barVertical
            readonly property int pad: 12
            readonly property string edge: Services.Sizes.barPosition

            // The bar claims one screen edge; which anchors are on decides both
            // where it sits and which way it stretches.
            anchors {
                top: bar.edge !== "bottom"
                bottom: bar.edge !== "top"
                left: bar.edge !== "right"
                right: bar.edge !== "left"
            }
            // Exactly the bar: moving it is a fade now, so there is no travel
            // to leave room for.
            implicitHeight: bar.vertical ? 0 : Services.Sizes.barH
            implicitWidth: bar.vertical ? Services.Sizes.barH : 0

            color: "transparent"
            exclusionMode: ExclusionMode.Normal
            exclusiveZone: Services.Sizes.barH
            // Spelled out rather than `item: content`: a Region bound to an item
            // follows its scene position, and anything that moves the content
            // would drag the input region off the surface.
            mask: Region {
                x: 0; y: 0
                width: bar.width; height: bar.height
            }

            // A row on a horizontal bar, a column on a vertical one. Everything
            // inside a group only has to know its own order, never the edge.
            component BarGroup: Grid {
                columns: bar.vertical ? 1 : 999
                spacing: 6
                horizontalItemAlignment: Grid.AlignHCenter
                verticalItemAlignment: Grid.AlignVCenter
            }

            Item {
                id: content
                // Bar-sized strip pinned to the docked edge of a window that may
                // be deeper than the bar itself while it is moving.
                anchors.fill: parent

                // Moving the bar just hides it: it goes, the edge changes while
                // nothing is on screen, and it comes back. Same duration both
                // ways, so no conditional-duration Behavior reading a stale flag.
                opacity: Services.Sizes.hidden ? 0 : 1
                Behavior on opacity {
                    NumberAnimation { duration: 240; easing.type: Services.Sizes.easeInOut }
                }




                CavaBackground {}

                // ── Layout ──────────────────────────────────────────────
                // Which pill goes where is Prefs.barLayout's business now, so
                // this file no longer names any of them in order. Each id is
                // mapped to the thing that builds it and nothing else here
                // knows what a launcher or a clock is.
                Component { id: cLauncher;      LauncherPill {} }
                Component { id: cNotifications; NotificationPill {} }
                Component { id: cWorkspaces;    Workspaces {} }
                Component { id: cMedia;         MediaPill {} }
                Component { id: cClock;         Clock {} }
                Component { id: cUsb;           USBPill {} }
                Component { id: cRecording;     RecordingPill {} }
                Component { id: cTray;          TrayPill {} }
                Component { id: cSystem;        SystemPill {} }
                Component { id: cPower;         PowerPill {} }
                Component { id: cWindow;        WindowPill {} }

                // What a section actually shows. Almost always just what the
                // layout says -- but a pill you took OFF the bar can still be
                // the only thing that can report a state that is running, and
                // taking a control off is not the same as asking not to be told.
                // It claims a slot for as long as the state lasts and gives it
                // straight back, the way USB comes and goes.
                function pillsIn(section) {
                    const base = Services.Prefs.barPills(section)
                    if (section !== "right") return base
                    if (!Services.AppState.recording) return base
                    if (Services.Prefs.barSectionOf("recording") !== "") return base
                    // Ahead of the power button rather than after it: power is
                    // the end cap of the bar and something arriving behind it
                    // reads as having fallen off the end.
                    const at = base[base.length - 1] === "power" ? base.length - 1
                                                                 : base.length
                    return base.slice(0, at).concat(["recording"], base.slice(at))
                }

                function pillFor(id) {
                    switch (id) {
                    case "launcher":      return cLauncher
                    case "notifications": return cNotifications
                    case "workspaces":    return cWorkspaces
                    case "media":         return cMedia
                    case "clock":         return cClock
                    case "usb":           return cUsb
                    case "recording":     return cRecording
                    case "tray":          return cTray
                    case "system":        return cSystem
                    case "power":         return cPower
                    case "window":        return cWindow
                    }
                    return null
                }

                // A pill arriving swells into place instead of blinking in; a
                // pill leaving is destroyed by the Repeater, so what sells the
                // removal is the `move` transition closing the gap behind it.
                component PillSlot: Item {
                    property string pillId: ""
                    implicitWidth: holder.item ? holder.item.width : 0
                    implicitHeight: holder.item ? holder.item.height : 0

                    Loader {
                        id: holder
                        sourceComponent: content.pillFor(parent.pillId)
                    }

                    scale: 0
                    opacity: 0
                    Component.onCompleted: { scale = 1; opacity = 1 }
                    Behavior on scale { NumberAnimation { duration: Services.Sizes.msPronounced; easing.type: Easing.OutBack; easing.overshoot: Services.Sizes.overshoot } }
                    Behavior on opacity { NumberAnimation { duration: Services.Sizes.msStandard } }
                }

                // ── Left ────────────────────────────────────────────────
                BarGroup {
                    id: startGroup
                    x: bar.vertical ? (parent.width - width) / 2 : bar.pad
                    y: bar.vertical ? bar.pad : (parent.height - height) / 2
                    move: Transition { NumberAnimation { properties: "x,y"; duration: Services.Sizes.msPronounced; easing.type: Services.Sizes.easeOut } }

                    Repeater {
                        model: content.pillsIn("left")
                        delegate: PillSlot { required property var modelData; pillId: modelData }
                    }
                }

                // ── Centre ──────────────────────────────────────────────
                // Pivoted, not simply centred: the anchor pill (the clock, if
                // it is in here) keeps the exact middle of the screen and its
                // neighbours fall either side of it in list order. Centring the
                // group as a block would shove the clock off centre the moment
                // anything joined it.
                BarGroup {
                    id: centreGroup
                    move: Transition { NumberAnimation { properties: "x,y"; duration: Services.Sizes.msPronounced; easing.type: Services.Sizes.easeOut } }

                    property Item anchorItem: null
                    readonly property real anchorMid: anchorItem
                        ? (bar.vertical ? anchorItem.y + anchorItem.height / 2
                                        : anchorItem.x + anchorItem.width / 2)
                        : (bar.vertical ? height / 2 : width / 2)

                    x: bar.vertical ? (parent.width - width) / 2 : parent.width / 2 - anchorMid
                    y: bar.vertical ? parent.height / 2 - anchorMid : (parent.height - height) / 2

                    Repeater {
                        model: content.pillsIn("centre")
                        delegate: PillSlot {
                            required property var modelData
                            pillId: modelData
                            readonly property bool isAnchor: modelData === "clock"
                            onIsAnchorChanged: if (isAnchor) centreGroup.anchorItem = this
                            Component.onCompleted: if (isAnchor) centreGroup.anchorItem = this
                            Component.onDestruction: if (centreGroup.anchorItem === this) centreGroup.anchorItem = null
                        }
                    }
                }

                // ── Right ───────────────────────────────────────────────
                BarGroup {
                    id: endGroup
                    x: bar.vertical ? (parent.width - width) / 2 : parent.width - width - bar.pad
                    y: bar.vertical ? parent.height - height - bar.pad : (parent.height - height) / 2
                    move: Transition { NumberAnimation { properties: "x,y"; duration: Services.Sizes.msPronounced; easing.type: Services.Sizes.easeOut } }

                    Repeater {
                        model: content.pillsIn("right")
                        delegate: PillSlot { required property var modelData; pillId: modelData }
                    }
                }
            }
        }
    }
}
