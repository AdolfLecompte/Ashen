import Quickshell
import QtQuick
import "root:/services" as Services

// The one slider in the shell, so drag behaviour cannot drift between
// callers. Three things it has to get right: coalesce writes to one per
// `writeInterval`, let the local position win while dragging, and hold it
// after release until the service agrees.
Item {
    id: root

    // 0..1, authoritative, from the service
    property real value: 0
    // 0..1, what is actually painted (local while dragging/holding)
    readonly property real shown: (dragging || holding) ? localRatio : Math.max(0, Math.min(1, value))

    // No knob: the filled part of the track already says where the value is,
    // and a dot riding on it was a second thing saying the same. `hitMargin`
    // below is what makes the bar easy to grab.
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
            // dragging it is just lag between the cursor and the bar.
            Behavior on width {
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
