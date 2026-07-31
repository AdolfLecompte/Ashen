import QtQuick

import "root:/modules/widgets" as Widgets

// The -/+ stepper on the night-light temperature and time rows.
//
// Nothing of its own any more: it used to be a fourth private copy of the small
// square button, at its own side, radius and hover opacity. It survives as a
// name because a stepper is the one control that repeats -- if press-and-hold
// ever lands it lands here, not in every button in the shell -- and because its
// eight call sites already say `onClicked`.
Widgets.IconButton {
    id: sb
    signal clicked()

    size: 28
    onActivated: sb.clicked()
}
