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

    // mapToGlobal does NOT return screen coordinates on a layer surface: it
    // returns window-local ones. With the bar on top or on the left the window
    // starts at 0 and the two happen to agree, which is why this went unnoticed
    // -- but on the bottom edge a pill reported y≈28 instead of y≈1052, so its
    // panel grew out of the TOP of the screen, and the right-hand bar had the
    // same fault sideways. The anchoring says where the window starts.
    readonly property real originX: {
        const s = Services.Screens.active
        return (s && Services.Sizes.barPosition === "right") ? s.width - Services.Sizes.barH : 0
    }
    readonly property real originY: {
        const s = Services.Screens.active
        return (s && Services.Sizes.barPosition === "bottom") ? s.height - Services.Sizes.barH : 0
    }

    function report() {
        if (!pill || !key) return
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

    // Safety net for anything the signals above cannot see (an ancestor moving
    // without resizing). Slow on purpose: this is a backstop, not the source.
    Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: root.report()
    }
}
