import Quickshell
import Quickshell.Services.SystemTray
import QtQuick

import "root:/services" as Services

Rectangle {
    id: root
    height: 44
    radius: 10
    color: Services.Colors.surfaceAlpha(0.82)
    border.color: Services.Colors.ghostAlpha(0.2)
    border.width: 1
    width: trayRow.width + 16
    visible: SystemTray.items.values.filter(i => !isSystemItem(i.id)).length > 0

    function isSystemItem(id) {
        let excluded = ["blueman", "nm-applet", "networkmanager", "bluetooth", "pulseaudio", "pipewire"]
        return excluded.some(e => id.toLowerCase().includes(e))
    }

    Row {
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

                Image {
                    anchors.centerIn: parent
                    source: modelData.icon
                    width: 24; height: 24
                    // render at 2x and downscale: tray icons ship small pixmaps
                    // and look mushy when Qt upscales them
                    sourceSize: Qt.size(48, 48)
                    smooth: true
                    mipmap: true
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onClicked: (mouse) => {
                        let g = parent.mapToGlobal(parent.width / 2, 0)
                        // onlyMenu items have no primary action, so a left click
                        // has to open the menu too or they do nothing at all
                        let wantsMenu = mouse.button === Qt.RightButton || modelData.onlyMenu
                        if (wantsMenu && modelData.hasMenu)
                            Services.AppState.openTrayMenu(modelData, g.x)
                        else if (mouse.button === Qt.LeftButton)
                            modelData.activate()
                    }
                }
            }
        }
    }
}
