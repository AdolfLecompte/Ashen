import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "root:/services" as Services
import "root:/modules/settings/components"

// Everything about the bar itself: which edge it lives on and what its clock
// and weather chip display.
TabPage {
    id: tab

    // City add-picker (weather): open state for the search box
    property bool cityPickerOpen: false

    // Live preview under "Time Format". new Date() is not reactive, so without
    // this tick the sample freezes at whatever time the tab opened.
    property string timePreview: Qt.formatDateTime(new Date(), Services.Prefs.timeFormat)
    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: tab.timePreview = Qt.formatDateTime(new Date(), Services.Prefs.timeFormat)
    }

    Card {
        title: "Bar"

        SectionLabel { text: "Position" }

        Segmented {
            stacked: true
            options: [
                { id: "top", icon: "\ue5d8", label: "Top" },
                { id: "bottom", icon: "\ue5db", label: "Bottom" },
                { id: "left", icon: "\ue5c4", label: "Left" },
                { id: "right", icon: "\ue5c8", label: "Right" },
            ]
            current: Services.Prefs.barPosition
            onPicked: id => Services.Prefs.barPosition = id
        }

        Text {
            text: "Side bars stack the pills and drop the labels they have no room for."
            color: Services.Colors.ash
            font.pixelSize: 10
            font.family: "JetBrainsMono NF"
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }
    }

    // ── Bar layout editor ───────────────────────────────────────────────
    readonly property var pillLabels: ({
        launcher: "Launcher", notifications: "Notifications", workspaces: "Workspaces",
        media: "Media", clock: "Clock & Weather", locks: "Caps / Num", usb: "USB",
        recording: "Recording", tray: "Tray", system: "System chips", power: "Power"
    })
    readonly property var allPills: ["launcher", "notifications", "workspaces", "media",
                                     "clock", "locks", "usb", "recording", "tray", "system", "power"]
    // Whatever is in no section at all
    readonly property var availablePills:
        tab.allPills.filter(id => Services.Prefs.barSectionOf(id) === "")

    // Which pill is in the air, so its own zone can be lifted above the others
    property string draggingId: ""

    // A chip that can be picked up. The slot keeps its place in the row while
    // only the face travels, so the layout underneath never gets disturbed and
    // a drop that lands nowhere just snaps home.
    component PillChip: Item {
        id: slot
        property string pillId: ""
        width: face.implicitWidth
        height: 28

        Rectangle {
            id: face
            implicitWidth: lab.implicitWidth + 20
            width: implicitWidth
            height: 28
            radius: 9
            z: dragArea.drag.active ? 100 : 0
            color: dragArea.drag.active ? Services.Colors.ghost
                 : hoverArea.containsMouse ? Services.Colors.ghostAlpha(0.32)
                 : Services.Colors.ghostAlpha(0.18)
            Behavior on color { ColorAnimation { duration: 140 } }

            // What the DropArea reads on the other end. `Drag.mimeData` is
            // only ever filled for Drag.Automatic (a real cross-process drag);
            // an internal QML drag carries the item itself and nothing else,
            // so the id has to live on the item as a plain property.
            property string pillId: slot.pillId

            Drag.active: dragArea.drag.active
            Drag.dragType: Drag.Internal
            Drag.hotSpot.x: width / 2
            Drag.hotSpot.y: height / 2

            Behavior on x { enabled: !dragArea.drag.active; NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
            Behavior on y { enabled: !dragArea.drag.active; NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

            Text {
                id: lab
                anchors.centerIn: parent
                text: tab.pillLabels[slot.pillId] || slot.pillId
                color: dragArea.drag.active ? Services.Colors.abyss : Services.Colors.snow
                font.pixelSize: 11
                font.family: "JetBrainsMono NF"
            }

            MouseArea {
                id: hoverArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: dragArea.drag.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor
            }
            MouseArea {
                id: dragArea
                anchors.fill: parent
                drag.target: face
                drag.smoothed: false
                onPressed: tab.draggingId = slot.pillId
                onReleased: {
                    // Clear the drag flag BEFORE dropping: a successful drop
                    // rewrites the layout, which rebuilds this very row and
                    // destroys this delegate mid-handler. Anything after the
                    // drop then runs against a dead object — that was throwing
                    // and leaving the zone stuck in its raised state.
                    tab.draggingId = ""
                    face.Drag.drop()
                    // Only reached when nothing caught it; then it snaps home.
                    if (face) { face.x = 0; face.y = 0 }
                }
            }
        }
    }

    // One of the four places a pill can be
    component Zone: ColumnLayout {
        id: zone
        property string section: ""
        property string caption: ""
        property var ids: []
        Layout.fillWidth: true
        spacing: 5
        // Lift the zone holding the chip being dragged, so its face is not
        // drawn underneath a neighbouring plate on the way out.
        z: (tab.draggingId !== "" && zone.ids.indexOf(tab.draggingId) !== -1) ? 10 : 0

        Text {
            text: zone.caption
            color: Services.Colors.ash
            font.pixelSize: 10
            font.bold: true
            font.family: "JetBrainsMono NF"
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 48
            radius: 12
            color: dropZone.containsDrag ? Services.Colors.ghostAlpha(0.16)
                                         : Services.Colors.ghostAlpha(0.05)
            border.color: dropZone.containsDrag ? Services.Colors.ghostAlpha(0.4) : "transparent"
            border.width: 1
            Behavior on color { ColorAnimation { duration: 140 } }

            DropArea {
                id: dropZone
                anchors.fill: parent
                onDropped: function(drop) {
                    const id = drop.source ? (drop.source.pillId || "") : ""
                    if (id === "") return
                    Services.Prefs.moveBarPill(id, zone.section, zone.indexAt(drop.x))
                    drop.accept()
                }
            }

            Row {
                id: chipRow
                // Each zone lays its chips out the way the bar will: left packs
                // to the left, right packs to the right, centre sits in the
                // middle. The editor then reads as a small picture of the bar
                // rather than three identical lists.
                //
                // Computed x, never conditional anchors: `anchors.left: cond ?
                // parent.left : undefined` does not release the anchor, and a
                // row anchored both ways stretches edge to edge.
                x: zone.section === "right"  ? parent.width - width - 10
                 : zone.section === "centre" ? (parent.width - width) / 2
                 : 10
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6
                Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

                Repeater {
                    model: zone.ids
                    delegate: PillChip {
                        required property var modelData
                        pillId: modelData
                    }
                }
            }

            Text {
                anchors.centerIn: parent
                visible: zone.ids.length === 0
                text: "drop here"
                color: Services.Colors.ash
                font.pixelSize: 10
                font.family: "JetBrainsMono NF"
            }
        }

        // Where in the row a drop at `px` belongs: before the first chip whose
        // middle it has already passed.
        function indexAt(px) {
            const kids = chipRow.children
            let n = 0
            for (let i = 0; i < kids.length; i++) {
                const c = kids[i]
                if (!c || c.width === undefined || c.width === 0) continue
                if (chipRow.x + c.x + c.width / 2 > px) return n
                n++
            }
            return n
        }
    }

    Card {
        title: "Layout"

        Text {
            text: "Drag a pill into a section to place it, and along a section to order it. Anything left in Available is not built at all."
            color: Services.Colors.ash
            font.pixelSize: 10
            font.family: "JetBrainsMono NF"
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
            Layout.bottomMargin: 4
        }

        Zone { section: "left";   caption: "LEFT";   ids: Services.Prefs.barPills("left") }
        Zone { section: "centre"; caption: "CENTRE \u2014 the clock holds the exact middle; its neighbours fall either side"; ids: Services.Prefs.barPills("centre") }
        Zone { section: "right";  caption: "RIGHT";  ids: Services.Prefs.barPills("right") }
        Zone { section: "";       caption: "AVAILABLE"; ids: tab.availablePills }

        Item { Layout.preferredHeight: 2 }

        Text {
            text: "Reset to the shipped arrangement"
            color: resetHover.containsMouse ? Services.Colors.snow : Services.Colors.ash
            font.pixelSize: 10
            font.family: "JetBrainsMono NF"
            Behavior on color { ColorAnimation { duration: 140 } }
            MouseArea {
                id: resetHover
                anchors.fill: parent
                anchors.margins: -4
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Services.Prefs.resetBarLayout()
            }
        }
    }


    Card {
        title: "Clock & Weather"
        RowLayout {
            Layout.fillWidth: true
            spacing: 12
            RowGlyph { glyph: "\uefd6" }        // access_time
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Text { text: "Time Format"; color: Services.Colors.snow; font.pixelSize: 13; font.family: "JetBrainsMono NF" }
                Text { text: tab.timePreview; color: Services.Colors.ash; font.pixelSize: 10; font.family: "JetBrainsMono NF" }
            }
            Segmented {
                options: [
                    { id: "24", label: "24H" },
                    { id: "12", label: "12H" },
                ]
                current: Services.Prefs.clock24h ? "24" : "12"
                onPicked: id => Services.Prefs.clock24h = (id === "24")
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 12
            RowGlyph { glyph: "\ue425" }        // timer
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Text { text: "Show Seconds"; color: Services.Colors.snow; font.pixelSize: 13; font.family: "JetBrainsMono NF" }
                Text { text: "Ticks the clock every second"; color: Services.Colors.ash; font.pixelSize: 10; font.family: "JetBrainsMono NF" }
            }
            Toggle {
                checked: Services.Prefs.clockSeconds
                onToggled: Services.Prefs.clockSeconds = !Services.Prefs.clockSeconds
            }
        }

        SectionLabel { text: "Weather"; Layout.topMargin: 4 }
        RowLayout {
            Layout.fillWidth: true
            spacing: 12
            RowGlyph { glyph: "\uf076" }        // thermostat
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Text { text: "Temperature"; color: Services.Colors.snow; font.pixelSize: 13; font.family: "JetBrainsMono NF" }
                Text { text: "Now: " + Services.Weather.temp; color: Services.Colors.ash; font.pixelSize: 10; font.family: "JetBrainsMono NF" }
            }
            Segmented {
                options: [
                    { id: "C", label: "°C" },
                    { id: "F", label: "°F" },
                    { id: "K", label: "K" },
                ]
                current: Services.Prefs.tempUnit
                onPicked: id => Services.Prefs.tempUnit = id
            }
        }

        RowLayout {
            Layout.fillWidth: true
            SectionLabel { text: "Location"; Layout.fillWidth: true }
            SectionLabel {
                text: Services.Weather.cityError
                    ? "No matches - try another name"
                    : (Services.Weather.city !== "" ? Services.Weather.city : "Auto (by IP)")
                color: Services.Weather.cityError ? Services.Colors.error_ : Services.Colors.ash
            }
        }

        // Saved cities as cards (mirrors the keyboard-layout picker below):
        // click to switch the active one, X to drop it, + to add another.
        Flow {
            Layout.fillWidth: true
            spacing: 10

            Repeater {
                model: Services.Weather.savedLocs
                delegate: Rectangle {
                    id: cityCard
                    required property var modelData
                    required property int index
                    readonly property bool active: Services.Weather.activeLocIndex === cityCard.index
                    property bool hovered: false
                    implicitWidth: Math.min(cityName.implicitWidth + 44, 220)
                    height: 40
                    radius: 10
                    color: cityCard.active ? Services.Colors.ghost : Services.Colors.ghostAlpha(0.12)
                    gradient: Services.Prefs.useGradients && (cityCard.active) ? Services.Colors.accentGradient : null
                    Behavior on color { ColorAnimation { duration: 150 } }
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 8
                        spacing: 6
                        Text {
                            text: "\uf1db"                 // location_on
                            font.family: "Material Symbols Rounded"
                            font.pixelSize: 15
                            color: cityCard.active ? Services.Colors.abyss : Services.Colors.ghost
                        }
                        Text {
                            id: cityName
                            text: cityCard.modelData.city
                            color: cityCard.active ? Services.Colors.abyss : Services.Colors.snow
                            font.pixelSize: 11
                            font.family: "JetBrainsMono NF"
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        anchors.rightMargin: 20      // leave the X hit-area free
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Services.Weather.selectLoc(cityCard.index)
                    }
                    Rectangle {
                        visible: cityCard.hovered || rmCityArea.containsMouse
                        anchors.top: parent.top
                        anchors.right: parent.right
                        anchors.margins: 4
                        width: 18; height: 18; radius: 9
                        color: rmCityArea.containsMouse ? Services.Colors.ghost : Services.Colors.ghostAlpha(0.4)
                        gradient: Services.Prefs.useGradients && (rmCityArea.containsMouse) ? Services.Colors.accentGradient : null
                        Behavior on color { ColorAnimation { duration: 120 } }
                        Text {
                            anchors.centerIn: parent
                            text: "\ue5cd"           // close
                            font.family: "Material Symbols Rounded"
                            font.pixelSize: 11
                            color: Services.Colors.abyss
                        }
                        MouseArea {
                            id: rmCityArea
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            hoverEnabled: true
                            onClicked: Services.Weather.removeLoc(cityCard.index)
                        }
                    }
                    HoverHandler { onHoveredChanged: cityCard.hovered = hovered }
                }
            }

            // Add-city card: toggles the search box.
            Rectangle {
                height: 40
                implicitWidth: 92
                radius: 10
                color: addCityArea.containsMouse ? Services.Colors.ghostAlpha(0.2) : Services.Colors.ghostAlpha(0.06)
                border.color: Services.Colors.ghostAlpha(0.3)
                border.width: 1
                Behavior on color { ColorAnimation { duration: 150 } }
                RowLayout {
                    anchors.centerIn: parent
                    spacing: 4
                    Text {
                        text: "\ue145"                    // add
                        font.family: "Material Symbols Rounded"
                        font.pixelSize: 18
                        color: Services.Colors.ghost
                    }
                    Text {
                        text: "Add"
                        font.pixelSize: 10
                        font.family: "JetBrainsMono NF"
                        color: Services.Colors.mist
                    }
                }
                MouseArea {
                    id: addCityArea
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onClicked: {
                        tab.cityPickerOpen = !tab.cityPickerOpen
                        if (tab.cityPickerOpen) cityInput.forceActiveFocus()
                        else { cityInput.text = ""; Services.Weather.search("") }
                    }
                }
            }
        }

        // City search box + candidate dropdown (only while adding).
        Rectangle {
            Layout.fillWidth: true
            clip: true
            radius: 12
            color: Services.Colors.ghostAlpha(0.08)
            implicitHeight: cityPickerCol.implicitHeight + 20
            // Slide open/closed instead of snapping.
            Layout.preferredHeight: tab.cityPickerOpen ? implicitHeight : 0
            Behavior on Layout.preferredHeight { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
            opacity: tab.cityPickerOpen ? 1.0 : 0.0
            Behavior on opacity { NumberAnimation { duration: 160 } }

            ColumnLayout {
                id: cityPickerCol
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
                            text: "\ue8e2"               // search
                            font.family: "Material Symbols Rounded"
                            font.pixelSize: 15
                            color: Services.Colors.ghost
                        }
                        TextField {
                            id: cityInput
                            Layout.fillWidth: true
                            placeholderText: "Search city..."
                            color: Services.Colors.snow
                            placeholderTextColor: Services.Colors.ash
                            font.pixelSize: 12
                            font.family: "JetBrainsMono NF"
                            background: null
                            padding: 0
                            onTextChanged: cityDebounce.restart()
                            Keys.onEscapePressed: { tab.cityPickerOpen = false; text = "" }
                            onAccepted: {
                                let r = Services.Weather.searchResults
                                if (r.length > 0) {
                                    Services.Weather.chooseResult(r[0].lat, r[0].lon, r[0].label)
                                    text = ""
                                    tab.cityPickerOpen = false
                                }
                            }
                        }
                    }
                }

                // Candidate dropdown (name + region/country); one tap to add.
                Repeater {
                    model: Services.Weather.searchResults
                    delegate: Rectangle {
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.preferredHeight: 38
                        radius: 8
                        color: sugArea.containsMouse ? Services.Colors.ghostAlpha(0.18) : Services.Colors.ghostAlpha(0.06)
                        Behavior on color { ColorAnimation { duration: 120 } }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 10
                            Text {
                                text: "\uf1db"            // location_on
                                font.family: "Material Symbols Rounded"
                                font.pixelSize: 14
                                color: Services.Colors.ghost
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0
                                Text {
                                    text: modelData.label
                                    color: Services.Colors.snow
                                    font.pixelSize: 12
                                    font.family: "JetBrainsMono NF"
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                                Text {
                                    text: modelData.detail
                                    visible: text !== ""
                                    color: Services.Colors.ash
                                    font.pixelSize: 9
                                    font.family: "JetBrainsMono NF"
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                            }
                        }
                        MouseArea {
                            id: sugArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                Services.Weather.chooseResult(modelData.lat, modelData.lon, modelData.label)
                                cityInput.text = ""
                                tab.cityPickerOpen = false
                            }
                        }
                    }
                }
            }
        }

        // Debounce keystrokes so the geocoder isn't hit on every letter.
        Timer {
            id: cityDebounce
            interval: 350
            onTriggered: Services.Weather.search(cityInput.text)
        }

    }

    Item { Layout.preferredHeight: 8 }
}
