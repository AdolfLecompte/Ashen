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
        target: "launcher"
        function toggle() {
            Services.AppState.toggleOverlay("launcherVisible")
            if (Services.AppState.launcherVisible) {
                searchField.text = ""
                searchField.forceActiveFocus()
                appLoader.running = true
            }
        }
    }

    PanelWindow {
        id: win
        anchors { top: true; left: true; right: true; bottom: true }
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        visible: Services.AppState.launcherVisible

        WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

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
            if (win.filteredApps.length === 0) return
            win.selectedIndex = Math.max(0, Math.min(win.filteredApps.length - 1, win.selectedIndex + dir))
            appList.positionViewAtIndex(win.selectedIndex, ListView.Contain)
        }
        function launchSelected() {
            if (win.filteredApps.length === 0) return
            let app = win.filteredApps[Math.min(win.selectedIndex, win.filteredApps.length - 1)]
            Quickshell.execDetached(["sh", "-c", app.exec])
            Services.AppState.launcherVisible = false
        }
        property var categories: [
           { id: "All", icon: "" },
           { id: "Internet", icon: "" },
           { id: "Development", icon: "" },
           { id: "System", icon: "" },
           { id: "Utility", icon: "" },
           { id: "Games", icon: "" },
           { id: "Graphics", icon: "" },
           { id: "Office", icon: "" },
           { id: "Other", icon: "" },
       ]

        property var filteredApps: {
            let apps = allApps
            if (activeCategory !== "All") {
                apps = apps.filter(a => a.category === activeCategory)
            }
            if (searchText.length > 0) {
                let q = searchText.toLowerCase()
                apps = apps.filter(a =>
                    a.name.toLowerCase().includes(q) ||
                    a.comment.toLowerCase().includes(q)
                )
            }
            return apps.slice(0, 50)
        }

        Process {
            id: appLoader
            command: ["sh", "-c", "find /usr/share/applications ~/.local/share/applications -name '*.desktop' 2>/dev/null | head -200"]
            running: false
            stdout: StdioCollector {
                onStreamFinished: {
                    let files = text.trim().split("\n").filter(f => f.length > 0)
                    win.loadApps(files)
                }
            }
        }

        function loadApps(files) {
            desktopReader.command = ["sh", "-c",
                "for f in " + files.join(" ") + "; do " +
                "echo '---'; " +
                "grep -E '^(Name|Comment|Exec|Icon|Categories|NoDisplay)=' \"$f\" 2>/dev/null; " +
                "done"
            ]
            desktopReader.running = true
        }

        Process {
            id: desktopReader
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
                            else if (line.startsWith("Exec=") && app.exec === "") app.exec = line.substring(5).trim().replace(/ %[uUfFdDnNickvm]/g, "")
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
            width: 620
            height: 480
            radius: 16
            color: Services.Colors.surfaceAlpha(0.96)
            border.color: Services.Colors.ghostAlpha(0.2)
            border.width: 1
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
                            text: ""
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
                            text: ""
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

                // Categorias
                RowLayout {
                    width: parent.width
                    spacing: 6
                    Repeater {
                        model: win.categories
                        delegate: Rectangle {
                       required property var modelData
                       Layout.fillWidth: true
                       height: 30
                       radius: 8
                       color: win.activeCategory === modelData.id ? Services.Colors.ghost : Services.Colors.ghostAlpha(0.15)
                       Behavior on color { ColorAnimation { duration: 150 } }

                       Text {
                           anchors.fill: parent
                           horizontalAlignment: Text.AlignHCenter
                           verticalAlignment: Text.AlignVCenter
                           text: modelData.icon
                           color: win.activeCategory === modelData.id ? Services.Colors.abyss : Services.Colors.mist
                           font.pixelSize: 16
                           font.family: "Material Symbols Rounded"
                       }

                       MouseArea {
                           anchors.fill: parent
                           cursorShape: Qt.PointingHandCursor
                           onClicked: win.activeCategory = modelData.id
                       }
                   }
                    }
                }

                // Lista apps
                Rectangle {
                    width: parent.width
                    height: 4 * 62
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
                            color: index === win.selectedIndex ? Services.Colors.ghostAlpha(0.18) : "transparent"
                            border.color: index === win.selectedIndex ? Services.Colors.ghostAlpha(0.4) : "transparent"
                            border.width: 1
                            Behavior on color { ColorAnimation { duration: 100 } }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                spacing: 14

                                Rectangle {
                                    width: 40; height: 40
                                    radius: 10
                                    color: Services.Colors.ghostAlpha(0.15)

                                    Image {
                                        id: appImg
                                        anchors.fill: parent
                                        anchors.margins: 6
                                        source: modelData.icon.startsWith("/") ? ("file://" + modelData.icon) : Quickshell.iconPath(modelData.icon, 48)
                                        fillMode: Image.PreserveAspectFit
                                        visible: status === Image.Ready
                                        opacity: 0.85
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        text: ""
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

                // Separador
                Rectangle {
                    width: parent.width
                    height: 1
                    color: Services.Colors.ghostAlpha(0.15)
                }

                // Accesos rapidos
                Row {
                    width: parent.width
                    spacing: 8

                    Repeater {
                        model: [
                            { icon: "", label: "Settings", action: "settings", cmd: "" },
                            { icon: "", label: "Record", action: "record", cmd: "" },
                            { icon: "",    label: "Theme",   action: "theme", cmd: "" },
                        ]

                        delegate: Rectangle {
                            required property var modelData
                            height: 40
                            width: (contentCol.width - 16) / 3
                            radius: 8
                            color: Services.Colors.ghostAlpha(0.1)
                            Behavior on color { ColorAnimation { duration: 150 } }

                            RowLayout {
                                anchors.centerIn: parent
                                spacing: 8
                                Text {
                                    text: modelData.icon
                                    color: Services.Colors.ghost
                                    font.pixelSize: 18
                                    font.family: "Material Symbols Rounded"
                                }
                                Text {
                                    text: modelData.label
                                    color: Services.Colors.mist
                                    font.pixelSize: 12
                                    font.family: "JetBrainsMono NF"
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                hoverEnabled: true
                                onEntered: parent.color = Services.Colors.ghostAlpha(0.2)
                                onExited: parent.color = Services.Colors.ghostAlpha(0.1)
                                onClicked: {
                                    console.log("Action:", modelData.action, modelData.label)
                                    if (modelData.action === "theme") {
                                        Services.AppState.launcherVisible = false
                                        Services.AppState.settingsTab = "theme"
                                        Services.AppState.settingsVisible = true
                                    } else if (modelData.action === "record") {
                                        Services.AppState.launcherVisible = false
                                        let path = "/home/adolf-arch/Videos/ashen_" + Date.now() + ".mp4"
                                        let startMs = Date.now()
                                        Quickshell.execDetached(["sh", "-c",
                                            "mkdir -p /home/adolf-arch/Videos; wf-recorder -f '" + path + "' & echo $! > /home/adolf-arch/.cache/ashen_recording.pid; echo " + startMs + " > /home/adolf-arch/.cache/ashen_recording_start"
                                        ])
                                        Services.AppState.recording = true
                                        Services.AppState.recordingStartTime = startMs
                                    } else if (modelData.action === "settings") {
                                        Services.AppState.launcherVisible = false
                                        Services.AppState.settingsVisible = true
                                    } else {
                                        Quickshell.execDetached(["sh", "-c", modelData.cmd])
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
