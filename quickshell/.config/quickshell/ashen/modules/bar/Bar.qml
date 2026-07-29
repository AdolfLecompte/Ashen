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
            // While moving, the window is deeper than the bar so the content can
            // slide in from outside the screen edge instead of being clipped
            // (which read as a fade-in on top of the edge). The reserved space
            // stays at the bar's own thickness the whole time.
            readonly property int slack: Services.Sizes.barH + 24
            implicitHeight: bar.vertical ? 0 : Services.Sizes.barH + slack
            implicitWidth: bar.vertical ? Services.Sizes.barH + slack : 0

            color: "transparent"
            exclusionMode: ExclusionMode.Normal
            exclusiveZone: Services.Sizes.barH
            // Only the bar strip takes clicks; the slack is see-through.
            // Spelled out instead of `item: content` on purpose: a Region bound
            // to an item follows its *scene* position, so the slide-out Translate
            // below drags the input region off the surface and the compositor
            // clips it to nothing — the bar keeps drawing but stops taking
            // clicks after every move. These are the strip's resting bounds.
            mask: Region {
                x: bar.vertical ? (bar.edge === "left" ? 0 : bar.width - Services.Sizes.barH) : 0
                y: bar.vertical ? 0 : (bar.edge === "top" ? 0 : bar.height - Services.Sizes.barH)
                width: bar.vertical ? Services.Sizes.barH : bar.width
                height: bar.vertical ? bar.height : Services.Sizes.barH
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
                width: bar.vertical ? Services.Sizes.barH : bar.width
                height: bar.vertical ? bar.height : Services.Sizes.barH
                x: bar.vertical ? (bar.edge === "left" ? 0 : bar.width - width) : 0
                y: bar.vertical ? 0 : (bar.edge === "top" ? 0 : bar.height - height)

                // Moving the bar slides it out into the edge it is leaving and
                // back in from the new one; Sizes only swaps the applied edge
                // while this is all the way out.
                property real slide: Services.Sizes.hidden ? 1 : 0
                // Leaves quickly and arrives with a settle, so a move between two
                // edges of the same axis still reads as a move and not a jump.
                Behavior on slide {
                    NumberAnimation { duration: 700; easing.type: Easing.InOutCubic }
                }
                opacity: 1 - content.slide
                transform: Translate {
                    x: bar.vertical ? (bar.edge === "left" ? -content.slide * (Services.Sizes.barH + 16)
                                                           : content.slide * (Services.Sizes.barH + 16)) : 0
                    y: bar.vertical ? 0 : (bar.edge === "top" ? -content.slide * (Services.Sizes.barH + 16)
                                                              : content.slide * (Services.Sizes.barH + 16))
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
                Component { id: cLocks;         LocksPill {} }
                Component { id: cUsb;           USBPill {} }
                Component { id: cRecording;     RecordingPill {} }
                Component { id: cTray;          TrayPill {} }
                Component { id: cSystem;        SystemPill {} }
                Component { id: cPower;         PowerPill {} }

                function pillFor(id) {
                    switch (id) {
                    case "launcher":      return cLauncher
                    case "notifications": return cNotifications
                    case "workspaces":    return cWorkspaces
                    case "media":         return cMedia
                    case "clock":         return cClock
                    case "locks":         return cLocks
                    case "usb":           return cUsb
                    case "recording":     return cRecording
                    case "tray":          return cTray
                    case "system":        return cSystem
                    case "power":         return cPower
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
                    Behavior on scale { NumberAnimation { duration: 260; easing.type: Easing.OutBack; easing.overshoot: 1.1 } }
                    Behavior on opacity { NumberAnimation { duration: 200 } }
                }

                // ── Left ────────────────────────────────────────────────
                BarGroup {
                    id: startGroup
                    x: bar.vertical ? (parent.width - width) / 2 : bar.pad
                    y: bar.vertical ? bar.pad : (parent.height - height) / 2
                    move: Transition { NumberAnimation { properties: "x,y"; duration: 240; easing.type: Easing.OutCubic } }

                    Repeater {
                        model: Services.Prefs.barPills("left")
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
                    move: Transition { NumberAnimation { properties: "x,y"; duration: 240; easing.type: Easing.OutCubic } }

                    property Item anchorItem: null
                    readonly property real anchorMid: anchorItem
                        ? (bar.vertical ? anchorItem.y + anchorItem.height / 2
                                        : anchorItem.x + anchorItem.width / 2)
                        : (bar.vertical ? height / 2 : width / 2)

                    x: bar.vertical ? (parent.width - width) / 2 : parent.width / 2 - anchorMid
                    y: bar.vertical ? parent.height / 2 - anchorMid : (parent.height - height) / 2

                    Repeater {
                        model: Services.Prefs.barPills("centre")
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
                    move: Transition { NumberAnimation { properties: "x,y"; duration: 240; easing.type: Easing.OutCubic } }

                    Repeater {
                        model: Services.Prefs.barPills("right")
                        delegate: PillSlot { required property var modelData; pillId: modelData }
                    }
                }
            }
        }
    }
}
