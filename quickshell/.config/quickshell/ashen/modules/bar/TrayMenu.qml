import Quickshell
import Quickshell.Wayland
import QtQuick

import "root:/services" as Services

// Renders the DBusMenu a tray app exports (Steam's "Library", "Exit Steam"...)
// with the shell's own styling instead of Quickshell's built-in menu window.
PanelWindow {
    id: root
    anchors { top: true; left: true; right: true; bottom: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    // stay mapped while the close animation plays
    visible: Services.AppState.trayMenuVisible || closeDelay.running

    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    readonly property bool shown: Services.AppState.trayMenuVisible

    Timer {
        id: closeDelay
        interval: 220
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

    Rectangle {
        id: card
        anchors.top: parent.top
        anchors.topMargin: 64
        width: 240
        x: Math.max(12, Math.min(parent.width - width - 12, Services.AppState.trayMenuCenterX - width / 2))
        radius: 14
        height: Math.min(menuCol.implicitHeight + 16, root.height - 80)
        color: Services.Colors.surfaceAlpha(0.95)
        border.color: Services.Colors.ghostAlpha(0.2)
        border.width: 0
        clip: true

        opacity: root.shown ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
        transform: Translate {
            y: root.shown ? 0 : -12
            Behavior on y { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
        }

        MouseArea { anchors.fill: parent; onClicked: {} }

        Column {
            id: menuCol
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 8
            spacing: 2

            Text {
                visible: opener.children.values.length === 0
                text: "No menu"
                color: Services.Colors.ash
                font.pixelSize: 11
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

                    Rectangle {
                        visible: entryCol.modelData.isSeparator
                        width: parent.width
                        height: visible ? 5 : 0
                        color: "transparent"
                        Rectangle {
                            anchors.centerIn: parent
                            width: parent.width - 8
                            height: 1
                            color: Services.Colors.ghostAlpha(0.15)
                        }
                    }

                    Rectangle {
                        id: entryRow
                        visible: !entryCol.modelData.isSeparator
                        width: parent.width
                        height: visible ? 32 : 0
                        radius: 8
                        color: entryMouse.containsMouse && entryCol.modelData.enabled
                               ? Services.Colors.ghostAlpha(0.15) : "transparent"

                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            spacing: 8

                            Image {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: entryCol.modelData.icon !== ""
                                source: entryCol.modelData.icon
                                width: visible ? 16 : 0
                                height: 16
                                sourceSize: Qt.size(32, 32)
                                smooth: true
                            }

                            // check/radio state lives in its own Text: the glyph
                            // needs the symbols font, the label needs the mono one
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: entryCol.modelData.buttonType !== QsMenuButtonType.None
                                width: visible ? 16 : 0
                                text: {
                                    let e = entryCol.modelData
                                    let on = e.checkState === Qt.Checked
                                    if (e.buttonType === QsMenuButtonType.RadioButton)
                                        return on ? "\ue837" : "\ue836"
                                    return on ? "\ue9de" : "\ue835"
                                }
                                color: entryCol.modelData.checkState === Qt.Checked
                                       ? Services.Colors.ghost : Services.Colors.ash
                                font.pixelSize: 14
                                font.family: "Material Symbols Rounded"
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - 40
                                text: entryCol.modelData.text
                                color: entryCol.modelData.enabled ? Services.Colors.snow : Services.Colors.ash
                                font.pixelSize: 12
                                font.family: "JetBrainsMono NF"
                                elide: Text.ElideRight
                            }
                        }

                        Text {
                            anchors.right: parent.right
                            anchors.rightMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            visible: entryCol.modelData.hasChildren
                            text: entryCol.expanded ? "" : ""
                            color: Services.Colors.mist
                            font.pixelSize: 14
                            font.family: "Material Symbols Rounded"
                        }

                        MouseArea {
                            id: entryMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            enabled: entryCol.modelData.enabled
                            onClicked: {
                                if (entryCol.modelData.hasChildren) {
                                    entryCol.expanded = !entryCol.expanded
                                } else {
                                    entryCol.modelData.triggered()
                                    Services.AppState.closeTrayMenu()
                                }
                            }
                        }
                    }

                    QsMenuOpener {
                        id: subOpener
                        menu: entryCol.expanded ? entryCol.modelData : null
                    }

                    Repeater {
                        model: subOpener.children

                        delegate: Rectangle {
                            required property QsMenuEntry modelData
                            width: entryCol.width
                            height: modelData.isSeparator ? 5 : 30
                            radius: 8
                            color: subMouse.containsMouse && modelData.enabled && !modelData.isSeparator
                                   ? Services.Colors.ghostAlpha(0.15) : "transparent"

                            Rectangle {
                                visible: parent.modelData.isSeparator
                                anchors.centerIn: parent
                                width: parent.width - 24
                                height: 1
                                color: Services.Colors.ghostAlpha(0.15)
                            }

                            Text {
                                anchors.left: parent.left
                                anchors.leftMargin: 24
                                anchors.right: parent.right
                                anchors.rightMargin: 8
                                anchors.verticalCenter: parent.verticalCenter
                                visible: !parent.modelData.isSeparator
                                text: parent.modelData.text
                                color: parent.modelData.enabled ? Services.Colors.mist : Services.Colors.ash
                                font.pixelSize: 12
                                font.family: "JetBrainsMono NF"
                                elide: Text.ElideRight
                            }

                            MouseArea {
                                id: subMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                enabled: parent.modelData.enabled && !parent.modelData.isSeparator
                                onClicked: {
                                    parent.modelData.triggered()
                                    Services.AppState.closeTrayMenu()
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
