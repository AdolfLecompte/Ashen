import Quickshell
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts

import "root:/modules/bar/components"

Scope {
    id: root

    Variants {
        model: Quickshell.screens

        PanelWindow {
            property var modelData
            screen: modelData
            anchors { top: true; left: true; right: true }
            implicitHeight: 56
            color: "transparent"
            exclusionMode: ExclusionMode.Auto

            Item {
                anchors.fill: parent
                CavaBackground {}

                // ── Izquierda ──────────────────────────
                LauncherPill {
                    id: launcherPill
                    anchors.left: parent.left
                    anchors.leftMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                }
                NotificationPill {
                    id: notificationPill
                    anchors.left: launcherPill.right
                    anchors.leftMargin: 6
                    anchors.verticalCenter: parent.verticalCenter
                }
                Workspaces {
                    id: workspaces
                    anchors.left: notificationPill.right
                    anchors.leftMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                }
                MediaPill {
                    anchors.left: workspaces.right
                    anchors.leftMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                }

                // ── Centro ─────────────────────────────
                USBPill {
                    anchors.right: clock.left
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                }
                Clock {
                    id: clock
                    anchors.centerIn: parent
                }
                RecordingPill {
                    anchors.left: clock.right
                    anchors.leftMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                }

                // ── Derecha ────────────────────────────
                Row {
                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6

                    TrayPill {}
                    LocksPill {}
                    SystemPill {}
                    PowerPill {}
                }
            }
        }
    }
}
