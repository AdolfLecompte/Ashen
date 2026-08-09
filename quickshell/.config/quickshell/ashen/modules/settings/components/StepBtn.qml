import QtQuick

import "root:/modules/widgets" as Widgets

// The -/+ stepper on the night-light temperature and time rows. Nothing of its
// own any more -- it was a fourth private copy of IconButton. It survives as a
// name because a stepper is the one control that repeats: if press-and-hold
// ever lands, it lands here and not in every button in the shell.
Widgets.IconButton {
    id: sb
    signal clicked()

    size: 28
    onActivated: sb.clicked()
}
