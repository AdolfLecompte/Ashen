import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "root:/services" as Services
import "root:/modules/settings/components"

// Keyboard layouts today; mouse and touchpad belong here when they land.
TabPage {
    id: tab

    // Layout picker state
    property bool pickerOpen: false
    property string layoutQuery: ""
    // Match on code or name, so both "de" and "german" find German
    readonly property var filteredLayouts: {
        let q = tab.layoutQuery.trim().toLowerCase()
        let all = Services.Keyboard.available
        if (q === "") return all
        return all.filter(l => l.code.indexOf(q) !== -1
            || l.name.toLowerCase().indexOf(q) !== -1)
    }

    Card {
        title: "Keyboard"
        RowLayout {
            Layout.fillWidth: true
            SectionLabel { text: "Keyboard Layout"; Layout.fillWidth: true }
            SectionLabel {
                // XKB caps at 4 groups; past that they cannot be selected
                text: Services.Keyboard.layouts.length + " / " + Services.Keyboard.maxLayouts
                color: Services.Keyboard.canAdd ? Services.Colors.ash : Services.Colors.ghost
            }
        }

        Flow {
            Layout.fillWidth: true
            spacing: 10

            Repeater {
                model: Services.Keyboard.layouts
                delegate: Rectangle {
                    id: kbCard
                    required property var modelData
                    required property int index
                    readonly property bool active: Services.Keyboard.activeIndex === kbCard.index
                    width: 100; height: 64
                    radius: 12
                    color: kbCard.active ? Services.Colors.ghost : Services.Colors.ghostAlpha(0.12)
                    gradient: Services.Prefs.useGradients && (kbCard.active) ? Services.Colors.accentGradient : null
                    Behavior on color { ColorAnimation { duration: Services.Sizes.msMicro } }
                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 4
                        Text {
                            text: "\ue312"
                            font.family: "Material Symbols Rounded"
                            font.pixelSize: 20
                            color: kbCard.active ? Services.Colors.accentText : Services.Colors.mist
                            Layout.alignment: Qt.AlignHCenter
                        }
                        Text {
                            text: kbCard.modelData.toUpperCase()
                            font.pixelSize: 10
                            font.family: "JetBrainsMono NF"
                            color: kbCard.active ? Services.Colors.accentText : Services.Colors.mist
                            Layout.alignment: Qt.AlignHCenter
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        onClicked: Services.Keyboard.setLayout(kbCard.index)
                    }
                    // Removing the last layout would leave a keyboard that
                    // types nothing, so the X only exists while there are 2+
                    Rectangle {
                        visible: Services.Keyboard.layouts.length > 1 && (kbCard.hovered || rmArea.containsMouse)
                        anchors.top: parent.top
                        anchors.right: parent.right
                        anchors.margins: 4
                        width: 18; height: 18
                        radius: 9
                        color: rmArea.containsMouse ? Services.Colors.ghost : Services.Colors.ghostAlpha(0.4)
                        gradient: Services.Prefs.useGradients && (rmArea.containsMouse) ? Services.Colors.accentGradient : null
                        Behavior on color { ColorAnimation { duration: Services.Sizes.msMicro } }
                        Text {
                            anchors.centerIn: parent
                            text: "\ue5cd"
                            font.family: "Material Symbols Rounded"
                            font.pixelSize: 11
                            color: Services.Colors.accentText
                        }
                        MouseArea {
                            id: rmArea
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            hoverEnabled: true
                            onClicked: Services.Keyboard.removeLayout(kbCard.modelData)
                        }
                    }
                    property bool hovered: false
                    HoverHandler { onHoveredChanged: kbCard.hovered = hovered }
                }
            }

            Rectangle {
                id: addCard
                width: 100; height: 64
                radius: 12
                color: addArea.containsMouse && Services.Keyboard.canAdd
                    ? Services.Colors.ghostAlpha(0.2) : Services.Colors.ghostAlpha(0.06)
                border.color: Services.Colors.ghostAlpha(0.3)
                border.width: 1
                opacity: Services.Keyboard.canAdd ? 1.0 : 0.4
                Behavior on color { ColorAnimation { duration: Services.Sizes.msMicro } }
                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 4
                    Text {
                        text: "\ue145"
                        font.family: "Material Symbols Rounded"
                        font.pixelSize: 20
                        color: Services.Colors.ghost
                        Layout.alignment: Qt.AlignHCenter
                    }
                    Text {
                        text: "Add"
                        font.pixelSize: 10
                        font.family: "JetBrainsMono NF"
                        color: Services.Colors.mist
                        Layout.alignment: Qt.AlignHCenter
                    }
                }
                MouseArea {
                    id: addArea
                    anchors.fill: parent
                    cursorShape: Services.Keyboard.canAdd ? Qt.PointingHandCursor : Qt.ForbiddenCursor
                    hoverEnabled: true
                    enabled: Services.Keyboard.canAdd
                    onClicked: {
                        tab.pickerOpen = !tab.pickerOpen
                        if (tab.pickerOpen) {
                            tab.layoutQuery = ""
                            searchField.forceActiveFocus()
                        }
                    }
                }
            }
        }

        Text {
            visible: !Services.Keyboard.canAdd
            text: "XKB allows 4 layouts at most -- remove one to add another"
            color: Services.Colors.ash
            font.pixelSize: 10
            font.family: "JetBrainsMono NF"
        }

        // ── Layout picker: 99 layouts, so it filters instead of listing ──
        Rectangle {
            Layout.fillWidth: true
            clip: true
            radius: 12
            color: Services.Colors.ghostAlpha(0.08)
            implicitHeight: pickerCol.implicitHeight + 20
            // Slide open/closed instead of snapping.
            Layout.preferredHeight: tab.pickerOpen ? implicitHeight : 0
            Behavior on Layout.preferredHeight { NumberAnimation { duration: Services.Sizes.msStandard; easing.type: Services.Sizes.easeOut } }
            opacity: tab.pickerOpen ? 1.0 : 0.0
            Behavior on opacity { NumberAnimation { duration: Services.Sizes.msMicro } }

            ColumnLayout {
                id: pickerCol
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 10
                spacing: 8

                Rectangle {
                    Layout.fillWidth: true
                    height: 34
                    radius: 8
                    color: Services.Colors.ghostAlpha(0.12)
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 8
                        Text {
                            text: "\ue8e2"
                            font.family: "Material Symbols Rounded"
                            font.pixelSize: 15
                            color: Services.Colors.ghost
                        }
                        TextField {
                            id: searchField
                            Layout.fillWidth: true
                            placeholderText: "Search layout..."
                            text: tab.layoutQuery
                            onTextChanged: tab.layoutQuery = text
                            color: Services.Colors.snow
                            placeholderTextColor: Services.Colors.ash
                            font.pixelSize: 12
                            font.family: "JetBrainsMono NF"
                            background: null
                            padding: 0
                            Keys.onEscapePressed: tab.pickerOpen = false
                        }
                    }
                }

                Text {
                    visible: tab.filteredLayouts.length === 0
                    text: "No layout matches \"" + tab.layoutQuery + "\""
                    color: Services.Colors.ash
                    font.pixelSize: 11
                    font.family: "JetBrainsMono NF"
                }

                // Capped height: the unfiltered list is 99 entries long
                ListView {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.min(contentHeight, 168)
                    visible: tab.filteredLayouts.length > 0
                    clip: true
                    model: tab.filteredLayouts
                    boundsBehavior: Flickable.StopAtBounds
                    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded; width: 4 }

                    delegate: Rectangle {
                        required property var modelData
                        readonly property bool already: Services.Keyboard.layouts.includes(modelData.code)
                        width: ListView.view.width
                        height: 30
                        radius: 6
                        color: rowArea.containsMouse && !already
                            ? Services.Colors.ghostAlpha(0.18) : "transparent"
                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            spacing: 10
                            Text {
                                text: modelData.code
                                color: Services.Colors.ghost
                                font.pixelSize: 11
                                font.bold: true
                                font.family: "JetBrainsMono NF"
                                Layout.preferredWidth: 52
                            }
                            Text {
                                text: modelData.name
                                color: parent.parent.already ? Services.Colors.ash : Services.Colors.snow
                                font.pixelSize: 11
                                font.family: "JetBrainsMono NF"
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                            Text {
                                visible: parent.parent.already
                                text: "in use"
                                color: Services.Colors.ash
                                font.pixelSize: 9
                                font.family: "JetBrainsMono NF"
                            }
                        }
                        MouseArea {
                            id: rowArea
                            anchors.fill: parent
                            hoverEnabled: true
                            enabled: !parent.already
                            cursorShape: parent.already ? Qt.ForbiddenCursor : Qt.PointingHandCursor
                            onClicked: {
                                Services.Keyboard.addLayout(modelData.code)
                                tab.pickerOpen = false
                            }
                        }
                    }
                }
            }
        }

        Text {
            text: Services.Keyboard.keymap
            color: Services.Colors.ash
            font.pixelSize: 10
            font.family: "JetBrainsMono NF"
        }

    }

    Card {
        title: "Shortcuts"

        Text {
            text: "Read straight from hypr/conf/keybinds.lua — edit that file and this list follows."
            color: Services.Colors.ash
            font.pixelSize: 10
            font.family: "JetBrainsMono NF"
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }

        Repeater {
            model: Services.Keybinds.sections
            delegate: ColumnLayout {
                required property var modelData
                Layout.fillWidth: true
                Layout.topMargin: 6
                spacing: 6

                SectionLabel {
                    text: modelData.name
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                Repeater {
                    model: modelData.items
                    delegate: RowLayout {
                        required property var modelData
                        Layout.fillWidth: true
                        spacing: 10

                        // Keys first: the list is scanned by "what do I press?"
                        Rectangle {
                            Layout.preferredWidth: 168
                            Layout.preferredHeight: 26
                            radius: 7
                            color: Services.Colors.ghostAlpha(0.15)
                            Text {
                                anchors.left: parent.left
                                anchors.leftMargin: 8
                                anchors.right: parent.right
                                anchors.rightMargin: 8
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData.keys
                                color: Services.Colors.snow
                                font.pixelSize: 10
                                font.bold: true
                                font.family: "JetBrainsMono NF"
                                elide: Text.ElideRight
                            }
                        }
                        Text {
                            Layout.fillWidth: true
                            text: modelData.action
                            color: Services.Colors.mist
                            font.pixelSize: 11
                            font.family: "JetBrainsMono NF"
                            elide: Text.ElideRight
                        }
                    }
                }
            }
        }

        Text {
            visible: Services.Keybinds.binds.length === 0
            text: "No shortcuts found — keybinds.lua could not be read."
            color: Services.Colors.ash
            font.pixelSize: 11
            font.family: "JetBrainsMono NF"
        }
    }

    Item { Layout.preferredHeight: 8 }
}
