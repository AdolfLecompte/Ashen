import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import "root:/modules/widgets" as Widgets
import "root:/services" as Services

Scope {
    id: root

    Component.onCompleted: appLoader.running = true

    PanelWindow {
        id: win
        anchors { top: true; left: true; right: true; bottom: true }
        screen: Services.Screens.active
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        // stays mapped through the close animation, so the exit plays in reverse
        readonly property bool shown: Services.AppState.launcherVisible
        visible: shown || closeDelay.running
        onShownChanged: {
            if (!shown) { closeDelay.restart(); return }
            searchField.text = ""
            focusArm.restart()
            // Rescan every open, not just the first: picks up installs/uninstalls
            // without needing a shell restart. Guard against overlapping runs.
            if (!appLoader.running) appLoader.running = true
        }
        // Long enough for the whole exit: the window used to unmap at 300 ms
        // while the collapse still had 220 to run, which cut it dead.
        Timer { id: closeDelay; interval: arrive.holdMs }
        // The card's contents are held back until the drop has landed, and an
        // item that is not on screen cannot take focus.
        Timer {
            id: focusArm
            interval: Services.Sizes.panelArmMs + 40
            onTriggered: searchField.forceActiveFocus()
        }

        WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        property string searchText: ""
        property var allApps: []
        property string activeCategory: "All"
        property int selectedIndex: 0

        function moveCategory(dir) {
            let ids = win.categories.map(c => c.id)
            let idx = ids.indexOf(win.activeCategory)
            idx = (idx + dir + ids.length) % ids.length
            win.activeCategory = ids[idx]
            win.selectedIndex = 0
        }
        function moveSelection(dir) {
            let count = win.filteredApps.length
            if (count === 0) return
            win.selectedIndex = Math.max(0, Math.min(count - 1, win.selectedIndex + dir))
            appList.positionViewAtIndex(win.selectedIndex, ListView.Contain)
        }
        function launchSelected() {
            if (win.filteredApps.length === 0) return
            let app = win.filteredApps[Math.min(win.selectedIndex, win.filteredApps.length - 1)]
            Quickshell.execDetached(["sh", "-c", app.exec])
            Services.AppState.launcherVisible = false
        }
        property var categories: [
           { id: "All", icon: "\ue5c3" },
           { id: "Internet", icon: "\ue80b" },
           { id: "Development", icon: "\ue86f" },
           { id: "System", icon: "\ue322" },
           { id: "Utility", icon: "\ue869" },
           { id: "Games", icon: "\uea28" },
           { id: "Graphics", icon: "\ue3f4" },
           { id: "Office", icon: "\uef42" },
           { id: "Other", icon: "\ue5d3" },
       ]

        property var filteredApps: {
            let apps = allApps
            if (activeCategory !== "All") {
                apps = apps.filter(a => a.category === activeCategory)
            }
            if (searchText.length > 0) {
                let q = searchText.toLowerCase()
                // Rank by how the query matches the NAME first; a comment-only hit
                // is kept but sinks to the bottom. Lower score = better. allApps is
                // already alphabetical and the sort is stable, so ties stay A→Z.
                function score(a) {
                    let n = a.name.toLowerCase()
                    if (n === q) return 0                                       // exact
                    if (n.startsWith(q)) return 1                               // name starts with query
                    if (n.split(/[\s\-_]+/).some(w => w.startsWith(q))) return 2 // a word starts with query
                    if (n.includes(q)) return 3                                 // name contains query
                    if (a.comment.toLowerCase().includes(q)) return 4           // only the description matches
                    return 5                                                    // no match
                }
                apps = apps.map(a => ({ app: a, s: score(a) }))
                           .filter(x => x.s < 5)
                           .sort((x, y) => x.s - y.s)
                           .map(x => x.app)
            }
            return apps.slice(0, 50)
        }

        // Apps are loaded in a single process (find + parse) instead of two sequential trips.
        // Preloaded when quickshell starts (Scope's Component.onCompleted) so the list
        // is already there the first time the launcher opens, then re-run on every
        // subsequent open (toggle() above) to pick up installs/uninstalls since last scan.
        Process {
            id: appLoader
            command: ["sh", "-c",
                // Walk XDG_DATA_HOME + XDG_DATA_DIRS, not two hardcoded paths: flatpak
                // exports under dirs the old find never saw. Line by line, because Steam's
                // shortcuts have spaces; deduped by desktop id, earlier dirs winning.
                "seen=''; for d in \"${XDG_DATA_HOME:-$HOME/.local/share}\" $(echo \"${XDG_DATA_DIRS:-/usr/local/share:/usr/share}\" | tr ':' ' '); do [ -d \"$d/applications\" ] || continue; find \"$d/applications\" -name '*.desktop' 2>/dev/null; done | while IFS= read -r f; do id=${f##*/}; case \" $seen \" in *\" $id \"*) continue ;; esac; seen=\"$seen $id\"; echo '---'; grep -E '^(Name|Comment|Exec|Icon|Categories|NoDisplay)=' \"$f\" 2>/dev/null; done"
            ]
            running: false
            stdout: StdioCollector {
                onStreamFinished: {
                    let apps = []
                    let blocks = text.split("---").filter(b => b.trim().length > 0)
                    for (let block of blocks) {
                        let lines = block.trim().split("\n")
                        let app = { name: "", comment: "", exec: "", icon: "", category: "Other", noDisplay: false }
                        for (let line of lines) {
                            if (line.startsWith("Name=") && app.name === "") app.name = line.substring(5).trim()
                            else if (line.startsWith("Comment=") && app.comment === "") app.comment = line.substring(8).trim()
                            // @@u/@@ are flatpak's file-forwarding markers; with no file
                            // args left after the field codes go, they are dead weight
                            else if (line.startsWith("Exec=") && app.exec === "") app.exec = line.substring(5).trim().replace(/ %[uUfFdDnNickvm]/g, "").replace(/ @@[uU]?(?= |$)/g, "")
                            else if (line.startsWith("Icon=") && app.icon === "") app.icon = line.substring(5).trim()
                            else if (line.startsWith("Categories=") && app.category === "Other") {
                                let cats = line.substring(11).split(";")
                                if (cats.some(c => ["WebBrowser","Network","Email"].includes(c))) app.category = "Internet"
                                else if (cats.some(c => ["Development","IDE"].includes(c))) app.category = "Development"
                                else if (cats.some(c => ["System","Settings","PackageManager"].includes(c))) app.category = "System"
                                else if (cats.some(c => ["Utility","Accessibility"].includes(c))) app.category = "Utility"
                                else if (cats.some(c => ["Game","Games"].includes(c))) app.category = "Games"
                                else if (cats.some(c => ["Graphics","Photography"].includes(c))) app.category = "Graphics"
                                else if (cats.some(c => ["Office","Spreadsheet"].includes(c))) app.category = "Office"
                            }
                            else if (line.startsWith("NoDisplay=true")) app.noDisplay = true
                        }
                        if (app.name.length > 0 && !app.noDisplay && app.exec.length > 0) {
                            apps.push(app)
                        }
                    }
                    apps.sort((a, b) => a.name.localeCompare(b.name))
                    win.allApps = apps
                }
            }
        }

        Timer {
            id: themeTimer
            interval: 150
            repeat: false
            onTriggered: Services.AppState.wallpaperVisible = true
        }


        MouseArea {
            anchors.fill: parent
            z: -1
            onClicked: Services.AppState.launcherVisible = false
        }

        // Which end of the screen it rests at: the one the bar is not on.
        readonly property string srcEdge:
            Services.Sizes.barPosition === "bottom" ? "top" : "bottom"

        // Rests near that edge, at the same offset as the drawer and Process,
        // so all of them sit at the same height.
        readonly property real openYCalc: win.srcEdge === "bottom"
            ? win.height - card.fullH - Math.max(68, Services.Sizes.marginBottom + 18)
            : Services.Sizes.panelTop

        // Contents assemble in three beats once the box has opened.
        function stage(i) {
            const start = Math.min(0.5, i * 0.14)
            return Math.max(0, Math.min(1, (arrive.contentAmt - start) / (1 - start)))
        }
        function riseOf(i) { return (1 - win.stage(i)) * 10 }

        Widgets.PanelArrive {
            id: arrive
            shown: win.shown
            // Comes up off the bottom, whichever end it rests at.
            rise: 48
        }

        Rectangle {
            id: card
            // What it opens to; the box unfolds into these.
            readonly property int fullW: 700
            readonly property int fullH: contentCol.height + 32

            x: arrive.boxX((win.width - fullW) / 2, fullW)
            y: arrive.boxY(win.openYCalc, fullH)
            width: arrive.boxW(fullW)
            height: arrive.boxH(fullH)
            radius: Services.Sizes.panelR
            color: Services.Colors.surfacePanel
            clip: true
            opacity: arrive.fade
            transform: Translate { y: arrive.offY }

            MouseArea { anchors.fill: parent; onClicked: {} }

            Column {
                id: contentCol
                // Sized to the card's final width, not anchored to it: while the
                // pill grows, anchoring would re-wrap the whole list per frame.
                x: 16
                y: 16
                width: card.fullW - 32
                spacing: 12

                // Search bar
                Rectangle {
                    opacity: win.stage(0)
                    transform: Translate { y: win.riseOf(0) }
                    width: parent.width
                    height: 52
                    radius: 10
                    color: Services.Colors.ghostAlpha(0.1)
                    border.color: searchField.activeFocus ? Services.Colors.ghost : Services.Colors.ghostAlpha(0.2)
                    border.width: 1
                    Behavior on border.color { ColorAnimation { duration: Services.Sizes.msMicro } }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 16
                        anchors.rightMargin: 16
                        spacing: 12

                        Text {
                            text: "\ue8b6"
                            color: Services.Colors.ghost
                            font.pixelSize: 22
                            font.family: "Material Symbols Rounded"
                        }

                        Item {
                            Layout.fillWidth: true
                            height: 30

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Search applications..."
                                color: Services.Colors.ash
                                font.pixelSize: Services.Sizes.fsSectionTitle
                                font.family: "JetBrainsMono NF"
                                visible: searchField.text.length === 0
                            }

                            TextInput {
                                id: searchField
                                anchors.fill: parent
                                color: Services.Colors.snow
                                font.pixelSize: Services.Sizes.fsSectionTitle
                                font.family: "JetBrainsMono NF"
                                focus: Services.AppState.launcherVisible
                                verticalAlignment: TextInput.AlignVCenter
                                onTextChanged: { win.searchText = text; win.selectedIndex = 0 }
                                Keys.onEscapePressed: Services.AppState.launcherVisible = false
                                Keys.onReturnPressed: win.launchSelected()
                                Keys.onUpPressed: win.moveSelection(-1)
                                Keys.onDownPressed: win.moveSelection(1)
                                Keys.onLeftPressed: win.moveCategory(-1)
                                Keys.onRightPressed: win.moveCategory(1)
                            }
                        }

                        Widgets.IconButton {
                            size: 24
                            glyph: "\ue5cd"
                            visible: searchField.text.length > 0
                            onActivated: searchField.text = ""
                        }
                    }
                }

                // Categories -- sliding indicator, workspace-style.
                Item {
                    id: catSelect
                    opacity: win.stage(1)
                    transform: Translate { y: win.riseOf(1) }
                    width: parent.width
                    height: 30
                    property Item activeCat: null

                    // Sliding highlight behind the active category (workspace-style)
                    Rectangle {
                        visible: catSelect.activeCat !== null
                        x: catSelect.activeCat ? catSelect.activeCat.x : 0
                        width: catSelect.activeCat ? catSelect.activeCat.width : 0
                        height: 30
                        radius: 8
                        color: Services.Colors.ghost
                        gradient: Services.Prefs.useGradients ? Services.Colors.accentGradient : null
                        Behavior on x { SmoothedAnimation { duration: Services.Sizes.msPronounced } }
                    }

                    RowLayout {
                        anchors.fill: parent
                        spacing: 6
                        Repeater {
                            model: win.categories
                            delegate: Rectangle {
                                required property var modelData
                                readonly property bool active: win.activeCategory === modelData.id
                                onActiveChanged: if (active) catSelect.activeCat = this
                                Component.onCompleted: if (active) catSelect.activeCat = this
                                Layout.fillWidth: true
                                height: 30
                                radius: 8
                                // Only the sliding indicator carries the active fill;
                                // idle slots are bare (hover just brightens them).
                                color: active ? "transparent"
                                    : catHover.containsMouse ? Services.Colors.ghostAlpha(0.15) : "transparent"
                                Behavior on color { ColorAnimation { duration: Services.Sizes.msMicro } }

                                Text {
                                    anchors.fill: parent
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                    text: modelData.icon
                                    color: active ? Services.Colors.accentText : Services.Colors.mist
                                    font.pixelSize: 16
                                    font.family: "Material Symbols Rounded"
                                }

                                MouseArea {
                                    id: catHover
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: win.activeCategory = modelData.id
                                }
                            }
                        }
                    }
                }

                // The app list, last to assemble.
                Rectangle {
                    id: listBox
                    opacity: win.stage(2)
                    transform: Translate { y: win.riseOf(2) }
                    width: parent.width
                    height: 6 * 62
                    color: "transparent"
                    clip: true

                    ListView {
                        id: appList
                        anchors.fill: parent
                        model: win.filteredApps
                        spacing: 2
                        clip: true

                        ScrollBar.vertical: ScrollBar {
                            policy: appList.contentHeight > appList.height ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
                            width: 4
                        }

                        delegate: Rectangle {
                            required property var modelData
                            required property int index
                            width: appList.width
                            height: 60
                            radius: 8
                            // Fill alone marks the selection; the outline read as
                            // a glow and nothing else in the shell frames a row.
                            color: index === win.selectedIndex ? Services.Colors.ghostAlpha(0.18) : "transparent"
                            border.width: 0
                            Behavior on color { ColorAnimation { duration: Services.Sizes.msInstant } }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                spacing: 14

                                // ── Icono: comando (glyph directo) o app (imagen + fallback) ──
                                Rectangle {
                                    width: 40; height: 40
                                    radius: 10
                                    color: Services.Colors.ghostAlpha(0.15)

                                    Image {
                                        id: appImg
                                        anchors.fill: parent
                                        anchors.margins: 6
                                        source: modelData.icon ? (modelData.icon.startsWith("/") ? ("file://" + modelData.icon) : Quickshell.iconPath(modelData.icon, 48)) : ""
                                        fillMode: Image.PreserveAspectFit
                                        visible: status === Image.Ready
                                        opacity: 0.85
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        text: "\ue5c3"
                                        color: Services.Colors.ghost
                                        font.pixelSize: 22
                                        font.family: "Material Symbols Rounded"
                                        visible: appImg.status !== Image.Ready
                                    }
                                }

                                Column {
                                    Layout.fillWidth: true
                                    spacing: 3

                                    Text {
                                        text: modelData.name
                                        color: Services.Colors.snow
                                        font.pixelSize: Services.Sizes.fsCardTitle
                                        font.family: "JetBrainsMono NF"
                                        font.bold: true
                                        elide: Text.ElideRight
                                        width: parent.width
                                    }
                                    Text {
                                        text: modelData.comment
                                        color: Services.Colors.mist
                                        font.pixelSize: Services.Sizes.fsBody
                                        font.family: "JetBrainsMono NF"
                                        elide: Text.ElideRight
                                        width: parent.width
                                        visible: modelData.comment.length > 0
                                    }
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                hoverEnabled: true
                                onEntered: win.selectedIndex = index
                                onClicked: {
                                    Quickshell.execDetached(["sh", "-c", modelData.exec])
                                    Services.AppState.launcherVisible = false
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
