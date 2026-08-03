import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import "root:/services" as Services

// A folder setting you type. "Change" used to shell out to zenity, which drags
// a GTK file manager onto the screen over a shell that has its own look, takes
// a second to appear, and is not even installed everywhere -- and all of that
// to enter a path the user already knows. Now the path itself becomes the
// field: click, type, Enter.
//
// It refuses a folder that is not there. A settings row that silently accepts
// a typo and then quietly saves nothing anywhere is worse than one that says
// no, so the check happens here, once, before the value is handed over.
RowLayout {
    id: root

    property string glyph: ""
    property string title: ""
    // What the setting is right now, already resolved to whatever the caller
    // falls back to when it is unset.
    property string value: ""
    property string placeholder: "/home/you/Pictures"

    // Only fires for a folder that exists. An empty string means "cleared" --
    // the caller decides what its default is; this row has no opinion.
    signal committed(string path)

    Layout.fillWidth: true
    spacing: 12

    property bool editing: false
    property bool badPath: false

    function beginEdit() {
        root.badPath = false
        field.text = root.value
        root.editing = true
        field.forceActiveFocus()
        field.selectAll()
    }
    function cancel() {
        root.editing = false
        root.badPath = false
    }
    function commit() {
        let p = field.text.trim()
        // A leading ~ is what anyone types for their home directory, and it is
        // the shell that expands it -- nothing here has been through one.
        if (p === "~") p = Services.Paths.home
        else if (p.startsWith("~/")) p = Services.Paths.home + p.substring(1)
        // Trailing slash never changes the meaning and only makes the saved
        // value differ from the same path typed twice.
        if (p.length > 1 && p.endsWith("/")) p = p.substring(0, p.length - 1)
        if (p === "") { root.editing = false; root.committed(""); return }
        checkProc.candidate = p
        checkProc.running = true
    }

    Process {
        id: checkProc
        property string candidate: ""
        running: false
        command: ["sh", "-c", "[ -d \"$1\" ] && echo yes || echo no", "sh", candidate]
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim() === "yes") {
                    root.editing = false
                    root.badPath = false
                    root.committed(checkProc.candidate)
                } else {
                    root.badPath = true
                    field.forceActiveFocus()
                }
            }
        }
    }

    RowGlyph { glyph: root.glyph }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 2

        Text {
            text: root.title
            color: Services.Colors.snow
            font.pixelSize: 13
            font.bold: true
            font.family: "JetBrainsMono NF"
        }

        // Reading and editing are the same line, so the path does not jump to
        // somewhere else on the row the moment you go to change it.
        Item {
            Layout.fillWidth: true
            implicitHeight: root.editing ? 28 : shownPath.implicitHeight
            Behavior on implicitHeight { NumberAnimation { duration: Services.Sizes.msMicro; easing.type: Services.Sizes.easeOut } }

            Text {
                id: shownPath
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                visible: !root.editing
                text: root.value
                color: Services.Colors.ash
                font.pixelSize: 10
                font.family: "JetBrainsMono NF"
                elide: Text.ElideMiddle
            }

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                height: 28
                visible: root.editing
                radius: 8
                color: Services.Colors.ghostAlpha(0.12)
                border.width: 1
                border.color: root.badPath ? Services.Colors.error_
                            : field.activeFocus ? Services.Colors.ghost
                                                : Services.Colors.ghostAlpha(0.2)
                Behavior on border.color { ColorAnimation { duration: Services.Sizes.msMicro } }

                TextField {
                    id: field
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    verticalAlignment: TextInput.AlignVCenter
                    placeholderText: root.placeholder
                    color: Services.Colors.snow
                    placeholderTextColor: Services.Colors.ash
                    font.pixelSize: 11
                    font.family: "JetBrainsMono NF"
                    background: null
                    padding: 0
                    // Typing again is the retry, so the complaint goes away as
                    // soon as the thing it was complaining about does.
                    onTextChanged: root.badPath = false
                    onAccepted: root.commit()
                    Keys.onEscapePressed: root.cancel()
                }
            }
        }

        Text {
            visible: root.badPath
            text: "No such folder"
            color: Services.Colors.error_
            font.pixelSize: 10
            font.family: "JetBrainsMono NF"
        }
    }

    Rectangle {
        width: 84; height: 32
        radius: 8
        color: btnHover.containsMouse ? Services.Colors.ghostAlpha(0.3)
                                      : Services.Colors.ghostAlpha(0.15)
        Behavior on color { ColorAnimation { duration: Services.Sizes.msMicro } }
        Text {
            anchors.centerIn: parent
            text: root.editing ? "Save" : "Change"
            color: Services.Colors.snow
            font.pixelSize: 11
            font.family: "JetBrainsMono NF"
        }
        MouseArea {
            id: btnHover
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.editing ? root.commit() : root.beginEdit()
        }
    }
}
