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
            onTriggered: if (card.bodyItem && card.bodyItem.focusItem)
                             card.bodyItem.focusItem.forceActiveFocus()
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
            // The ids travel as an argv entry, never through the shell's
            // parser. Base64 was only ever a way to survive that parser, and
            // Qt.btoa is deprecated -- same route Notifications took.
            thumbProc.command = ["sh", "-c",
                "mkdir -p /tmp/ashen_clip_thumbs && for id in $1; do cliphist decode \"$id\" > /tmp/ashen_clip_thumbs/\"$id\".png 2>/dev/null; done",
                "sh", imageIds.join(" ")
            ]
            thumbProc.running = true
        }

        function copySelected() {
            if (filtered.length === 0) return
            let e = filtered[Math.min(selectedIndex, filtered.length - 1)]
            copyProc.command = ["sh", "-c",
                                "printf %s \"$1\" | cliphist decode | wl-copy", "sh", e.id]
            copyProc.running = true
            Services.AppState.clipboardVisible = false
        }

        function deleteEntry(entry) {
            deleteProc.command = ["sh", "-c",
                                  "printf %s \"$1\" | cliphist delete", "sh", entry.fullLine]
            deleteProc.running = true
            win.entries = win.entries.filter(e => e.id !== entry.id)
        }

        function moveSelection(dir) {
            if (filtered.length === 0) return
            selectedIndex = Math.max(0, Math.min(filtered.length - 1, selectedIndex + dir))
            const view = win.onImages ? imageGrid : textGrid
            view.positionViewAtIndex(selectedIndex, GridView.Contain)
        }

        function setTab(name) {
            if (win.activeTab === name) return
            win.pendingTab = name
            win.selectedIndex = 0
        }
        // What the list is showing; it turns over halfway through the slide,
        // while nothing is legible.
        property string pendingTab: "Text"
        readonly property real listOpacity: listSlide.fade
        Widgets.SlideSwap {
            id: listSlide
            axis: "horizontal"
            index: win.pendingTab === "Images" ? 1 : 0
            onCommit: win.activeTab = win.pendingTab
        }

        MouseArea {
            anchors.fill: parent
            z: -1
            onClicked: Services.AppState.clipboardVisible = false
        }

        // Same drop as Process, out of the clipboard chip on the utility pill.
        // Read live from the pill, never written at click time: a keybind never
        // clicks, and the panel used to grow from wherever the last click left.
        readonly property string srcEdge: Services.AppState.clipboardSourceEdge
    // Its chip: on the utility pill of that edge, or on the bar.
    readonly property var chipRect: Services.AppState.chipRectOf("clipboard", win.srcEdge)
        readonly property real openXCalc: srcEdge === "" ? NaN
        : srcEdge === "left" ? Services.Sizes.panelTop
            : srcEdge === "right" ? win.width - card.openW - Services.Sizes.panelTop
            : (win.width - card.openW) / 2
        readonly property real openYCalc: srcEdge === "" ? NaN
        : srcEdge === "top" ? Services.Sizes.panelTop
            : srcEdge === "bottom" ? win.height - card.openH - Math.max(68, Services.Sizes.marginBottom + 18)
            : (win.height - card.openH) / 2

        Widgets.PanelHost {
            id: card
            shown: win.shown
            sourceEdge: win.srcEdge
            openXOverride: win.openXCalc
            openYOverride: win.openYCalc

            pillCX: win.chipRect.cx
            pillCY: win.chipRect.cy
            pillW: win.chipRect.w
            pillH: win.chipRect.h
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
                    ? Services.Colors.accentText
                    : (tabHover.containsMouse ? Services.Colors.snow : Services.Colors.mist)

                height: 34
                implicitWidth: tabInner.implicitWidth + 24

                RowLayout {
                    id: tabInner
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

            pillKey: "clipboard"
            restSide: "center"

            body: Component {
                Item {
                    // What takes the keyboard once the card is on screen.
                    readonly property Item focusItem: searchField

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 18
                        spacing: 12

                        // ── Top: what you are looking at, and what you are
                        // looking for. The two tabs used to own a 200 px column
                        // whose bottom half was a hole; up here they cost a
                        // pill's width and the entries get the whole card.
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 12

                            Rectangle {
                                id: tabsPill
                                Layout.preferredWidth: tabsRow.implicitWidth + 8
                                Layout.preferredHeight: 42
                                radius: 12
                                color: Services.Colors.surfacePill

                                // One accent for both tabs, and it travels. See
                                // docs/DESIGN.md.
                                Rectangle {
                                    x: (win.onImages ? textTab.width + tabsRow.spacing : 0) + 4
                                    y: 4
                                    width: win.onImages ? imagesTab.width : textTab.width
                                    height: parent.height - 8
                                    radius: Services.Sizes.innerR
                                    color: Services.Colors.ghost
                                    gradient: Services.Prefs.useGradients ? Services.Colors.accentGradient : null
                                    Behavior on x { NumberAnimation { duration: Services.Sizes.msPronounced; easing.type: Services.Sizes.easeOut } }
                                    Behavior on width { NumberAnimation { duration: Services.Sizes.msStandard; easing.type: Services.Sizes.easeOut } }
                                }

                                Row {
                                    id: tabsRow
                                    x: 4
                                    y: 4
                                    height: parent.height - 8
                                    spacing: 2
                                    TabRow {
                                        id: textTab
                                        anchors.verticalCenter: parent.verticalCenter
                                        name: "Text"
                                        glyph: "\ue14d"
                                        count: win.textCount
                                    }
                                    TabRow {
                                        id: imagesTab
                                        anchors.verticalCenter: parent.verticalCenter
                                        name: "Images"
                                        glyph: "\ue3f4"
                                        count: win.imageCount
                                    }
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 42
                                radius: 12
                                color: Services.Colors.ghostAlpha(0.1)
                                // A resting outline is decoration; only focus earns one.
                                border.color: Services.Colors.ghost
                                border.width: searchField.activeFocus ? 1 : 0
                                Behavior on border.color { ColorAnimation { duration: Services.Sizes.msMicro } }

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
                                            Keys.onUpPressed: win.moveSelection(-win.gridCols)
                                            Keys.onDownPressed: win.moveSelection(win.gridCols)
                                            Keys.onLeftPressed: win.moveSelection(-1)
                                            Keys.onRightPressed: win.moveSelection(1)
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

                            // Wipe: the far end of the same bar, where a
                            // destructive button is out of the way of the tabs
                            // you are actually aiming at.
                            Rectangle {
                                Layout.preferredWidth: 42
                                Layout.preferredHeight: 42
                                radius: 12
                                color: wipeHover.containsMouse ? Services.Colors.ghostAlpha(0.22)
                                                               : Services.Colors.ghostAlpha(0.06)
                                Behavior on color { ColorAnimation { duration: Services.Sizes.msMicro } }

                                Text {
                                    anchors.centerIn: parent
                                    text: "\ue0b8"
                                    color: wipeHover.containsMouse ? Services.Colors.snow : Services.Colors.mist
                                    font.pixelSize: 18
                                    font.family: "Material Symbols Rounded"
                                    Behavior on color { ColorAnimation { duration: Services.Sizes.msMicro } }
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

                            // ── Text: the same wall the captures get ───
                            // A row 900 px wide held one elided line and a lot
                            // of nothing; a tile holds the first few lines,
                            // which is what you are scanning for.
                            GridView {
                                id: textGrid
                                opacity: win.listOpacity
                                transform: Translate { x: listSlide.offX }
                                visible: !win.onImages && win.filtered.length > 0
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                model: win.onImages ? [] : win.filtered
                                cellWidth: width / win.gridCols
                                cellHeight: 132
                                clip: true
                                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded; width: 4 }

                                delegate: Item {
                                    required property var modelData
                                    required property int index
                                    width: textGrid.cellWidth
                                    height: textGrid.cellHeight

                                    Rectangle {
                                        anchors.fill: parent
                                        anchors.margins: 4
                                        radius: 12
                                        color: index === win.selectedIndex ? Services.Colors.ghostAlpha(0.2)
                                                                           : Services.Colors.ghostAlpha(0.06)
                                        Behavior on color { ColorAnimation { duration: Services.Sizes.msInstant } }

                                        Text {
                                            anchors.fill: parent
                                            anchors.margins: 12
                                            anchors.rightMargin: 14
                                            text: modelData.preview
                                            color: Services.Colors.snow
                                            font.pixelSize: 11
                                            font.family: "JetBrainsMono NF"
                                            wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                                            elide: Text.ElideRight
                                            maximumLineCount: 5
                                            lineHeight: 1.2
                                        }

                                        Widgets.IconButton {
                                            id: tileDel
                                            size: 24
                                            glyph: "\ue5cd"
                                            anchors.right: parent.right
                                            anchors.top: parent.top
                                            anchors.margins: 4
                                            // Only on the tile under the pointer.
                                            opacity: tileHover.containsMouse || tileDel.hovered ? 1 : 0
                                            visible: opacity > 0.01
                                            Behavior on opacity { NumberAnimation { duration: Services.Sizes.msMicro } }
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

                            // ── Images: a wall of thumbnails ───────────
                            // A capture is its picture; down a list at 132 px wide they
                            // were all "binary data" with a stamp beside it, and the
                            // panel is wide enough now to just show them.
                            GridView {
                                id: imageGrid
                                opacity: win.listOpacity
                                transform: Translate { x: listSlide.offX }
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
                                        Behavior on color { ColorAnimation { duration: Services.Sizes.msMicro } }

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
                                            id: tileDel
                                            anchors.top: parent.top
                                            anchors.right: parent.right
                                            anchors.margins: 8
                                            size: 24
                                            glyph: "\ue5cd"
                                            // Its own hover counts: the button covers
                                            // the tile's MouseArea, so reaching for it
                                            // used to make it fade away.
                                            opacity: tileHover.containsMouse || tileDel.hovered ? 1 : 0
                                            visible: opacity > 0.01
                                            Behavior on opacity { NumberAnimation { duration: Services.Sizes.msMicro } }
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
}
