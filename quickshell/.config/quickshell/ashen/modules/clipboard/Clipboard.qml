import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import "root:/modules/widgets" as Widgets
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
            focusArm.restart()
        }
        Timer { id: closeDelay; interval: card.closeMs }
        // The surface is not on screen the frame the flag flips, and focusing a
        // field on an unmapped window does nothing.
        Timer {
            id: focusArm
            interval: Services.Sizes.panelArmMs + 40
            onTriggered: searchField.forceActiveFocus()
        }

        WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        property var entries: []
        property string searchText: ""
        property int selectedIndex: 0

        property string activeTab: "Text"
        readonly property int imageCount: entries.filter(e => e.isImage).length
        readonly property int textCount: entries.length - imageCount
        readonly property bool onImages: activeTab === "Images"
        // The grid lays images three across, so up/down has to jump a row.
        readonly property int gridCols: 3

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

        Process {
            id: thumbProc
            running: false
            onExited: {
                win.entries = win.entries.map(e => {
                    if (!e.isImage) return e
                    return Object.assign({}, e, { thumbPath: "/tmp/ashen_clip_thumbs/" + e.id + ".png" })
                })
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
            if (win.onImages) imageGrid.positionViewAtIndex(selectedIndex, GridView.Contain)
            else textList.positionViewAtIndex(selectedIndex, ListView.Contain)
        }

        function setTab(name) {
            if (win.activeTab === name) return
            win.activeTab = name
            win.selectedIndex = 0
            listFade.restart()
        }
        // Same cross-fade the Settings sections use: text and images are
        // different shapes, and cutting between them read as a flinch.
        property real listOpacity: 1
        NumberAnimation {
            id: listFade
            target: win; property: "listOpacity"
            from: 0.0; to: 1.0
            duration: Services.Sizes.msStandard
            easing.type: Easing.OutCubic
        }

        MouseArea {
            anchors.fill: parent
            z: -1
            onClicked: Services.AppState.clipboardVisible = false
        }

        // Same drop as Process and the bar's own panels: it grows out of the
        // clipboard chip on the utility pill, which can be on any of the three
        // edges the bar is not using.
        // Live from the pill, not a value written when something was clicked:
    // a keybind never clicks, and the panel used to grow from wherever the
    // last click had left the numbers.
    readonly property var chip: Services.AppState.utilChipOf(win.srcEdge, "clipboard")
    readonly property string srcEdge: Services.AppState.clipboardSourceEdge
        readonly property real openXCalc: srcEdge === "left" ? Services.Sizes.panelTop
            : srcEdge === "right" ? win.width - card.openW - Services.Sizes.panelTop
            : (win.width - card.openW) / 2
        readonly property real openYCalc: srcEdge === "top" ? Services.Sizes.panelTop
            : srcEdge === "bottom" ? win.height - card.openH - Math.max(68, Services.Sizes.marginBottom + 18)
            : (win.height - card.openH) / 2

        Widgets.DropCard {
            id: card
            shown: win.shown
            sourceEdge: win.srcEdge
            openXOverride: win.openXCalc
            openYOverride: win.openYCalc

            pillCX: (win.chip ? win.chip.cx : 0)
            pillCY: (win.chip ? win.chip.cy : 0)
            pillW: (win.chip ? win.chip.w : 44)
            pillH: (win.chip ? win.chip.h : 44)
            // The chip is icon-only, so the icon is the only piece with
            // anywhere to travel from.

            openW: Math.min(980, win.width - 80)
            openH: Math.min(560, win.height - 120)
            cardRadius: 22

            // Sections of one panel: a single accent that TRAVELS between
            // them, no box per row. See docs/DESIGN.md.
            component TabRow: Item {
                id: tab
                property string name: ""
                property string glyph: ""
                property int count: 0
                readonly property bool active: win.activeTab === tab.name
                readonly property color fg: active
                    ? Services.Colors.onColor(Services.Colors.ghost)
                    : (tabHover.containsMouse ? Services.Colors.snow : Services.Colors.mist)

                height: 38

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 10
                    Text {
                        text: tab.glyph
                        color: tab.fg
                        font.pixelSize: 16
                        font.family: "Material Symbols Rounded"
                        Behavior on color { ColorAnimation { duration: Services.Sizes.msMicro } }
                    }
                    Text {
                        text: tab.name
                        color: tab.fg
                        font.pixelSize: Services.Sizes.fsBody
                        font.bold: true
                        font.family: "JetBrainsMono NF"
                        Layout.fillWidth: true
                        Behavior on color { ColorAnimation { duration: Services.Sizes.msMicro } }
                    }
                    Text {
                        text: tab.count
                        color: tab.fg
                        opacity: 0.7
                        font.pixelSize: 11
                        font.family: "JetBrainsMono NF"
                        Behavior on color { ColorAnimation { duration: Services.Sizes.msMicro } }
                    }
                }

                MouseArea {
                    id: tabHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: win.setTab(tab.name)
                }
            }

            RowLayout {
                anchors.fill: parent
                anchors.margins: 18
                spacing: 16

                // ── Left: what you are looking at ──────────────────
                ColumnLayout {
                    Layout.fillWidth: false
                    Layout.preferredWidth: 200
                    Layout.fillHeight: true
                    spacing: 12

                    // The travelling accent sits behind whichever tab is on.
                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 38 * 2 + 2

                        Rectangle {
                            width: parent.width
                            height: 38
                            radius: Services.Sizes.innerR
                            color: Services.Colors.ghost
                            gradient: Services.Prefs.useGradients ? Services.Colors.accentGradient : null
                            y: win.onImages ? 40 : 0
                            Behavior on y { SmoothedAnimation { duration: 260 } }
                        }

                        Column {
                            anchors.fill: parent
                            spacing: 2
                            TabRow {
                                width: parent.width
                                name: "Text"
                                glyph: "\ue14d"
                                count: win.textCount
                            }
                            TabRow {
                                width: parent.width
                                name: "Images"
                                glyph: "\ue3f4"
                                count: win.imageCount
                            }
                        }
                    }

                    Item { Layout.fillHeight: true }

                    // Wipe: a named button down here rather than a bare icon
                    // wedged into the tab row, where nothing said what it did.
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 38
                        radius: 12
                        color: wipeHover.containsMouse ? Services.Colors.ghostAlpha(0.22)
                                                       : Services.Colors.ghostAlpha(0.06)
                        Behavior on color { ColorAnimation { duration: 150 } }

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 8
                            Text {
                                text: "\ue0b8"
                                color: wipeHover.containsMouse ? Services.Colors.snow : Services.Colors.mist
                                font.pixelSize: 16
                                font.family: "Material Symbols Rounded"
                                Behavior on color { ColorAnimation { duration: 150 } }
                            }
                            Text {
                                text: "Clear all"
                                color: wipeHover.containsMouse ? Services.Colors.snow : Services.Colors.mist
                                font.pixelSize: 11
                                font.bold: true
                                font.family: "JetBrainsMono NF"
                                Behavior on color { ColorAnimation { duration: 150 } }
                            }
                        }

                        MouseArea {
                            id: wipeHover
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: wipeProc.running = true
                        }
                    }
                }

                // ── Right: the entries themselves ──────────────────
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 12

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: false
                        Layout.preferredHeight: 42
                        radius: 12
                        color: Services.Colors.ghostAlpha(0.1)
                        // A resting outline is decoration; only focus earns one.
                        border.color: Services.Colors.ghost
                        border.width: searchField.activeFocus ? 1 : 0
                        Behavior on border.color { ColorAnimation { duration: 150 } }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 14
                            anchors.rightMargin: 14
                            spacing: 10
                            Text {
                                text: "\ue8b6"
                                color: Services.Colors.ghost
                                font.pixelSize: 16
                                font.family: "Material Symbols Rounded"
                            }
                            Item {
                                Layout.fillWidth: true
                                height: 26
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: win.onImages ? "Search captures..." : "Search clipboard..."
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
                                    // On the grid the arrows have to move by a
                                    // row, not by one tile, or the selection
                                    // crawls sideways through the whole page.
                                    Keys.onUpPressed: win.moveSelection(win.onImages ? -win.gridCols : -1)
                                    Keys.onDownPressed: win.moveSelection(win.onImages ? win.gridCols : 1)
                                    Keys.onLeftPressed: if (win.onImages) win.moveSelection(-1)
                                    Keys.onRightPressed: if (win.onImages) win.moveSelection(1)
                                }
                            }
                            Text {
                                text: win.filtered.length + (win.filtered.length === 1 ? " item" : " items")
                                color: Services.Colors.ash
                                font.pixelSize: 10
                                font.family: "JetBrainsMono NF"
                            }
                        }
                    }

                    // Nothing to show: say so rather than leaving a hole where
                    // the list would be.
                    Text {
                        visible: win.filtered.length === 0
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        text: win.searchText.length > 0 ? "Nothing matches that."
                             : win.onImages ? "No captures kept yet." : "Nothing copied yet."
                        color: Services.Colors.ash
                        font.pixelSize: 12
                        font.family: "JetBrainsMono NF"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    // ── Text: one row each ─────────────────────
                    ListView {
                        id: textList
                        opacity: win.listOpacity
                        visible: !win.onImages && win.filtered.length > 0
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        model: win.onImages ? [] : win.filtered
                        spacing: 4
                        clip: true
                        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded; width: 4 }

                        delegate: Rectangle {
                            required property var modelData
                            required property int index
                            width: textList.width
                            height: 46
                            radius: 10
                            color: index === win.selectedIndex ? Services.Colors.ghostAlpha(0.2)
                                                               : Services.Colors.ghostAlpha(0.06)
                            Behavior on color { ColorAnimation { duration: 100 } }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 8
                                spacing: 10

                                Text {
                                    text: "\ue14d"
                                    color: Services.Colors.ghost
                                    font.pixelSize: 16
                                    font.family: "Material Symbols Rounded"
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: modelData.preview
                                    color: Services.Colors.snow
                                    font.pixelSize: 11
                                    font.family: "JetBrainsMono NF"
                                    elide: Text.ElideRight
                                }
                                Widgets.IconButton {
                                    id: rowDel
                                    size: 24
                                    glyph: "\ue5cd"
                                    // Only on the row under the pointer. Filled
                                    // plates down every line at once read as a
                                    // column of buttons rather than as a list.
                                    opacity: rowHover.containsMouse || rowDel.hovered ? 1 : 0
                                    visible: opacity > 0.01
                                    Behavior on opacity { NumberAnimation { duration: 120 } }
                                    onActivated: win.deleteEntry(modelData)
                                }
                            }

                            MouseArea {
                                id: rowHover
                                anchors.fill: parent
                                z: -1
                                cursorShape: Qt.PointingHandCursor
                                hoverEnabled: true
                                onEntered: win.selectedIndex = index
                                onClicked: win.copySelected()
                            }
                        }
                    }

                    // ── Images: a wall of thumbnails ───────────
                    // A capture is its picture; down a list at 132 px wide they
                    // were all "binary data" with a stamp beside it, and the
                    // panel is wide enough now to just show them.
                    GridView {
                        id: imageGrid
                        opacity: win.listOpacity
                        visible: win.onImages && win.filtered.length > 0
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        model: win.onImages ? win.filtered : []
                        clip: true
                        cellWidth: width / win.gridCols
                        cellHeight: 132
                        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded; width: 4 }

                        delegate: Item {
                            required property var modelData
                            required property int index
                            width: imageGrid.cellWidth
                            height: imageGrid.cellHeight

                            Rectangle {
                                anchors.fill: parent
                                anchors.margins: 4
                                radius: 12
                                color: index === win.selectedIndex ? Services.Colors.ghostAlpha(0.24)
                                                                   : Services.Colors.ghostAlpha(0.06)
                                Behavior on color { ColorAnimation { duration: 120 } }

                                ClippingRectangle {
                                    anchors.fill: parent
                                    anchors.margins: 6
                                    radius: 9
                                    color: Services.Colors.ghostAlpha(0.12)

                                    Image {
                                        anchors.fill: parent
                                        source: modelData.thumbPath !== "" ? "file://" + modelData.thumbPath : ""
                                        fillMode: Image.PreserveAspectCrop
                                        visible: modelData.thumbPath !== "" && status === Image.Ready
                                        asynchronous: true
                                        // The path is reused as entries come
                                        // and go, so a cached frame would show
                                        // the previous capture.
                                        cache: false
                                    }
                                    Text {
                                        anchors.centerIn: parent
                                        text: "\ue3f4"
                                        color: Services.Colors.ghost
                                        font.pixelSize: 24
                                        font.family: "Material Symbols Rounded"
                                        visible: modelData.thumbPath === ""
                                    }
                                }

                                Widgets.IconButton {
                                    anchors.top: parent.top
                                    anchors.right: parent.right
                                    anchors.margins: 8
                                    size: 24
                                    glyph: "\ue5cd"
                                    opacity: tileHover.containsMouse ? 1 : 0
                                    visible: opacity > 0.01
                                    Behavior on opacity { NumberAnimation { duration: 120 } }
                                    onActivated: win.deleteEntry(modelData)
                                }

                                MouseArea {
                                    id: tileHover
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
}
