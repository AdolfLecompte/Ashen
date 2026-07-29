import QtQuick

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

    function report() {
        if (!pill || !key) return
        const g = pill.mapToGlobal(0, 0)
        Services.AppState.setPillCenter(key, g.x + pill.width / 2, g.y + pill.height / 2)
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

    // Safety net for anything the signals above cannot see (an ancestor moving
    // without resizing). Slow on purpose: this is a backstop, not the source.
    Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: root.report()
    }
}
