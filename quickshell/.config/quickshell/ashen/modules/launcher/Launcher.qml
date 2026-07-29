import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

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
            searchField.forceActiveFocus()
            // Rescan every open, not just the first: picks up installs/uninstalls
            // without needing a shell restart. Guard against overlapping runs.
            if (!appLoader.running) appLoader.running = true
        }
        Timer { id: closeDelay; interval: 300 }

        WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        property string searchText: ""
        property var allApps: []
        property string activeCategory: "All"
        property int selectedIndex: 0

        // Command mode: active when the search starts with ">"
        property bool commandMode: searchText.startsWith(">")
        onCommandModeChanged: swapFade.restart()
        property string commandQuery: commandMode ? searchText.substring(1).toLowerCase().trim() : ""
        property var commandActions: [
            { id: "settings",  icon: "\ue8b8", label: "Settings",        action: "settings" },
            { id: "wallpaper", icon: "\ue1bc", label: "Wallpaper",       action: "wallpaper" },
            { id: "theme",     icon: "\ue40a", label: "Theme",           action: "theme" },
            { id: "clipboard", icon: "\ue14f", label: "Clipboard",       action: "clipboard" },
            { id: "emoji",     icon: "\uea22", label: "Emoji",           action: "emoji" },
            { id: "glyph",     icon: "\ue167", label: "Glyphs",          action: "glyph" },
            { id: "record",    icon: "\uf679", label: "Record",          action: "record" },
            { id: "processes", icon: "\ue322", label: "Processes",       action: "processes" },
            { id: "lock",      icon: "\ue899", label: "Lock",            action: "lock" },
            { id: "power",     icon: "\uf8c7", label: "Power",           action: "power" },
            { id: "caffeine",  icon: "\uefef", label: "Keep Awake",      action: "caffeine" },
            { id: "dnd",       icon: "\uf08f", label: "Do Not Disturb",  action: "dnd" },
            { id: "nightlight", icon: "\ue51c", label: "Night Light",    action: "nightlight" },
        ]
        property var filteredCommands: {
            if (commandQuery.length === 0) return commandActions
            return commandActions.filter(c => c.label.toLowerCase().includes(commandQuery))
        }

        function moveCategory(dir) {
            if (win.commandMode) return
            let ids = win.categories.map(c => c.id)
            let idx = ids.indexOf(win.activeCategory)
            idx = (idx + dir + ids.length) % ids.length
            win.activeCategory = ids[idx]
            win.selectedIndex = 0
        }
        function moveSelection(dir) {
            let count = win.commandMode ? win.filteredCommands.length : win.filteredApps.length
            if (count === 0) return
            win.selectedIndex = Math.max(0, Math.min(count - 1, win.selectedIndex + dir))
            appList.positionViewAtIndex(win.selectedIndex, ListView.Contain)
        }
        function runCommand(cmd) {
            Services.AppState.launcherVisible = false
            switch (cmd.action) {
                case "settings":  Services.AppState.settingsVisible = true; break
                case "theme":     Services.AppState.settingsTab = "theme"; Services.AppState.settingsVisible = true; break
                case "record":    Services.AppState.toggleRecording(); break
                case "wallpaper": Services.AppState.wallpaperVisible = true; break
                case "clipboard": Services.AppState.clipboardVisible = true; break
                case "emoji":     Services.AppState.emojisVisible = true; break
                case "glyph":     Services.AppState.glyphVisible = true; break
                case "processes": Services.AppState.processVisible = true; break
                case "power":     Services.AppState.powerMenuVisible = true; break
                case "lock":      Quickshell.execDetached(["loginctl", "lock-session"]); break
                case "caffeine":  Services.AppState.keepAwake = !Services.AppState.keepAwake; break
                case "dnd":       Services.AppState.doNotDisturb = !Services.AppState.doNotDisturb; break
                case "nightlight": Services.NightLight.toggle(); break
            }
        }
        function launchSelected() {
            if (win.commandMode) {
                if (win.filteredCommands.length === 0) return
                let cmd = win.filteredCommands[Math.min(win.selectedIndex, win.filteredCommands.length - 1)]
                win.runCommand(cmd)
                return
            }
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
                // walk XDG_DATA_HOME + XDG_DATA_DIRS instead of hardcoding two paths:
                // flatpak exports its .desktop files under /var/lib/flatpak/exports/share
                // (and ~/.local/share/flatpak/... for user installs), which are in
                // XDG_DATA_DIRS but were invisible to the old find.
                // Read the paths line by line: Steam's shortcuts have spaces in
                // their filenames ("Gun Devil.desktop") and $(find) would split them.
                // Earlier dirs win, per the XDG spec, so dedupe by desktop id.
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

        Rectangle {
            anchors.centerIn: parent
            width: 700
            height: contentCol.height + 32
            radius: 16
            color: Services.Colors.surfaceAlpha(0.96)
            border.color: Services.Colors.ghostAlpha(0.2)
            border.width: 0
            clip: true

            opacity: Services.AppState.launcherVisible ? 1.0 : 0.0
            scale: Services.AppState.launcherVisible ? 1.0 : 0.96
            transform: Translate {
                y: Services.AppState.launcherVisible ? 0 : 20
                Behavior on y { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
            }
            Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
            Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

            MouseArea { anchors.fill: parent; onClicked: {} }

            Column {
                id: contentCol
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 16
                spacing: 12

                // Search bar
                Rectangle {
                    width: parent.width
                    height: 52
                    radius: 10
                    color: Services.Colors.ghostAlpha(0.1)
                    border.color: searchField.activeFocus ? Services.Colors.ghost : Services.Colors.ghostAlpha(0.2)
                    border.width: 1
                    Behavior on border.color { ColorAnimation { duration: 150 } }

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
                                text: "Search applications, or type > for actions..."
                                color: Services.Colors.ash
                                font.pixelSize: 16
                                font.family: "JetBrainsMono NF"
                                visible: searchField.text.length === 0
                            }

                            TextInput {
                                id: searchField
                                anchors.fill: parent
                                color: Services.Colors.snow
                                font.pixelSize: 16
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

                        Text {
                            text: "\ue5cd"
                            color: Services.Colors.ash
                            font.pixelSize: 20
                            font.family: "Material Symbols Rounded"
                            visible: searchField.text.length > 0
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: searchField.text = ""
                            }
                        }
                    }
                }

                // Categorias -- indicador deslizante. En modo comando se desvanecen
                // pero conservan su alto, para que el panel no cambie de tamaño.
                Item {
                    id: catSelect
                    width: parent.width
                    height: 30
                    opacity: win.commandMode ? 0 : 1
                    enabled: !win.commandMode
                    Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
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
                        Behavior on x { SmoothedAnimation { duration: 250 } }
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
                                Behavior on color { ColorAnimation { duration: 150 } }

                                Text {
                                    anchors.fill: parent
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                    text: modelData.icon
                                    color: active ? Services.Colors.abyss : Services.Colors.mist
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

                // List: apps or commands, depending on the mode
                Rectangle {
                    id: listBox
                    width: parent.width
                    height: 6 * 62
                    color: "transparent"
                    clip: true

                    // Fade the content in when switching apps <-> commands.
                    NumberAnimation {
                        id: swapFade
                        target: listBox; property: "opacity"
                        from: 0.0; to: 1.0; duration: 180; easing.type: Easing.OutCubic
                    }

                    ListView {
                        id: appList
                        anchors.fill: parent
                        model: win.commandMode ? win.filteredCommands : win.filteredApps
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
                            Behavior on color { ColorAnimation { duration: 100 } }

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
                                    visible: win.commandMode

                                    Text {
                                        anchors.centerIn: parent
                                        text: win.commandMode ? modelData.icon : ""
                                        color: Services.Colors.ghost
                                        font.pixelSize: 20
                                        font.family: "Material Symbols Rounded"
                                    }
                                }
                                Rectangle {
                                    width: 40; height: 40
                                    radius: 10
                                    color: Services.Colors.ghostAlpha(0.15)
                                    visible: !win.commandMode

                                    Image {
                                        id: appImg
                                        anchors.fill: parent
                                        anchors.margins: 6
                                        source: !win.commandMode && modelData.icon ? (modelData.icon.startsWith("/") ? ("file://" + modelData.icon) : Quickshell.iconPath(modelData.icon, 48)) : ""
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
                                        text: win.commandMode ? modelData.label : modelData.name
                                        color: Services.Colors.snow
                                        font.pixelSize: 14
                                        font.family: "JetBrainsMono NF"
                                        font.bold: true
                                        elide: Text.ElideRight
                                        width: parent.width
                                    }
                                    Text {
                                        text: modelData.comment
                                        color: Services.Colors.mist
                                        font.pixelSize: 11
                                        font.family: "JetBrainsMono NF"
                                        elide: Text.ElideRight
                                        width: parent.width
                                        visible: !win.commandMode && modelData.comment.length > 0
                                    }
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                hoverEnabled: true
                                onEntered: win.selectedIndex = index
                                onClicked: {
                                    if (win.commandMode) {
                                        win.runCommand(modelData)
                                    } else {
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
}
