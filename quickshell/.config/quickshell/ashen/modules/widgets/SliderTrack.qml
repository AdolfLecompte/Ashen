import Quickshell
import QtQuick
import "root:/services" as Services

// The one slider in the shell: settings rows, the volume pill, the mic pill and
// the brightness pill all use this, so drag behaviour cannot drift between them.
//
// Three things it has to get right, all of which were wrong somewhere before:
//   1. Writing on every mouse event spawns ~60-120 processes/sec while dragging.
//      Coalesced to one write per `writeInterval` (leading edge + trailing).
//   2. The services poll (Audio 1s, Brightness 1.5s), so following `value`
//      directly makes the knob crawl a second behind the cursor. While dragging
//      the local position wins.
//   3. Dropping the local value the instant the mouse is released snaps the knob
//      back to the stale poll. It is held until the service agrees (or times out).
Item {
    id: root

    // 0..1, authoritative, from the service
    property real value: 0
    // 0..1, what is actually painted (local while dragging/holding)
    readonly property real shown: (dragging || holding) ? localRatio : Math.max(0, Math.min(1, value))

    property int knobSize: 16
    property int knobBorder: 2
    property color knobBorderColor: Services.Colors.ghost
    // The mic slider turns red when muted
    property color fillColor: Services.Colors.ghost
    property int trackHeight: 10
    // extra grab area around the track, so it is not a 10px-tall target
    property int hitMargin: 8
    property bool dimmed: false
    property int writeInterval: 45

    signal moved(real ratio)

    readonly property bool dragging: dragArea.pressed
    property bool holding: false
    property real localRatio: 0
    property bool queued: false

    implicitHeight: trackHeight

    onValueChanged: if (holding && Math.abs(value - localRatio) <= 0.03) holding = false
    Timer { id: holdTimeout; interval: 1600; onTriggered: root.holding = false }

    function push(r) {
        if (r === root.localRatio && throttle.running) return
        root.localRatio = r
        if (throttle.running) { root.queued = true; return }
        root.moved(r)
        throttle.restart()
    }
    Timer {
        id: throttle
        interval: root.writeInterval
        onTriggered: {
            if (!root.queued) return
            root.queued = false
            root.moved(root.localRatio)
            throttle.restart()
        }
    }

    Rectangle {
        id: track
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: root.trackHeight
        radius: height / 2
        color: Services.Colors.ghostAlpha(0.15)
        opacity: root.dimmed ? 0.4 : 1.0

        Rectangle {
            id: fill
            anchors.left: parent.left
            height: parent.height
            radius: parent.radius
            color: root.fillColor
            Behavior on color { ColorAnimation { duration: Services.Sizes.msMicro } }
            width: track.width * root.shown
            // Easing is for changes coming from elsewhere (keys, OSD); while
            // dragging it is just lag between cursor and knob.
            Behavior on width {
                enabled: !root.dragging
                NumberAnimation { duration: Services.Sizes.msMicro }
            }
        }

        Rectangle {
            width: root.knobSize; height: root.knobSize
            radius: width / 2
            color: Services.Colors.snow
            border.color: root.knobBorderColor
            border.width: root.knobBorder
            anchors.verticalCenter: parent.verticalCenter
            x: Math.max(0, Math.min(track.width - width, fill.width - width / 2))
            Behavior on x {
                enabled: !root.dragging
                NumberAnimation { duration: Services.Sizes.msMicro }
            }
        }
    }

    MouseArea {
        id: dragArea
        anchors.fill: track
        anchors.topMargin: -root.hitMargin
        anchors.bottomMargin: -root.hitMargin
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        function ratioAt(mx) { return Math.max(0, Math.min(1, mx / track.width)) }

        onPressed: mouse => {
            root.holding = true
            root.push(ratioAt(mouse.x))
        }
        onPositionChanged: mouse => { if (pressed) root.push(ratioAt(mouse.x)) }
        onReleased: mouse => {
            // Write the final position explicitly: the last move may have been
            // swallowed by the throttle, which would leave it slightly off.
            let r = ratioAt(mouse.x)
            root.localRatio = r
            root.queued = false
            root.moved(r)
            holdTimeout.restart()
        }
        onCanceled: holdTimeout.restart()
    }
}
