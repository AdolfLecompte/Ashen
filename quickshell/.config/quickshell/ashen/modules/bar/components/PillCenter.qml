import QtQuick
import Quickshell

import "root:/services" as Services

// Publishes where a bar pill sits on screen, so the panel that hangs off it can
// line up with it. mapToGlobal has no change signal, so this listens to every
// event that can move the pill instead of polling it several times a second.
Item {
    id: root

    // Key in AppState: "volume", "network", "clock"…
    property string key: ""
    // The pill itself; defaults to whoever holds this reporter
    property Item pill: parent

    visible: false

    // The screen THIS bar is on, asked of its own window rather than taken from
    // Screens.active. With a bar per monitor the two are different things, and
    // reading the focused one would offset a pill against a screen it is not on.
    readonly property var barScreen: QsWindow.window ? QsWindow.window.screen : null

    // mapToGlobal returns window-local coordinates on a layer surface, not
    // screen ones; Sizes owns the correction, since the workspace preview
    // reports its geometry the same way and needs the same sum.
    readonly property real originX: Services.Sizes.barOriginX(root.barScreen)
    readonly property real originY: Services.Sizes.barOriginY(root.barScreen)

    // AppState holds ONE set of numbers per pill, and every panel opens on the
    // focused monitor -- so only the bar on that monitor has anything true to
    // say. Without this the bars overwrite each other every couple of seconds
    // and a panel lands wherever the last one to speak happened to put it.
    readonly property bool speaks: !root.barScreen
        || root.barScreen.name === Services.Screens.activeName

    function report() {
        if (!pill || !key || !root.speaks) return
        const g = pill.mapToGlobal(0, 0)
        Services.AppState.setPillCenter(key,
            root.originX + g.x + pill.width / 2,
            root.originY + g.y + pill.height / 2)
        // Size as well: the drop that falls out of a pill has to start the
        // size of that pill, and the neck has to be as wide as it is.
        Services.AppState.setPillSize(key, pill.width, pill.height)
    }

    Component.onCompleted: report()

    // The pill moves when its own geometry changes…
    Connections {
        target: root.pill
        function onXChanged() { root.report() }
        function onYChanged() { root.report() }
        function onWidthChanged() { root.report() }
        function onHeightChanged() { root.report() }
    }

    // …and when the bar itself moves to another edge or slides out and back
    Connections {
        target: Services.Sizes
        function onBarPositionChanged() { root.report() }
        function onHiddenChanged() { root.report() }
    }

    // Focus moved to this monitor: this bar has just become the one that speaks,
    // and its numbers are whatever the other bar left behind until it says so.
    onSpeaksChanged: if (root.speaks) root.report()

    // Safety net for anything the signals above cannot see (an ancestor moving
    // without resizing). Slow on purpose: this is a backstop, not the source.
    Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: root.report()
    }
}
