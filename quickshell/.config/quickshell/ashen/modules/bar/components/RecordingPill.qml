import Quickshell
import QtQuick
import "root:/services" as Services

Rectangle {
    id: root
    // Hidden from Settings > Bar > Pills -- except while a recording is
    // actually running, when Bar.pillsIn() puts it back and it has to agree to
    // be drawn. Off the bar it is a control you chose not to keep; running, it
    // is the only thing that can tell you the machine is still capturing.
    visible: Services.Prefs.pillVisible("recording") || root.active
    // The bar's one hover language, from Sizes: grow under the pointer,
    // give a little under the click.
    scale: Services.Sizes.hoverScale(hover.containsMouse, hover.pressed)
    Behavior on scale { NumberAnimation { duration: Services.Sizes.pillHoverMs; easing.type: Easing.OutCubic } }

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
                  : Services.Colors.surfacePill
    gradient: Services.Prefs.useGradients && (active) ? Services.Colors.accentGradient : null
    border.color: active ? Services.Colors.ghost : Services.Colors.fillRest
    border.width: 0

    // Opening out to fit the clock is the pill telling you it started, so it
    // gets the same settle as the panels rather than a flat 150 ms slide.
    Behavior on width { NumberAnimation { duration: 260; easing.type: Easing.OutQuint } }
    Behavior on color { ColorAnimation { duration: 200 } }

    // Counted in AppState, so the floating indicator shows the same number.
    readonly property string elapsed: Services.AppState.recordingElapsed

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 6
        Text {
            id: dot
            text: "\uf679"
            // Dark only on the solid accent fill; over the hover tint it lifts.
            color: root.active ? Services.Colors.onColor(Services.Colors.ghost)
                 : hover.containsMouse ? Services.Colors.snow : Services.Colors.mist
            font.pixelSize: (root.active && !root.vertical) ? 16 : 22
            font.family: "Material Symbols Rounded"
            anchors.verticalCenter: parent.verticalCenter
            Behavior on color { ColorAnimation { duration: 200 } }
            Behavior on font.pixelSize { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

            // A recording is the one thing on the bar that is still happening
            // while you look away, so the dot breathes for as long as it runs.
            // Scale, not colour: red is not this shell's alarm — the scheme is
            // (see the colour rules), and a pulsing tint would fight the fill.
            transform: Scale {
                id: beat
                origin.x: dot.width / 2
                origin.y: dot.height / 2
            }
            SequentialAnimation {
                running: root.active
                loops: Animation.Infinite
                alwaysRunToEnd: true
                onStopped: { beat.xScale = 1; beat.yScale = 1; dot.opacity = 1 }
                ParallelAnimation {
                    NumberAnimation { target: beat; property: "xScale"; to: 1.18; duration: 620; easing.type: Easing.InOutSine }
                    NumberAnimation { target: beat; property: "yScale"; to: 1.18; duration: 620; easing.type: Easing.InOutSine }
                    NumberAnimation { target: dot; property: "opacity"; to: 0.72; duration: 620; easing.type: Easing.InOutSine }
                }
                ParallelAnimation {
                    NumberAnimation { target: beat; property: "xScale"; to: 1.0; duration: 620; easing.type: Easing.InOutSine }
                    NumberAnimation { target: beat; property: "yScale"; to: 1.0; duration: 620; easing.type: Easing.InOutSine }
                    NumberAnimation { target: dot; property: "opacity"; to: 1.0; duration: 620; easing.type: Easing.InOutSine }
                }
            }
        }
        Text {
            // no room for a timer on a side bar
            visible: root.active && !root.vertical
            width: visible ? implicitWidth : 0
            text: root.elapsed
            color: Services.Colors.onColor(Services.Colors.ghost)
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
