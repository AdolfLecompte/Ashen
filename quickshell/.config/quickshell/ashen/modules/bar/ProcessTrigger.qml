import Quickshell
import Quickshell.Wayland
import QtQuick

import "root:/services" as Services

// Hidden handle at the bottom edge: rest the pointer on the middle of the
// screen bottom for a moment and a small "Process" button peeks out.
PanelWindow {
    id: root
    anchors { bottom: true; left: true; right: true }
    implicitHeight: 62
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    property bool revealed: false

    // Only the strip (or the button, once revealed) takes pointer input, so
    // the rest of the bottom edge keeps working normally.
    // Only the strip (or the button, once revealed) takes pointer input, so
    // the rest of the bottom edge keeps working normally.
    mask: Region {
        item: strip
        Region { item: btn }
    }

    onRevealedChanged: if (!revealed) hideTimer.stop()

    Timer {
        id: peekTimer
        interval: 1000
        onTriggered: {
            root.revealed = true
            // if the pointer never reaches the button, retract on its own
            hideTimer.restart()
        }
    }
    Timer {
        id: hideTimer
        interval: 1600
        onTriggered: if (!Services.AppState.processVisible) root.revealed = false
    }

    // the 4px sliver that arms the reveal
    Item {
        id: strip
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        width: 220
        height: 8

        // MouseArea, not HoverHandler: on a layer surface the handler drops the
        // hover as soon as the pointer settles and the peek never arms
        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
            onEntered: {
                hideTimer.stop()
                if (!root.revealed) peekTimer.restart()
            }
            onExited: {
                peekTimer.stop()
                if (root.revealed) hideTimer.restart()
            }
        }
    }

    Rectangle {
        id: btn
        anchors.bottom: parent.bottom
        anchors.bottomMargin: root.revealed ? 10 : -48
        anchors.horizontalCenter: parent.horizontalCenter
        width: 124
        height: 44
        radius: 10
        color: btnMouse.containsMouse ? Services.Colors.ghostAlpha(0.3)
                                      : Services.Colors.surfaceAlpha(0.92)
        border.color: Services.Colors.ghostAlpha(0.2)
        border.width: 0
        opacity: root.revealed ? 1.0 : 0.0

        Behavior on anchors.bottomMargin { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
        Behavior on color { ColorAnimation { duration: 150 } }

        Row {
            anchors.centerIn: parent
            spacing: 6
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "\ueaa2"
                color: Services.Colors.mist
                font.pixelSize: 20
                font.family: "Material Symbols Rounded"
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "Process"
                color: Services.Colors.snow
                font.pixelSize: 12
                font.family: "JetBrainsMono NF"
            }
        }

        MouseArea {
            id: btnMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onEntered: hideTimer.stop()
            onExited: if (root.revealed) hideTimer.restart()
            onClicked: Services.AppState.toggleOverlay("processVisible")
        }
    }

    // once the panel closes, retract the button as well
    Connections {
        target: Services.AppState
        function onProcessVisibleChanged() {
            if (Services.AppState.processVisible) hideTimer.stop()
            else hideTimer.restart()
        }
    }
}
