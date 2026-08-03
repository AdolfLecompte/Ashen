import Quickshell
import Quickshell.Services.SystemTray
import QtQuick

import "root:/services" as Services

Rectangle {
    id: root
    readonly property bool vertical: Services.Sizes.barVertical
    height: root.vertical ? trayRow.height + 16 : Services.Sizes.pillH
    radius: Services.Sizes.pillR
    color: Services.Colors.surfacePill
    border.color: Services.Colors.fillRest
    border.width: 0
    width: root.vertical ? Services.Sizes.pillH : trayRow.width + 16
    // Hidden from Settings > Bar > Pills
    visible: Services.Prefs.pillVisible("tray") && (SystemTray.items.values.filter(i => !isSystemItem(i.id)).length > 0)

    function isSystemItem(id) {
        let excluded = ["blueman", "nm-applet", "networkmanager", "bluetooth", "pulseaudio", "pipewire"]
        return excluded.some(e => id.toLowerCase().includes(e))
    }

    BarStrip {
        id: trayRow
        anchors.centerIn: parent
        spacing: 6

        Repeater {
            model: SystemTray.items
            delegate: Item {
                required property SystemTrayItem modelData
                width: visible ? 26 : 0
                height: 26
                visible: !root.isSystemItem(modelData.id)

                // A tray icon is somebody else's pixmap: it cannot lift to
                // snow the way a glyph does, so growing is the whole of its
                // hover. No plate behind it -- that was the last of the
                // washes.
                Image {
                    anchors.centerIn: parent
                    source: modelData.icon
                    width: 24; height: 24
                    scale: Services.Sizes.hoverScale(trayHover.containsMouse, trayHover.pressed)
                    Behavior on scale { NumberAnimation { duration: Services.Sizes.pillHoverMs; easing.type: Services.Sizes.easeOut } }
                    // render at 2x and downscale: tray icons ship small pixmaps
                    // and look mushy when Qt upscales them
                    sourceSize: Qt.size(48, 48)
                    smooth: true
                    mipmap: true
                }
                MouseArea {
                    id: trayHover
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onClicked: (mouse) => {
                        let g = parent.mapToGlobal(parent.width / 2, 0)
                        // onlyMenu items have no primary action, so a left click
                        // has to open the menu too or they do nothing at all
                        let wantsMenu = mouse.button === Qt.RightButton || modelData.onlyMenu
                        if (wantsMenu && modelData.hasMenu)
                            Services.AppState.openTrayMenu(modelData, g.x, g.y + parent.height / 2)
                        else if (mouse.button === Qt.LeftButton)
                            modelData.activate()
                    }
                }
            }
        }
    }
}
