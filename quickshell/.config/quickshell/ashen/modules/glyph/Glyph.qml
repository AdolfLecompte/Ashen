import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import "root:/services" as Services

Scope {
    id: root

    IpcHandler {
        target: "glyph"
        function toggle() {
            Services.AppState.toggleOverlay("glyphVisible")
            if (Services.AppState.glyphVisible) {
                searchField.text = ""
                searchField.forceActiveFocus()
                if (win.nerdFontIcons.length === 0) nerdFontLoader.running = true
                if (win.materialIcons.length === 0) materialLoader.running = true
            }
        }
    }

    PanelWindow {
        id: win
        anchors { top: true; left: true; right: true; bottom: true }
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        visible: Services.AppState.glyphVisible

        WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        property string searchText: ""
        property string activeTab: "Nerd Font"
        property int selectedIndex: 0
        property bool copied: false
        property var materialIcons: []

        property var nerdFontIcons: []

        Process {
            id: nerdFontLoader
            command: ["sh", "-c", "cat /home/adolf-arch/ashen/quickshell/.config/quickshell/ashen/modules/glyph/data/nerd_font_icons.txt"]
            running: false
            stdout: StdioCollector {
                onStreamFinished: {
                    let lines = text.trim().split("\n")
                    let list = []
                    for (let line of lines) {
                        let parts = line.trim().split(/\s+/)
                        if (parts.length === 2) list.push({ name: parts[0], code: parts[1] })
                    }
                    win.nerdFontIcons = list
                }
            }
        }

        Process {
            id: materialLoader
            command: ["sh", "-c", "cat /home/adolf-arch/ashen/quickshell/.config/quickshell/ashen/modules/glyph/data/material_symbols.txt"]
            running: false
            stdout: StdioCollector {
                onStreamFinished: {
                    let lines = text.trim().split("\n")
                    let list = []
                    for (let line of lines) {
                        let parts = line.trim().split(/\s+/)
                        if (parts.length === 2) list.push({ name: parts[0], code: parts[1] })
                    }
                    win.materialIcons = list
                }
            }
        }

        property var currentList: activeTab === "Nerd Font" ? nerdFontIcons : materialIcons
        property var filtered: {
            let list = currentList
            if (searchText.length > 0) {
                let q = searchText.toLowerCase()
                list = list.filter(i => i.name.toLowerCase().includes(q))
            }
            return list
        }

        function codeToChar(code) {
            let n = parseInt(code, 16)
            if (n > 0xFFFF) {
                // par sustituto para puntos de codigo fuera del BMP (ej. Material Icons nuevos)
                n -= 0x10000
                let hi = 0xD800 + (n >> 10)
                let lo = 0xDC00 + (n & 0x3FF)
                return String.fromCharCode(hi, lo)
            }
            return String.fromCharCode(n)
        }

        function moveSelection(dir) {
            if (filtered.length === 0) return
            selectedIndex = Math.max(0, Math.min(filtered.length - 1, selectedIndex + dir))
            grid.positionViewAtIndex(selectedIndex, GridView.Contain)
        }
        function copySelected() {
            if (filtered.length === 0) return
            let g = filtered[Math.min(selectedIndex, filtered.length - 1)]
            let ch = win.codeToChar(g.code)
            copyProc.command = ["sh", "-c", "printf '%s' '" + ch + "' | wl-copy"]
            copyProc.running = true
            win.copied = true
            copiedTimer.restart()
        }

        Process { id: copyProc; running: false }
        Timer { id: copiedTimer; interval: 900; onTriggered: win.copied = false }

        MouseArea {
            anchors.fill: parent
            z: -1
            onClicked: Services.AppState.glyphVisible = false
        }

        Rectangle {
            anchors.centerIn: parent
            width: 560
            height: 480
            radius: 16
            color: Services.Colors.surfaceAlpha(0.96)
            border.color: Services.Colors.ghostAlpha(0.2)
            border.width: 1
            clip: true

            opacity: Services.AppState.glyphVisible ? 1.0 : 0.0
            scale: Services.AppState.glyphVisible ? 1.0 : 0.96
            Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
            Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

            MouseArea { anchors.fill: parent; onClicked: {} }

            Column {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 16
                spacing: 12

                RowLayout {
                    width: parent.width
                    spacing: 8
                    Repeater {
                        model: ["Nerd Font", "Material Icon"]
                        delegate: Rectangle {
                            required property string modelData
                            height: 32
                            Layout.fillWidth: true
                            radius: 8
                            color: win.activeTab === modelData ? Services.Colors.ghost : Services.Colors.ghostAlpha(0.15)
                            Behavior on color { ColorAnimation { duration: 150 } }
                            Text {
                                anchors.centerIn: parent
                                text: modelData
                                color: win.activeTab === modelData ? Services.Colors.abyss : Services.Colors.mist
                                font.pixelSize: 12
                                font.bold: true
                                font.family: "JetBrainsMono NF"
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    win.activeTab = modelData
                                    win.selectedIndex = 0
                                    if (modelData === "Material Icon" && win.materialIcons.length === 0) materialLoader.running = true
                                }
                            }
                        }
                    }
                }

                RowLayout {
                    width: parent.width
                    Rectangle {
                        Layout.fillWidth: true
                        height: 48
                        radius: 10
                        color: Services.Colors.ghostAlpha(0.1)
                        border.color: searchField.activeFocus ? Services.Colors.ghost : Services.Colors.ghostAlpha(0.2)
                        border.width: 1
                        Behavior on border.color { ColorAnimation { duration: 150 } }
                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 14
                            anchors.rightMargin: 14
                            spacing: 10
                            Text { text: "\ue8b6"; color: Services.Colors.ghost; font.pixelSize: 18; font.family: "Material Symbols Rounded" }
                            Item {
                                Layout.fillWidth: true
                                height: 28
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "Search icon name..."
                                    color: Services.Colors.ash
                                    font.pixelSize: 14
                                    font.family: "JetBrainsMono NF"
                                    visible: searchField.text.length === 0
                                }
                                TextInput {
                                    id: searchField
                                    anchors.fill: parent
                                    color: Services.Colors.snow
                                    font.pixelSize: 14
                                    font.family: "JetBrainsMono NF"
                                    verticalAlignment: TextInput.AlignVCenter
                                    onTextChanged: { win.searchText = text; win.selectedIndex = 0 }
                                    Keys.onEscapePressed: Services.AppState.glyphVisible = false
                                    Keys.onReturnPressed: win.copySelected()
                                    Keys.onUpPressed: win.moveSelection(-8)
                                    Keys.onDownPressed: win.moveSelection(8)
                                    Keys.onLeftPressed: win.moveSelection(-1)
                                    Keys.onRightPressed: win.moveSelection(1)
                                }
                            }
                        }
                    }
                    Text {
                        text: win.copied ? "Copied!" : ""
                        color: Services.Colors.ghost
                        font.pixelSize: 12
                        font.family: "JetBrainsMono NF"
                        Layout.leftMargin: 8
                    }
                }

                Text {
                    text: win.filtered.length + " icons"
                    color: Services.Colors.ash
                    font.pixelSize: 10
                    font.family: "JetBrainsMono NF"
                }

                Rectangle {
                    width: parent.width
                    height: 320
                    color: "transparent"
                    clip: true

                    GridView {
                        id: grid
                        anchors.fill: parent
                        model: win.filtered
                        cellWidth: parent.width / 7
                        cellHeight: 64

                        ScrollBar.vertical: ScrollBar {
                            policy: grid.contentHeight > grid.height ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
                            width: 4
                        }

                        delegate: Rectangle {
                            required property var modelData
                            required property int index
                            width: grid.cellWidth - 4
                            height: grid.cellHeight - 4
                            radius: 8
                            color: index === win.selectedIndex ? Services.Colors.ghostAlpha(0.25) : "transparent"
                            border.color: index === win.selectedIndex ? Services.Colors.ghostAlpha(0.4) : "transparent"
                            border.width: 1

                            Column {
                                anchors.centerIn: parent
                                spacing: 2
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: win.codeToChar(modelData.code)
                                    font.pixelSize: 22
                                    font.family: win.activeTab === "Nerd Font" ? "JetBrainsMono NF" : "Material Symbols Rounded"
                                    color: Services.Colors.snow
                                }
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                hoverEnabled: true
                                onEntered: win.selectedIndex = index
                                onClicked: win.copySelected()
                            }
                        }
                    }
                }
            }
        }
    }
}
