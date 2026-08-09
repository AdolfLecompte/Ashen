import Quickshell
import QtQuick

// Host for a panel that must not be built during startup: loaded asynchronously
// a moment after the shell is up, and then it stays. Loading on first open
// looked wrong -- the window was created already open, so the grow-out-of-the-
// pill animation had nothing to play and only the fade was left.
Scope {
    id: root

    property bool shown: false
    property Component panel: null
    // Staggered so twenty panels do not all build on the same frame
    property int preloadMs: 1500

    LazyLoader {
        id: loader
        component: root.panel
    }

    Timer {
        interval: root.preloadMs
        running: true
        repeat: false
        onTriggered: loader.loading = true
    }

    // A panel asked for before its turn in the queue is built right away
    onShownChanged: if (shown) loader.loading = true
}
