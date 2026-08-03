import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts

import "root:/modules/widgets" as Widgets
import "root:/services" as Services

// Quick notes: a list on the left, the note itself on the right. Everything is
// a plain .md in the folder Settings points at, so a note is still a note
// outside this shell.
Scope {
    id: root

    PanelWindow {
        id: win
        anchors { top: true; left: true; right: true; bottom: true }
        screen: Services.Screens.active
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"

        readonly property bool shown: Services.AppState.notesVisible
        visible: shown || closeDelay.running
        onShownChanged: {
            if (!shown) {
                // Never wait on the debounce to close: the panel is about to be
                // torn down and the last keystrokes would go with it.
                Services.Notes.flush()
                closeDelay.restart()
                return
            }
            Services.Notes.refresh()
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

        MouseArea {
            anchors.fill: parent
            z: -1
            onClicked: Services.AppState.notesVisible = false
        }

        // Live from the pill, not a value written when something was clicked: a
        // keybind never clicks.
        readonly property string srcEdge: Services.AppState.notesSourceEdge
        readonly property var chipRect: Services.AppState.chipRectOf("notes", win.srcEdge)
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
            pillKey: "notes"
            restSide: "center"
            sourceEdge: win.srcEdge
            openXOverride: win.openXCalc
            openYOverride: win.openYCalc

            pillCX: win.chipRect.cx
            pillCY: win.chipRect.cy
            pillW: win.chipRect.w
            pillH: win.chipRect.h
            pillGlyph: Services.Pills.glyph("notes")

            openW: Math.min(760, win.width - 80)
            openH: Math.min(520, win.height - 120)
            cardRadius: 22

            body: Component {
                Item {
                    id: bodyRoot

                    // Crosses the Component boundary for the panel: the field
                    // the keyboard should land in.
                    readonly property Item focusItem: editor
                    property bool newFolder: false

                    // Whole minutes are enough for something you wrote today.
                    function ago(ms, tick) {
                        const s = Math.max(0, (Date.now() - ms) / 1000)
                        if (s < 60) return "now"
                        if (s < 3600) return Math.floor(s / 60) + "m"
                        if (s < 86400) return Math.floor(s / 3600) + "h"
                        return Math.floor(s / 86400) + "d"
                    }
                    // Passed into ago() so the binding has a reason to re-run.
                    property int clockTick: 0
                    Timer {
                        running: true; repeat: true; interval: 30000
                        onTriggered: bodyRoot.clockTick++
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 18
                        spacing: 16

                        // ── The list ────────────────────────────────────────
                        ColumnLayout {
                            Layout.preferredWidth: 236
                            Layout.fillWidth: false
                            Layout.fillHeight: true
                            spacing: 10

                            // No heading: a panel does not announce itself. What
                            // is up here is where you are, and the two things you
                            // can make. See docs/DESIGN.md.
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 6

                                // The trail back out; the root is a house.
                                Repeater {
                                    model: Services.Notes.crumbs
                                    delegate: Row {
                                        required property var modelData
                                        required property int index
                                        spacing: 4
                                        Text {
                                            visible: index > 0
                                            text: "/"
                                            color: Services.Colors.ash
                                            font.pixelSize: 11
                                            font.family: "JetBrainsMono NF"
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                        Text {
                                            id: crumbText
                                            readonly property bool here: modelData === Services.Notes.folder
                                            text: modelData === "" ? "" : String(modelData).split("/").pop()
                                            font.family: modelData === "" ? "Material Symbols Rounded" : "JetBrainsMono NF"
                                            font.pixelSize: modelData === "" ? 14 : 11
                                            color: crumbText.here || crumbHover.containsMouse
                                                 ? Services.Colors.snow : Services.Colors.mist
                                            anchors.verticalCenter: parent.verticalCenter
                                            Behavior on color { ColorAnimation { duration: Services.Sizes.msMicro } }
                                            MouseArea {
                                                id: crumbHover
                                                anchors.fill: parent
                                                anchors.margins: -3
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: Services.Notes.enter(modelData)
                                            }
                                        }
                                    }
                                }

                                Item { Layout.fillWidth: true }

                                Widgets.IconButton {
                                    size: 28
                                    glyph: ""
                                    onActivated: bodyRoot.newFolder = !bodyRoot.newFolder
                                }
                                Widgets.IconButton {
                                    size: 28
                                    glyph: ""
                                    onActivated: Services.Notes.create()
                                }
                            }

                            // Naming a new folder, in place rather than as a
                            // dialog: it is one field and an Enter.
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: bodyRoot.newFolder ? 32 : 0
                                clip: true
                                radius: 9
                                color: Services.Colors.fillInset
                                opacity: bodyRoot.newFolder ? 1 : 0
                                visible: opacity > 0.01
                                Behavior on Layout.preferredHeight { NumberAnimation { duration: Services.Sizes.msMicro } }
                                Behavior on opacity { NumberAnimation { duration: Services.Sizes.msMicro } }

                                TextInput {
                                    id: folderField
                                    anchors.fill: parent
                                    anchors.leftMargin: 10
                                    anchors.rightMargin: 10
                                    verticalAlignment: TextInput.AlignVCenter
                                    color: Services.Colors.snow
                                    font.pixelSize: 12
                                    font.family: "JetBrainsMono NF"
                                    onVisibleChanged: if (visible) forceActiveFocus()
                                    Keys.onReturnPressed: {
                                        Services.Notes.createFolder(text)
                                        text = ""
                                        bodyRoot.newFolder = false
                                    }
                                    Keys.onEscapePressed: { text = ""; bodyRoot.newFolder = false }
                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: "Folder name..."
                                        color: Services.Colors.ash
                                        font: folderField.font
                                        visible: folderField.text.length === 0
                                    }
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                radius: 14
                                color: Services.Colors.fillInset

                                ListView {
                                    id: list
                                    anchors.fill: parent
                                    anchors.margins: 6
                                    clip: true
                                    spacing: 2
                                    // Folders first, then the notes: the same
                                    // order a file manager uses, so the shape of
                                    // the folder is readable at a glance.
                                    model: Services.Notes.folders.concat(Services.Notes.notes)

                                    delegate: Rectangle {
                                        id: row
                                        required property var modelData
                                        // A row is either a folder or a note.
                                        readonly property bool isFolder: modelData.rel !== undefined
                                        readonly property bool on: !row.isFolder
                                            && Services.Notes.current === modelData.file
                                        width: list.width
                                        height: 44
                                        radius: 10
                                        // Selection is a fill; hover only makes
                                        // the writing brighter. See DESIGN.md.
                                        color: row.on ? Services.Colors.ghost : "transparent"
                                        gradient: Services.Prefs.useGradients && row.on
                                            ? Services.Colors.accentGradient : null

                                        // Under everything, so the × on top of
                                        // it gets its own clicks.
                                        MouseArea {
                                            id: rowHover
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: row.isFolder ? Services.Notes.enter(row.modelData.rel)
                                                                    : Services.Notes.open(row.modelData.file)
                                        }

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 10
                                            anchors.rightMargin: 34
                                            spacing: 6

                                            Text {
                                                visible: row.isFolder
                                                text: ""
                                                color: row.on ? Services.Colors.accentText
                                                     : (rowHover.containsMouse ? Services.Colors.snow
                                                                               : Services.Colors.mist)
                                                font.pixelSize: 16
                                                font.family: "Material Symbols Rounded"
                                                Layout.alignment: Qt.AlignVCenter
                                            }

                                            ColumnLayout {
                                                Layout.fillWidth: true
                                                spacing: 0
                                                Text {
                                                    text: row.isFolder ? row.modelData.name : row.modelData.title
                                                    color: row.on ? Services.Colors.accentText
                                                         : (rowHover.containsMouse ? Services.Colors.snow
                                                                                   : Services.Colors.mist)
                                                    font.pixelSize: 12
                                                    font.family: "JetBrainsMono NF"
                                                    elide: Text.ElideRight
                                                    Layout.fillWidth: true
                                                    Behavior on color { ColorAnimation { duration: Services.Sizes.msMicro } }
                                                }
                                                Text {
                                                    text: row.isFolder
                                                        ? row.modelData.count + (row.modelData.count === 1 ? " note" : " notes")
                                                        : (row.modelData.preview && row.modelData.preview.length > 0
                                                           ? row.modelData.preview
                                                           : bodyRoot.ago(row.modelData.mtime, bodyRoot.clockTick))
                                                    elide: Text.ElideRight
                                                    Layout.fillWidth: true
                                                    color: row.on ? Services.Colors.accentText
                                                                  : Services.Colors.ash
                                                    font.pixelSize: 9
                                                    font.family: "JetBrainsMono NF"
                                                }
                                            }

                                        }

                                        // Only under the pointer: a column of
                                        // permanent crosses turns a list of
                                        // notes into a row of buttons. It counts
                                        // its OWN hover too, or it vanishes the
                                        // moment you reach for it.
                                        Widgets.IconButton {
                                            id: delBtn
                                            anchors.right: parent.right
                                            anchors.rightMargin: 8
                                            anchors.verticalCenter: parent.verticalCenter
                                            size: 24
                                            glyph: ""
                                            opacity: rowHover.containsMouse || delBtn.hovered ? 1 : 0
                                            Behavior on opacity { NumberAnimation { duration: Services.Sizes.msMicro } }
                                            // An empty folder can go; one with
                                            // notes in it is not this panel's to
                                            // delete.
                                            onActivated: row.isFolder
                                                ? Services.Notes.removeFolder(row.modelData.rel)
                                                : Services.Notes.remove(row.modelData.file)
                                        }
                                    }
                                }

                                Text {
                                    anchors.centerIn: parent
                                    width: parent.width - 32
                                    horizontalAlignment: Text.AlignHCenter
                                    wrapMode: Text.WordWrap
                                    visible: Services.Notes.notes.length === 0
                                    text: "Nothing written yet"
                                    color: Services.Colors.ash
                                    font.pixelSize: 11
                                    font.family: "JetBrainsMono NF"
                                }
                            }
                        }

                        // ── The note ────────────────────────────────────────
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            radius: 14
                            color: Services.Colors.fillInset

                            Flickable {
                                id: scroll
                                anchors.fill: parent
                                anchors.margins: 14
                                clip: true
                                contentWidth: width
                                contentHeight: editor.implicitHeight
                                boundsBehavior: Flickable.StopAtBounds

                                TextEdit {
                                    id: editor
                                    width: scroll.width
                                    enabled: Services.Notes.current !== ""
                                    text: Services.Notes.draft
                                    color: Services.Colors.snow
                                    selectionColor: Services.Colors.ghostAlpha(0.4)
                                    selectedTextColor: Services.Colors.snow
                                    font.pixelSize: 13
                                    font.family: "JetBrainsMono NF"
                                    wrapMode: TextEdit.Wrap
                                    // Markdown as you type: `#` makes a
                                    // heading big, `-` makes a bullet, `**`
                                    // makes it bold. What lands on disk is
                                    // still the markdown, not HTML.
                                    textFormat: TextEdit.MarkdownText
                                    persistentSelection: true
                                    // The service owns the text; this only
                                    // reports edits. Writing back into `text`
                                    // from here would fight the binding every
                                    // time a note is opened.
                                    onTextChanged: if (text !== Services.Notes.draft)
                                                       Services.Notes.edit(text)
                                    Keys.onEscapePressed: Services.AppState.notesVisible = false

                                    // Follow the caret when it leaves the view.
                                    onCursorRectangleChanged: {
                                        if (cursorRectangle.y < scroll.contentY)
                                            scroll.contentY = cursorRectangle.y
                                        else if (cursorRectangle.y + cursorRectangle.height > scroll.contentY + scroll.height)
                                            scroll.contentY = cursorRectangle.y + cursorRectangle.height - scroll.height
                                    }
                                }
                            }

                            Text {
                                anchors.centerIn: parent
                                width: parent.width - 60
                                horizontalAlignment: Text.AlignHCenter
                                wrapMode: Text.WordWrap
                                visible: Services.Notes.current === ""
                                text: "Pick a note, or start a new one"
                                color: Services.Colors.ash
                                font.pixelSize: 12
                                font.family: "JetBrainsMono NF"
                            }
                        }
                    }

                    // Where it is being written, and whether it has landed.
                    RowLayout {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.leftMargin: 18
                        anchors.rightMargin: 18
                        anchors.bottomMargin: 4
                        spacing: 8

                        Text {
                            text: Services.Notes.dir.replace(Services.Paths.home, "~")
                            color: Services.Colors.ash
                            font.pixelSize: 9
                            font.family: "JetBrainsMono NF"
                            elide: Text.ElideMiddle
                            Layout.fillWidth: true
                        }
                        Text {
                            text: Services.Notes.current === "" ? ""
                                : (Services.Notes.dirty ? "saving" : "saved")
                            color: Services.Colors.ash
                            font.pixelSize: 9
                            font.family: "JetBrainsMono NF"
                        }
                    }
                }
            }
        }
    }
}
