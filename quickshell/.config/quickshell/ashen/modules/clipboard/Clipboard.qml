import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import "root:/services" as Services

Scope {
    id: root

    PanelWindow {
        id: win
        anchors { top: true; left: true; right: true; bottom: true }
        screen: Services.Screens.active
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        // stays mapped through the close animation, so the exit plays in reverse
        readonly property bool shown: Services.AppState.clipboardVisible
        visible: shown || closeDelay.running
        onShownChanged: {
            if (!shown) { closeDelay.restart(); return }
            win.refresh()
        }
        Timer { id: closeDelay; interval: 300 }

        WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        property var entries: []
        property string searchText: ""
        property int selectedIndex: 0

        property string activeTab: "Text"
        property var filtered: {
            let list = entries.filter(e => activeTab === "Images" ? e.isImage : !e.isImage)
            if (searchText.length === 0) return list
            let q = searchText.toLowerCase()
            return list.filter(e => e.preview.toLowerCase().includes(q))
        }

        function refresh() {
            listProc.running = true
        }

        Process {
            id: listProc
            command: ["sh", "-c", "cliphist list"]
            running: false
            stdout: StdioCollector {
                onStreamFinished: {
                    let lines = text.split("\n").filter(l => l.length > 0)
                    win.entries = lines.slice(0, 50).map(line => {
                        let tabIdx = line.indexOf("\t")
                        let id = tabIdx >= 0 ? line.substring(0, tabIdx) : line
                        let preview = tabIdx >= 0 ? line.substring(tabIdx + 1) : line
                        let isImg = preview.indexOf("binary data") !== -1
                        return { fullLine: line, id: id, preview: preview, isImage: isImg, thumbPath: "" }
                    })
                    win.selectedIndex = 0
                    win.loadThumbnails()
                }
            }
        }

        Process { id: copyProc; running: false }
        Process { id: deleteProc; running: false }
        Process {
            id: wipeProc
            command: ["sh", "-c", "cliphist wipe"]
            running: false
            onExited: win.refresh()
        }

        Process { id: thumbProc; running: false
            onExited: {
                console.log("[Clipboard] thumbProc termino, ids de imagenes:", JSON.stringify(win.entries.filter(e => e.isImage).map(e => e.id)))
                win.entries = win.entries.map(e => {
                    if (!e.isImage) return e
                    let path = "/tmp/ashen_clip_thumbs/" + e.id + ".png"
                    console.log("[Clipboard] assigning thumbPath for id", e.id, "->", path)
                    return Object.assign({}, e, { thumbPath: path })
                })
                console.log("[Clipboard] entries actualizado, primer thumbPath:", win.entries.length > 0 ? win.entries[0].thumbPath : "ninguno")
            }
        }

        function loadThumbnails() {
            let imageIds = win.entries.filter(e => e.isImage).map(e => e.id)
            if (imageIds.length === 0) return
            let b64ids = Qt.btoa(imageIds.join(" "))
            thumbProc.command = ["sh", "-c",
                "mkdir -p /tmp/ashen_clip_thumbs && for id in $(echo '" + b64ids + "' | base64 -d); do cliphist decode \"$id\" > /tmp/ashen_clip_thumbs/\"$id\".png 2>/dev/null; done"
            ]
            thumbProc.running = true
        }

        function copySelected() {
            if (filtered.length === 0) return
            let e = filtered[Math.min(selectedIndex, filtered.length - 1)]
            let b64id = Qt.btoa(e.id)
            copyProc.command = ["sh", "-c", "echo '" + b64id + "' | base64 -d | cliphist decode | wl-copy"]
            copyProc.running = true
            Services.AppState.clipboardVisible = false
        }

        function deleteEntry(entry) {
            let b64line = Qt.btoa(entry.fullLine)
            deleteProc.command = ["sh", "-c", "echo '" + b64line + "' | base64 -d | cliphist delete"]
            deleteProc.running = true
            win.entries = win.entries.filter(e => e.id !== entry.id)
        }

        function moveSelection(dir) {
            if (filtered.length === 0) return
            selectedIndex = Math.max(0, Math.min(filtered.length - 1, selectedIndex + dir))
            list.positionViewAtIndex(selectedIndex, ListView.Contain)
        }

        MouseArea {
            anchors.fill: parent
            z: -1
            onClicked: Services.AppState.clipboardVisible = false
        }

        Rectangle {
            anchors.centerIn: parent
            width: 900
            height: 580
            radius: 16
            color: Services.Colors.surfaceAlpha(0.96)
            border.color: Services.Colors.ghostAlpha(0.2)
            border.width: 0
            clip: true

            opacity: Services.AppState.clipboardVisible ? 1.0 : 0.0
            scale: Services.AppState.clipboardVisible ? 1.0 : 0.96
            Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
            Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

            MouseArea { anchors.fill: parent; onClicked: {} }

            Column {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 16
                spacing: 12

                // Tabs as one sliding capsule (workspace-style); wipe sits at the end.
                Item {
                    id: tabSelect
                    width: parent.width
                    height: 30
                    property Item activeTabItem: null

                    Rectangle {
                        visible: tabSelect.activeTabItem !== null
                        x: tabSelect.activeTabItem ? tabSelect.activeTabItem.x : 0
                        width: tabSelect.activeTabItem ? tabSelect.activeTabItem.width : 0
                        height: 30
                        radius: 8
                        color: Services.Colors.ghost
                        gradient: Services.Prefs.useGradients ? Services.Colors.accentGradient : null
                        Behavior on x { SmoothedAnimation { duration: 250 } }
                        Behavior on width { SmoothedAnimation { duration: 220 } }
                    }

                    RowLayout {
                        anchors.fill: parent
                        spacing: 8
                        Repeater {
                            model: ["Text", "Images"]
                            delegate: Rectangle {
                                required property string modelData
                                readonly property bool active: win.activeTab === modelData
                                onActiveChanged: if (active) tabSelect.activeTabItem = this
                                Component.onCompleted: if (active) tabSelect.activeTabItem = this
                                Layout.fillWidth: true
                                height: 30
                                radius: 8
                                color: active ? "transparent"
                                    : tabHover.containsMouse ? Services.Colors.ghostAlpha(0.12) : "transparent"
                                Behavior on color { ColorAnimation { duration: 150 } }
                                Text {
                                    anchors.centerIn: parent
                                    text: modelData
                                    color: active ? Services.Colors.abyss : Services.Colors.mist
                                    font.pixelSize: 12
                                    font.bold: true
                                    font.family: "JetBrainsMono NF"
                                }
                                MouseArea {
                                    id: tabHover
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: { win.activeTab = modelData; win.selectedIndex = 0 }
                                }
                            }
                        }
                        Rectangle {
                            Layout.preferredWidth: 30
                            Layout.preferredHeight: 30
                            radius: 8
                            color: wipeHover.containsMouse ? Services.Colors.ghostAlpha(0.15) : "transparent"
                            Behavior on color { ColorAnimation { duration: 150 } }
                            Text {
                                anchors.centerIn: parent
                                text: "\uE16C"
                                color: Services.Colors.ghost
                                font.pixelSize: 18
                                font.family: "Material Symbols Rounded"
                            }
                            MouseArea {
                                id: wipeHover
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                hoverEnabled: true
                                onClicked: wipeProc.running = true
                            }
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 44
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
                        Text { text: "\ue8b6"; color: Services.Colors.ghost; font.pixelSize: 16; font.family: "Material Symbols Rounded" }
                        Item {
                            Layout.fillWidth: true
                            height: 26
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Search clipboard..."
                                color: Services.Colors.ash
                                font.pixelSize: 13
                                font.family: "JetBrainsMono NF"
                                visible: searchField.text.length === 0
                            }
                            TextInput {
                                id: searchField
                                anchors.fill: parent
                                color: Services.Colors.snow
                                font.pixelSize: 13
                                font.family: "JetBrainsMono NF"
                                verticalAlignment: TextInput.AlignVCenter
                                onTextChanged: { win.searchText = text; win.selectedIndex = 0 }
                                Keys.onEscapePressed: Services.AppState.clipboardVisible = false
                                Keys.onReturnPressed: win.copySelected()
                                Keys.onUpPressed: win.moveSelection(-1)
                                Keys.onDownPressed: win.moveSelection(1)
                            }
                        }
                    }
                }

                Text { text: win.filtered.length + " items"; color: Services.Colors.ash; font.pixelSize: 10; font.family: "JetBrainsMono NF" }

                Rectangle {
                    width: parent.width
                    // fills the space the removed title header used to occupy
                    height: 428
                    color: "transparent"
                    clip: true

                    ListView {
                        id: list
                        anchors.fill: parent
                        model: win.filtered
                        spacing: 4

                        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded; width: 4 }

                        delegate: Rectangle {
                            required property var modelData
                            required property int index
                            width: list.width
                            // Image rows are a bit taller to fit the fixed tile;
                            // text rows stay compact.
                            height: modelData.isImage ? 76 : 48
                            radius: 8
                            color: index === win.selectedIndex ? Services.Colors.ghostAlpha(0.2) : Services.Colors.ghostAlpha(0.08)
                            Behavior on color { ColorAnimation { duration: 100 } }

                            RowLayout {
                                visible: !modelData.isImage
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 8
                                spacing: 10

                                Rectangle {
                                    width: 36; height: 36
                                    radius: 6
                                    color: Services.Colors.ghostAlpha(0.15)
                                    clip: true
                                    Image {
                                        anchors.fill: parent
                                        source: modelData.isImage && modelData.thumbPath !== "" ? "file://" + modelData.thumbPath : ""
                                        fillMode: Image.PreserveAspectCrop
                                        visible: modelData.isImage && modelData.thumbPath !== "" && status === Image.Ready
                                        asynchronous: true
                                        cache: false
                                    }
                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData.isImage ? "" : ""
                                        color: Services.Colors.ghost
                                        font.pixelSize: 18
                                        font.family: "Material Symbols Rounded"
                                        visible: !modelData.isImage || modelData.thumbPath === ""
                                    }
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: modelData.preview
                                    color: Services.Colors.snow
                                    font.pixelSize: 11
                                    font.family: "JetBrainsMono NF"
                                    elide: Text.ElideRight
                                }
                                Rectangle {
                                    width: 26; height: 26; radius: 7; color: "transparent"
                                    Text {
                                        anchors.centerIn: parent
                                        text: ""
                                        color: Services.Colors.ash
                                        font.pixelSize: 14
                                        font.family: "Material Symbols Rounded"
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        hoverEnabled: true
                                        onEntered: parent.color = Services.Colors.ghostAlpha(0.2)
                                        onExited: parent.color = "transparent"
                                        onClicked: win.deleteEntry(modelData)
                                    }
                                }
                            }

                            // Image row: fixed rounded tile on the left + the
                            // capture name beside it, like the settings wallpaper card.
                            RowLayout {
                                visible: modelData.isImage
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 8
                                spacing: 12

                                // ClippingRectangle clips children to its rounded shape
                                // (plain `clip` only clips to the square bounds, so the
                                // image corners would poke past the frame).
                                ClippingRectangle {
                                    Layout.preferredWidth: 132
                                    Layout.preferredHeight: 60
                                    radius: 8
                                    color: Services.Colors.ghostAlpha(0.15)
                                    Image {
                                        anchors.fill: parent
                                        source: modelData.thumbPath !== "" ? "file://" + modelData.thumbPath : ""
                                        fillMode: Image.PreserveAspectCrop
                                        visible: modelData.thumbPath !== "" && status === Image.Ready
                                        asynchronous: true
                                        cache: false
                                    }
                                    Text {
                                        anchors.centerIn: parent
                                        text: ""
                                        color: Services.Colors.ghost
                                        font.pixelSize: 22
                                        font.family: "Material Symbols Rounded"
                                        visible: modelData.thumbPath === ""
                                    }
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: modelData.preview
                                    color: Services.Colors.snow
                                    font.pixelSize: 12
                                    font.family: "JetBrainsMono NF"
                                    elide: Text.ElideRight
                                }
                                Rectangle {
                                    Layout.preferredWidth: 26; Layout.preferredHeight: 26; radius: 7
                                    color: delImgMouse.containsMouse ? Services.Colors.ghostAlpha(0.2) : "transparent"
                                    Text {
                                        anchors.centerIn: parent
                                        text: ""
                                        color: Services.Colors.ash
                                        font.pixelSize: 14
                                        font.family: "Material Symbols Rounded"
                                    }
                                    MouseArea {
                                        id: delImgMouse
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        hoverEnabled: true
                                        onClicked: win.deleteEntry(modelData)
                                    }
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                z: -1
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
