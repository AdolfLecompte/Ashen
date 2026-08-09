import QtQuick

import "root:/services" as Services

// Changing section slides in the direction you moved: out towards where you
// came from, in from where you went. Publishes numbers only -- the panel binds
// `offset` and `fade`, and swaps what it shows on `commit`: halfway, while
// nothing is legible.
Item {
    id: root

    // Which section is selected. Set it and the slide runs.
    property int index: 0
    // "horizontal" or "vertical"
    property string axis: "horizontal"
    // How far the content travels on its way out and in.
    property int travel: 26

    property real offset: 0
    property real fade: 1

    // The body should now show `index`.
    signal commit()

    readonly property bool horizontal: axis === "horizontal"
    readonly property real offX: root.horizontal ? root.offset : 0
    readonly property real offY: root.horizontal ? 0 : root.offset

    property int lastIndex: 0
    // Nothing slides on the way in: a body built with its index already set
    // would otherwise play a change that never happened.
    property bool armed: false
    // Off while something places the index itself -- opening a panel on the
    // section that matches the current state is not a change you made.
    property bool animate: true
    Component.onCompleted: { root.lastIndex = root.index; root.armed = true }

    onIndexChanged: {
        if (!root.armed || !root.animate) {
            root.lastIndex = root.index
            root.commit()
            return
        }
        // Which way it moved decides which way it slides.
        const dir = root.index >= root.lastIndex ? 1 : -1
        root.lastIndex = root.index
        swap.stop()
        outAnim.to = -dir * root.travel
        inAnim.from = dir * root.travel
        swap.start()
    }

    SequentialAnimation {
        id: swap
        ParallelAnimation {
            NumberAnimation {
                id: outAnim
                target: root; property: "offset"
                duration: Services.Sizes.msMicro
                easing.type: Services.Sizes.easeIn
            }
            NumberAnimation {
                target: root; property: "fade"; to: 0
                duration: Services.Sizes.msMicro
                easing.type: Services.Sizes.easeIn
            }
        }
        ScriptAction { script: root.commit() }
        ParallelAnimation {
            NumberAnimation {
                id: inAnim
                target: root; property: "offset"; to: 0
                duration: Services.Sizes.msPronounced
                easing.type: Services.Sizes.easeOut
            }
            NumberAnimation {
                target: root; property: "fade"; to: 1
                duration: Services.Sizes.msPronounced
                easing.type: Services.Sizes.easeOut
            }
        }
    }
}
