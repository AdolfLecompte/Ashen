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
            exclusionMode: ExclusionMode.Exclusive

            Item {
                anchors.fill: parent
                CavaBackground {}

                // ── Izquierda ──────────────────────────
                Workspaces {
                    id: workspaces
                    anchors.left: parent.left
                    anchors.leftMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                }
                MediaPill {
                    anchors.left: workspaces.right
                    anchors.leftMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                }

                // ── Centro ─────────────────────────────
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
