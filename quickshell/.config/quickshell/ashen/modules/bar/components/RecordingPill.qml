import Quickshell
import QtQuick
import "root:/services" as Services

Rectangle {
    id: root
    // Hidden from Settings > Bar > Pills
    visible: Services.Prefs.pillVisible("recording")
    // Subtle hover grow
    scale: hover.containsMouse ? 1.05 : 1.0
    Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

    readonly property bool active: Services.AppState.recording

    // Idle it is a square icon-only pill like the ones on the right; while
    // recording it grows to fit the elapsed time and fills with the accent,
    // the same inversion every other active pill uses (see SystemPill).
    readonly property bool vertical: Services.Sizes.barVertical

    // On a side bar there is no room for the elapsed time, so it stays a square
    // icon pill and only the glyph reports that a recording is running.
    width: (active && !vertical) ? row.width + 20 : Services.Sizes.pillH
    height: Services.Sizes.pillH
    radius: Services.Sizes.pillR
    clip: true
    color: active ? Services.Colors.ghost
                  : (hover.containsMouse ? Services.Colors.ghostAlpha(0.3)
                                         : Services.Colors.surfaceAlpha(0.82))
    gradient: Services.Prefs.useGradients && (active) ? Services.Colors.accentGradient : null
    border.color: active ? Services.Colors.ghost : Services.Colors.ghostAlpha(0.2)
    border.width: 0

    Behavior on width { NumberAnimation { duration: 150 } }
    Behavior on color { ColorAnimation { duration: 200 } }

    property string elapsed: "00:00"

    Timer {
        interval: 1000
        running: root.active
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            let secs = Math.floor((Date.now() - Services.AppState.recordingStartTime) / 1000)
            let m = Math.floor(secs / 60)
            let s = secs % 60
            root.elapsed = (m < 10 ? "0" + m : m) + ":" + (s < 10 ? "0" + s : s)
        }
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 6
        Text {
            text: "\uf679"
            color: (root.active || hover.containsMouse) ? Services.Colors.abyss : Services.Colors.mist
            font.pixelSize: (root.active && !root.vertical) ? 16 : 22
            font.family: "Material Symbols Rounded"
            anchors.verticalCenter: parent.verticalCenter
        }
        Text {
            // no room for a timer on a side bar
            visible: root.active && !root.vertical
            width: visible ? implicitWidth : 0
            text: root.elapsed
            color: Services.Colors.abyss
            font.pixelSize: 12
            font.bold: true
            font.family: "JetBrainsMono NF"
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    MouseArea {
        id: hover
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        hoverEnabled: true
        onClicked: Services.AppState.toggleRecording()
    }
}
