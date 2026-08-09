import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Controls

import "root:/services" as Services

// Renders the DBusMenu a tray app exports (Steam's "Library", "Exit Steam"…)
// in the shell's own styling instead of Quickshell's built-in menu window.
// The one panel outside the PanelHost family: its origin is a tray icon, whose
// rect only exists at click time, and it has no entry in Pills.
PanelWindow {
    id: root
    anchors { top: true; left: true; right: true; bottom: true }
    screen: Services.Screens.active
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    // stay mapped while the close animation plays
    visible: Services.AppState.trayMenuVisible || closeDelay.running

    // Escape has to reach us, so the keyboard is taken while it is open and
    // handed straight back -- the same deal PowerMenu and Settings make.
    WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    readonly property bool shown: Services.AppState.trayMenuVisible

    Timer {
        id: closeDelay
        interval: Services.Sizes.msPronounced
    }
    onShownChanged: if (!shown) closeDelay.restart()

    QsMenuOpener {
        id: opener
        menu: Services.AppState.trayMenuHandle
    }

    MouseArea {
        anchors.fill: parent
        z: -1
        onClicked: Services.AppState.closeTrayMenu()
    }

    FocusScope {
        anchors.fill: parent
        focus: root.shown
        Keys.onEscapePressed: Services.AppState.closeTrayMenu()
    }

    Rectangle {
        id: card
        width: 240
        x: Services.Sizes.panelX(parent.width, width, Services.AppState.trayMenuCenterX)
        y: Services.Sizes.panelY(parent.height, height, Services.AppState.trayMenuCenterY)
        radius: Services.Sizes.cardR
        // A tray app's menu can be longer than the screen (Steam's is), so the
        // card stops growing and the list scrolls inside it instead of being
        // cut off with no way to reach the rest.
        height: Math.min(menuCol.implicitHeight + 16, root.height - 80)
        color: Services.Colors.surfacePanel
        clip: true

        // Origin-anchored open: grows out of its tray icon + fades, smooth settle.
        property real openAmt: root.shown ? 1.0 : 0.0
        Behavior on openAmt { NumberAnimation { duration: Services.Sizes.msEmphasis; easing.type: Services.Sizes.easeBox } }

        opacity: root.shown ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: Services.Sizes.msStandard; easing.type: Services.Sizes.easeOut } }
        transform: Scale {
            origin.x: Services.Sizes.originX(card.x, card.width, Services.AppState.trayMenuCenterX)
            origin.y: Services.Sizes.originY(card.y, card.height, Services.AppState.trayMenuCenterY)
            xScale: 0.55 + 0.45 * card.openAmt
            yScale: 0.55 + 0.45 * card.openAmt
        }

        MouseArea { anchors.fill: parent; onClicked: {} }

        Flickable {
            anchors.fill: parent
            anchors.margins: 8
            contentHeight: menuCol.implicitHeight
            boundsBehavior: Flickable.StopAtBounds
            interactive: contentHeight > height
            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded; width: 4 }

            Column {
                id: menuCol
                width: parent.width
                spacing: 2

                Text {
                    visible: opener.children.values.length === 0
                    text: "No menu"
                    color: Services.Colors.ash
                    font.pixelSize: Services.Sizes.fsBody
                    font.family: "JetBrainsMono NF"
                    topPadding: 10
                    bottomPadding: 10
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                Repeater {
                    model: opener.children

                    delegate: Column {
                        id: entryCol
                        required property QsMenuEntry modelData
                        width: menuCol.width
                        spacing: 2

                        // submenus expand in place; a second popup would fight the
                        // click-outside handler of this one
                        property bool expanded: false

                        MenuRow {
                            width: parent.width
                            entry: entryCol.modelData
                            expanded: entryCol.expanded
                            onPicked: {
                                if (entryCol.modelData.hasChildren)
                                    entryCol.expanded = !entryCol.expanded
                                else {
                                    entryCol.modelData.triggered()
                                    Services.AppState.closeTrayMenu()
                                }
                            }
                        }

                        QsMenuOpener {
                            id: subOpener
                            menu: entryCol.expanded ? entryCol.modelData : null
                        }

                        Repeater {
                            model: subOpener.children

                            delegate: MenuRow {
                                required property QsMenuEntry modelData
                                width: entryCol.width
                                entry: modelData
                                // Set in from its parent so a run of children
                                // reads as belonging to the row above it.
                                depth: 1
                                onPicked: {
                                    modelData.triggered()
                                    Services.AppState.closeTrayMenu()
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // ── Shared pieces ──────────────────────────────────────────────────────
    // Inline components only parse in the document's root object.

    // One row for both levels. There used to be two of these, and the nested
    // one had quietly lost the icon and the check state: a submenu with
    // checkboxes in it drew none of them.
    component MenuRow: Rectangle {
        id: mrow
        property QsMenuEntry entry: null
        property int depth: 0
        property bool expanded: false

        signal picked()

        readonly property bool sep: entry !== null && entry.isSeparator
        readonly property bool usable: entry !== null && entry.enabled && !sep

        height: sep ? 5 : 32
        radius: Services.Sizes.innerR
        color: mouse.containsMouse && mrow.usable ? Services.Colors.fillLine : "transparent"
        Behavior on color { ColorAnimation { duration: Services.Sizes.msMicro } }

        // A separator is a hairline, not a row: it keeps its own margins so a
        // nested run still lines up with the labels above it.
        Rectangle {
            visible: mrow.sep
            anchors.centerIn: parent
            width: parent.width - 8 - mrow.depth * 16
            height: 1
            color: Services.Colors.fillLine
        }

        Row {
            visible: !mrow.sep
            anchors.fill: parent
            anchors.leftMargin: 8 + mrow.depth * 16
            anchors.rightMargin: 8
            spacing: 8

            Image {
                anchors.verticalCenter: parent.verticalCenter
                visible: mrow.entry !== null && mrow.entry.icon !== ""
                source: mrow.entry !== null ? mrow.entry.icon : ""
                width: visible ? 16 : 0
                height: 16
                sourceSize: Qt.size(32, 32)
                smooth: true
            }

            // check/radio state lives in its own Text: the glyph needs the
            // symbols font, the label needs the mono one
            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: mrow.entry !== null && mrow.entry.buttonType !== QsMenuButtonType.None
                width: visible ? 16 : 0
                text: {
                    if (mrow.entry === null) return ""
                    const on = mrow.entry.checkState === Qt.Checked
                    if (mrow.entry.buttonType === QsMenuButtonType.RadioButton)
                        return on ? "" : ""
                    return on ? "" : ""
                }
                color: mrow.entry !== null && mrow.entry.checkState === Qt.Checked
                       ? Services.Colors.ghost : Services.Colors.ash
                font.pixelSize: 14
                font.family: "Material Symbols Rounded"
            }

            Text {
                id: label
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - (parent.spacing * 2) - 40
                text: mrow.entry !== null ? mrow.entry.text : ""
                // Under the pointer the label lifts, the way every other row in
                // the shell answers a hover.
                color: !mrow.usable ? Services.Colors.ash
                     : (mouse.containsMouse ? Services.Colors.snow
                                            : (mrow.depth > 0 ? Services.Colors.mist
                                                              : Services.Colors.snow))
                font.pixelSize: Services.Sizes.fsBody
                font.family: "JetBrainsMono NF"
                elide: Text.ElideRight
                Behavior on color { ColorAnimation { duration: Services.Sizes.msMicro } }
            }
        }

        // Which way a submenu is about to go
        Text {
            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            visible: mrow.entry !== null && mrow.entry.hasChildren
            text: mrow.expanded ? "" : ""
            color: Services.Colors.mist
            font.pixelSize: 14
            font.family: "Material Symbols Rounded"
        }

        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            enabled: mrow.usable
            onClicked: mrow.picked()
        }
    }
}
