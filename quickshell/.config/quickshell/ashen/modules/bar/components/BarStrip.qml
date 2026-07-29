import QtQuick

import "root:/services" as Services

// Lays its children along the bar's axis: a row on a horizontal bar, a column
// on a vertical one. Children are positioned, so they must not anchor
// themselves — the alignment properties below centre them on the cross axis.
Grid {
    id: strip

    // A Grid given more columns than it has items reserves one extra spacing at
    // the end, which makes anything centred inside the parent sit off to the
    // left. Ask for exactly as many lanes as there are items instead. Repeaters
    // are children too but never get a cell, so they must not be counted.
    readonly property int lanes: {
        let n = 0
        for (let i = 0; i < children.length; i++) {
            const c = children[i]
            if (c.visible && String(c).indexOf("Repeater") === -1)
                n++
        }
        return Math.max(1, n)
    }

    columns: Services.Sizes.barVertical ? 1 : strip.lanes
    horizontalItemAlignment: Grid.AlignHCenter
    verticalItemAlignment: Grid.AlignVCenter
    spacing: 6
}
