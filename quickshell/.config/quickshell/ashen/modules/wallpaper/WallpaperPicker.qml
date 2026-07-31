import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects

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
        readonly property bool shown: Services.AppState.wallpaperVisible
        visible: shown || closeDelay.running
        Timer { id: closeDelay; interval: 300 }

        WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        // Every file found, unfiltered
        property var allWallpapers: []
        property bool scanned: false

        // Path of the wallpaper actually on screen (written by ashen-wallpaper.sh),
        // so the picker can open centred on it instead of at the far left.
        property string currentWallpaperPath: ""

        // "static" = png/jpg/jpeg/webp (awww) | "animated" = gif (awww) + mp4/webm/mkv/mov (mpvpaper)
        property string category: "static"

        function isAnimated(p) {
            let l = p.toLowerCase()
            return l.endsWith(".gif") || l.endsWith(".mp4") || l.endsWith(".webm")
                || l.endsWith(".mkv") || l.endsWith(".mov")
        }
        function isVideo(p) {
            let l = p.toLowerCase()
            return l.endsWith(".mp4") || l.endsWith(".webm") || l.endsWith(".mkv") || l.endsWith(".mov")
        }

        // QML's Image cannot decode video, so videos are previewed with the
        // frame ashen-wallpaper-thumbs.sh cached for them
        function previewFor(p) {
            if (!isVideo(p)) return "file://" + p
            let name = p.split("/").pop()
            return "file://" + Quickshell.env("HOME") + "/.cache/ashen_wall_thumbs/" + name + ".jpg"
        }

        readonly property var wallpapers: allWallpapers.filter(p => category === "animated" ? isAnimated(p) : !isAnimated(p))
        readonly property int animatedCount: allWallpapers.filter(p => isAnimated(p)).length
        readonly property int staticCount: allWallpapers.length - animatedCount

        property int currentIndex: 0
        readonly property real skew: -0.16
        readonly property real cardH: Math.min(200, height * 0.2)
        readonly property real cardW: 340
        readonly property real bandHeight: cardH + 20

        onCategoryChanged: {
            currentIndex = 0
            view.currentIndex = 0
            view.positionViewAtBeginning()
        }

        onShownChanged: {
            if (shown) {
                // Re-read the on-screen wallpaper first; its handler kicks off
                // the scan, and positionAtCurrent() runs once the list is in.
                stateReader.running = true
                focusItem.forceActiveFocus()
            } else {
                closeDelay.restart()
            }
        }

        // Centre the carousel on the wallpaper currently on screen. Switches the
        // static/animated tab to match so the entry is in the filtered list.
        function positionAtCurrent() {
            let cur = win.currentWallpaperPath
            if (cur && cur.length > 0)
                win.category = win.isAnimated(cur) ? "animated" : "static"
            let idx = cur ? win.wallpapers.indexOf(cur) : -1
            if (idx < 0) idx = 0
            win.currentIndex = idx
            view.currentIndex = idx
            // Defer the scroll so the ListView has realised its delegates.
            Qt.callLater(function() { view.positionViewAtIndex(idx, ListView.Center) })
        }

        // awww vs mpvpaper, gif frames for matugen, killing the other backend:
        // all of that lives in the script, this just hands it a path
        function applyWallpaper(path) {
            if (!path) return
            Quickshell.execDetached([Quickshell.env("HOME") + "/ashen/scripts/ashen-wallpaper.sh", path])
            Services.AppState.wallpaperVisible = false
        }

        // Reads the on-screen wallpaper path, then triggers the (re)scan; the
        // scanner positions the carousel once its list is ready.
        Process {
            id: stateReader
            command: ["cat", Quickshell.env("HOME") + "/.cache/ashen_wallpaper.txt"]
            running: false
            stdout: StdioCollector {
                onStreamFinished: {
                    win.currentWallpaperPath = text.trim()
                    wallpaperScanner.running = true
                }
            }
        }

        Process {
            id: wallpaperScanner
            // The folder is a setting now, so it rides as an argument
            command: [Quickshell.env("HOME") + "/ashen/scripts/ashen-wallpaper-thumbs.sh",
                      Services.Prefs.wallpaperDir !== "" ? Services.Prefs.wallpaperDir : Services.Paths.wallpapers]
            running: false
            stdout: StdioCollector {
                onStreamFinished: {
                    let files = text.trim().split("\n").filter(f => f.length > 0)
                    win.allWallpapers = files
                    win.scanned = true
                    win.positionAtCurrent()
                }
            }
        }

        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.0)
            MouseArea {
                anchors.fill: parent
                onClicked: Services.AppState.wallpaperVisible = false
            }
        }

        FocusScope {
            id: focusItem
            anchors.fill: parent
            focus: true

            Keys.onLeftPressed: {
                if (win.wallpapers.length === 0) return
                if (win.currentIndex > 0) win.currentIndex--
                else win.currentIndex = win.wallpapers.length - 1
                view.currentIndex = win.currentIndex
            }
            Keys.onRightPressed: {
                if (win.wallpapers.length === 0) return
                if (win.currentIndex < win.wallpapers.length - 1) win.currentIndex++
                else win.currentIndex = 0
                view.currentIndex = win.currentIndex
            }
            // Up/Down switch category
            Keys.onUpPressed: win.category = "static"
            Keys.onDownPressed: win.category = "animated"
            Keys.onReturnPressed: {
                if (win.wallpapers.length > 0) win.applyWallpaper(win.wallpapers[win.currentIndex])
            }
            Keys.onEscapePressed: Services.AppState.wallpaperVisible = false
        }

        // Categories, centered above the card band
        Item {
            id: tabsWrap
            anchors.bottom: band.top
            anchors.bottomMargin: 14
            anchors.horizontalCenter: parent.horizontalCenter
            width: container.width
            height: container.height
            z: 30
            property Item activeTab: null

            opacity: win.shown ? 1.0 : 0.0
            Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
            transform: Translate {
                y: win.shown ? 0 : 16
                Behavior on y { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
            }

            // One container pill holding both tabs, so the labels always sit on
            // a solid backdrop (readable over any wallpaper) -- workspace style.
            Rectangle {
                id: container
                anchors.centerIn: parent
                width: tabs.width + 8
                height: 34
                radius: 12
                color: Services.Colors.surfacePill

                // Sliding highlight behind the active tab (workspace-style)
                Rectangle {
                    visible: tabsWrap.activeTab !== null
                    x: 4 + (tabsWrap.activeTab ? tabsWrap.activeTab.x : 0)
                    width: tabsWrap.activeTab ? tabsWrap.activeTab.width : 0
                    height: 26
                    anchors.verticalCenter: parent.verticalCenter
                    radius: 9
                    color: Services.Colors.ghost
                    gradient: Services.Prefs.useGradients ? Services.Colors.accentGradient : null
                    Behavior on x { SmoothedAnimation { duration: 250 } }
                    Behavior on width { SmoothedAnimation { duration: 220 } }
                }

                Row {
                id: tabs
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.leftMargin: 4
                spacing: 8


            Repeater {
                model: [
                    { id: "static",   label: "Static",   icon: "" },
                    { id: "animated", label: "Animated", icon: "" }
                ]

                delegate: Rectangle {
                    required property var modelData
                    readonly property bool active: win.category === modelData.id
                    readonly property int count: modelData.id === "animated" ? win.animatedCount : win.staticCount
                    onActiveChanged: if (active) tabsWrap.activeTab = this
                    Component.onCompleted: if (active) tabsWrap.activeTab = this

                    height: 26
                    width: tabRow.implicitWidth + 20
                    radius: 9
                    // Only the sliding indicator carries the active fill;
                    // idle tabs are bare (hover just brightens them).
                    color: active ? "transparent"
                        : tabHover.containsMouse ? Services.Colors.ghostAlpha(0.12) : "transparent"

                    Behavior on color { ColorAnimation { duration: 140 } }

                    Row {
                        id: tabRow
                        anchors.centerIn: parent
                        spacing: 6

                        Text {
                            text: parent.parent.modelData.icon
                            color: parent.parent.active ? Services.Colors.abyss : Services.Colors.snow
                            font.pixelSize: 13
                            font.family: "Material Symbols Rounded"
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: parent.parent.modelData.label + "  " + parent.parent.count
                            color: parent.parent.active ? Services.Colors.abyss : Services.Colors.snow
                            font.pixelSize: 11
                            font.bold: parent.parent.active
                            font.family: "JetBrainsMono NF"
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    MouseArea {
                        id: tabHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: win.category = parent.modelData.id
                    }
                }
            }
        }
        }
        }

        // Message shown when the category is empty
        Text {
            anchors.centerIn: band
            z: 20
            visible: win.scanned && win.wallpapers.length === 0
            readonly property string dir: Services.Prefs.wallpaperDir !== ""
                ? Services.Prefs.wallpaperDir : Services.Paths.wallpapers
            text: win.category === "animated"
                ? "No animated wallpapers (gif / mp4 / webm) in " + dir
                : "No wallpapers in " + dir
            color: Services.Colors.mist
            font.pixelSize: 12
            font.family: "JetBrainsMono NF"
        }

        Item {
            id: band
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Math.max(56, Services.Sizes.marginBottom)
            height: win.bandHeight
            clip: true
            z: 10

            // Rises from the bottom edge on open, sinks back into it on close
            opacity: win.shown ? 1.0 : 0.0
            Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
            transform: Translate {
                y: win.shown ? 0 : 28
                Behavior on y { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
            }

            ListView {
                id: view
                anchors.fill: parent
                orientation: ListView.Horizontal
                clip: false
                spacing: 0
                model: win.wallpapers.length
                currentIndex: win.currentIndex

                // Preload neighbouring cards so scrolling has no gaps
                cacheBuffer: Math.round(win.cardW * 4)
                reuseItems: true

                highlightRangeMode: ListView.StrictlyEnforceRange
                preferredHighlightBegin: width / 2 - win.cardW / 2
                preferredHighlightEnd: width / 2 + win.cardW / 2
                highlightMoveDuration: 160

                header: Item { width: view.width / 2 - win.cardW / 2 }
                footer: Item { width: view.width / 2 - win.cardW / 2 }

                onCurrentIndexChanged: win.currentIndex = currentIndex

                delegate: Item {
                    required property int index
                    property bool isCurrent: index === win.currentIndex
                    property real dist: index - win.currentIndex

                    width: win.cardW
                    height: view.height

                    Item {
                        id: cardRoot
                        width: win.cardW - 20
                        height: parent.isCurrent ? win.cardH : win.cardH * 0.82
                        anchors.centerIn: parent

                        scale: parent.isCurrent ? 1.0 : 0.9
                        opacity: parent.isCurrent ? 1.0 : Math.max(0.3, 1.0 - Math.abs(parent.dist) * 0.22)

                        Behavior on height { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                        Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                        Behavior on opacity { NumberAnimation { duration: 120 } }

                        transform: Matrix4x4 {
                            matrix: Qt.matrix4x4(
                                1, win.skew, 0, 0,
                                0, 1,        0, 0,
                                0, 0,        1, 0,
                                0, 0,        0, 1
                            )
                        }

                        Image {
                            id: img
                            anchors.fill: parent
                            source: win.wallpapers.length > index ? win.previewFor(win.wallpapers[index]) : ""
                            sourceSize.width: 360
                            sourceSize.height: 240
                            fillMode: Image.PreserveAspectCrop
                            smooth: true
                            asynchronous: true
                            cache: true
                            visible: false
                        }

                        Rectangle {
                            id: maskRect
                            anchors.fill: parent
                            radius: 14
                            visible: false
                        }

                        OpacityMask {
                            anchors.fill: parent
                            source: img
                            maskSource: maskRect
                            visible: img.status === Image.Ready
                            opacity: img.status === Image.Ready ? 1.0 : 0.0
                            Behavior on opacity { NumberAnimation { duration: 140 } }
                        }

                        // Placeholder while decoding, avoids the black gap
                        Rectangle {
                            anchors.fill: parent
                            radius: 14
                            // Not a card background: a veil over a thumbnail
                            // that has not decoded yet, deliberately see-through
                            // so the tile does not flash solid and then fill in.
                            // The only surfaceAlpha left in the tree.
                            color: Services.Colors.surfaceAlpha(0.5)
                            visible: img.status !== Image.Ready
                        }

                        Rectangle {
                            anchors.fill: parent
                            radius: 14
                            color: "transparent"
                            border.color: parent.parent.isCurrent ? Services.Colors.ghost : Qt.rgba(1,1,1,0.08)
                            border.width: parent.parent.isCurrent ? 2 : 1
                        }

                        // Marks what the card actually is, since a video shows a still frame
                        Rectangle {
                            visible: win.wallpapers.length > index && win.isAnimated(win.wallpapers[index])
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: 8
                            height: 20
                            width: badgeRow.implicitWidth + 12
                            radius: 6
                            color: Qt.rgba(0, 0, 0, 0.62)

                            Row {
                                id: badgeRow
                                anchors.centerIn: parent
                                spacing: 4

                                Text {
                                    text: ""
                                    color: Services.Colors.snow
                                    font.pixelSize: 11
                                    font.family: "Material Symbols Rounded"
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Text {
                                    text: win.wallpapers.length > index && win.isVideo(win.wallpapers[index]) ? "VIDEO" : "GIF"
                                    color: Services.Colors.snow
                                    font.pixelSize: 9
                                    font.bold: true
                                    font.family: "JetBrainsMono NF"
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (parent.parent.isCurrent) {
                                    win.applyWallpaper(win.wallpapers[win.currentIndex])
                                } else {
                                    win.currentIndex = index
                                    view.currentIndex = index
                                }
                            }
                        }
                    }
                }
            }
        }

        Row {
            anchors.top: band.bottom
            anchors.topMargin: 16
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 8
            z: 30
            visible: win.wallpapers.length > 1

            Repeater {
                model: Math.min(win.wallpapers.length, 10)
                delegate: Rectangle {
                    required property int index
                    width: win.currentIndex === index ? 20 : 7
                    height: 7; radius: 4
                    color: win.currentIndex === index ? Services.Colors.ghost : Qt.rgba(1,1,1,0.2)
                    gradient: Services.Prefs.useGradients && (win.currentIndex === index) ? Services.Colors.accentGradient : null
                    Behavior on width { NumberAnimation { duration: 200 } }
                    Behavior on color { ColorAnimation { duration: 200 } }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { win.currentIndex = index; view.currentIndex = index }
                    }
                }
            }
        }
    }
}
