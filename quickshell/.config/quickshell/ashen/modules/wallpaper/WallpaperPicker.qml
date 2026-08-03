import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects

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
        readonly property bool shown: Services.AppState.wallpaperVisible
        visible: shown || closeDelay.running
        Timer { id: closeDelay; interval: card.closeMs }

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

        // `category` is the tab you pressed; `shownCategory` is what the
        // carousel is showing. It turns over halfway through the slide, while
        // nothing is legible. Assigned, never bound: a binding would track the
        // tab live and the cards would swap under the animation.
        property string shownCategory: "static"
        // True while the picker places the category itself.
        property bool settling: false
        readonly property var wallpapers: allWallpapers.filter(p => shownCategory === "animated" ? isAnimated(p) : !isAnimated(p))
        readonly property int animatedCount: allWallpapers.filter(p => isAnimated(p)).length
        readonly property int staticCount: allWallpapers.length - animatedCount

        property int currentIndex: 0
        readonly property real skew: -0.16
        readonly property real cardH: Math.min(200, height * 0.2)
        readonly property real cardW: 340
        readonly property real bandHeight: cardH + 20

        // The carousel is inside the card's body, which is rebuilt on every
        // open, so it is reached through what the body publishes -- never held
        // onto. It is absent until the card has built it.
        readonly property Item listView: card.bodyItem ? card.bodyItem.listView : null

        onShownCategoryChanged: {
            currentIndex = 0
            if (!win.listView) return
            win.listView.currentIndex = 0
            win.listView.positionViewAtBeginning()
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
            if (cur && cur.length > 0) {
                // No slide on the way in: landing on the category of the
                // wallpaper you already have is not a change you asked for,
                // and it played on top of the panel's own opening.
                win.settling = true
                win.category = win.isAnimated(cur) ? "animated" : "static"
                win.shownCategory = win.category
                Qt.callLater(function() { win.settling = false })
            }
            let idx = cur ? win.wallpapers.indexOf(cur) : -1
            if (idx < 0) idx = 0
            win.currentIndex = idx
            if (!win.listView) return
            win.listView.currentIndex = idx
            // Defer the scroll so the ListView has realised its delegates.
            Qt.callLater(function() {
                if (win.listView) win.listView.positionViewAtIndex(idx, ListView.Center)
            })
        }

        // awww vs mpvpaper, gif frames for matugen, killing the other backend:
        // all of that lives in the script, this just hands it a path
        function applyWallpaper(path) {
            if (!path) return
            Quickshell.execDetached([Services.Paths.script("ashen-wallpaper.sh"), path])
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
            command: [Services.Paths.script("ashen-wallpaper-thumbs.sh"),
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
                if (win.listView) win.listView.currentIndex = win.currentIndex
            }
            Keys.onRightPressed: {
                if (win.wallpapers.length === 0) return
                if (win.currentIndex < win.wallpapers.length - 1) win.currentIndex++
                else win.currentIndex = 0
                if (win.listView) win.listView.currentIndex = win.currentIndex
            }
            // Up/Down switch category
            Keys.onUpPressed: win.category = "static"
            Keys.onDownPressed: win.category = "animated"
            Keys.onReturnPressed: {
                if (win.wallpapers.length > 0) win.applyWallpaper(win.wallpapers[win.currentIndex])
            }
            Keys.onEscapePressed: Services.AppState.wallpaperVisible = false
        }


        // Never had a capsule of its own, so it unfolds where it lives instead
        // of dropping out of a chip -- and it is a card now, not a band welded
        // to the bottom of the screen.
        Widgets.PanelHost {
            id: card
            shown: win.shown
            restSide: "bottom"
            rise: 40
            // Same clearance the other bottom panels keep, so it does not sit
            // welded to the edge the way the old band did.
            openYOverride: win.height - card.openH - Math.max(68, Services.Sizes.marginBottom + 18)

            // Edge to edge, the way the old band ran: the carousel is meant to
            // sweep the whole screen, and a narrower card just cropped it.
            openW: win.width
            openXOverride: 0
            // tabs + carousel + dots, and the padding between them
            openH: 20 + 34 + 16 + win.bandHeight + 14 + 7 + 20
            cardRadius: 22
            // No plate: the wallpapers ARE the surface here, and a panel
            // behind them only got in the way.
            cardColor: "transparent"

            body: Component {
                Item {
                    id: bodyRoot
                    // The window drives the carousel (positionAtCurrent) and a
                    // Component is a boundary for ids, so it is handed out here.
                    readonly property Item listView: view

                    // Its own arrival. The shared stage() is spaced for a card
                    // whose box you can watch unfold; this one is invisible, so
                    // the pieces themselves have to carry the entrance, and they
                    // need real distance between them to read as an order.
                    property real intro: 0
                    function piece(i) {
                        const start = i * 0.26
                        return Math.max(0, Math.min(1, (bodyRoot.intro - start) / (1 - start)))
                    }
                    NumberAnimation {
                        id: introIn
                        target: bodyRoot; property: "intro"; to: 1
                        duration: 520; easing.type: Services.Sizes.easeOut
                    }
                    NumberAnimation {
                        id: introOut
                        target: bodyRoot; property: "intro"; to: 0
                        duration: 150; easing.type: Services.Sizes.easeIn
                    }
                    // Explicit, never Behaviors: in and out are different
                    // shapes, and starting one does not stop the other.
                    Connections {
                        target: win
                        function onShownChanged() {
                            if (win.shown) { introOut.stop(); introIn.restart() }
                            else { introIn.stop(); introOut.restart() }
                        }
                    }
                    // The body is rebuilt on every open, and a property born
                    // with its value never emits a change.
                    Component.onCompleted: if (win.shown) introIn.restart()

                    // Categories, above the carousel. The three pieces come in
                    // one after another rather than as one slab, and leave the
                    // same way -- the card itself is invisible here, so the
                    // arrival IS the content.
                    Item {
                        id: tabsWrap
                        anchors.top: parent.top
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: container.width
                        height: container.height
                        z: 30
                        property Item activeTab: null

                        readonly property real amt: bodyRoot.piece(0)
                        opacity: amt
                        transform: Translate { y: (1 - tabsWrap.amt) * -14 }

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
                                Behavior on x { SmoothedAnimation { duration: Services.Sizes.msPronounced } }
                                Behavior on width { SmoothedAnimation { duration: Services.Sizes.msStandard } }
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

                                Behavior on color { ColorAnimation { duration: Services.Sizes.msMicro } }

                                Row {
                                    id: tabRow
                                    anchors.centerIn: parent
                                    spacing: 6

                                    Text {
                                        text: parent.parent.modelData.icon
                                        color: parent.parent.active ? Services.Colors.accentText : Services.Colors.snow
                                        font.pixelSize: 13
                                        font.family: "Material Symbols Rounded"
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                    Text {
                                        text: parent.parent.modelData.label + "  " + parent.parent.count
                                        color: parent.parent.active ? Services.Colors.accentText : Services.Colors.snow
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


                    // Changing category slides, the same as every other set of
                    // sections in the shell.
                    Widgets.SlideSwap {
                        id: catSlide
                        axis: "horizontal"
                        travel: 40
                        index: win.category === "animated" ? 1 : 0
                        animate: !win.settling
                        onCommit: win.shownCategory = win.category
                    }

                    Item {
                        id: band
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: tabsWrap.bottom
                        anchors.topMargin: 16
                        height: win.bandHeight
                        clip: true
                        z: 10

                        readonly property real amt: bodyRoot.piece(1)
                        opacity: catSlide.fade * band.amt
                        transform: Translate { x: catSlide.offX; y: (1 - band.amt) * 26 }

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
                                id: slot
                                required property int index
                                property bool isCurrent: index === win.currentIndex

                                // How far this card is from the middle of the
                                // view, in cards, read off the LIVE scroll
                                // position rather than off the index. Index
                                // distance is a whole number, so the cards used
                                // to jump a step at a time no matter how slowly
                                // you dragged; this follows your finger.
                                readonly property real dist:
                                    (slot.x + win.cardW / 2 - view.contentX - view.width / 2) / win.cardW
                                // 1 dead centre, 0 two cards out. Falls off fast
                                // on purpose: the one you are choosing has to be
                                // obviously bigger than its neighbours.
                                readonly property real prox: Math.max(0, 1 - Math.abs(slot.dist) / 2)

                                width: win.cardW
                                height: view.height

                                Item {
                                    id: cardRoot
                                    width: win.cardW - 20
                                    // The nearer it is, the bigger it gets --
                                    // no Behaviors, because `prox` is already
                                    // continuous and smoothing it only adds lag.
                                    height: win.cardH * (0.6 + 0.4 * slot.prox)

                                    anchors.centerIn: parent

                                    scale: 0.74 + 0.26 * slot.prox
                                    opacity: 0.22 + 0.78 * slot.prox

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
                                        Behavior on opacity { NumberAnimation { duration: Services.Sizes.msMicro } }
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
                                        border.color: parent.parent.isCurrent ? Services.Colors.ghost : Services.Colors.snowAlpha(0.08)
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
                        id: dotsRow
                        anchors.top: band.bottom
                        anchors.topMargin: 14

                        readonly property real amt: bodyRoot.piece(2)
                        opacity: catSlide.fade * dotsRow.amt
                        transform: Translate { x: catSlide.offX; y: (1 - dotsRow.amt) * 16 }
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 8
                        z: 30
                        visible: win.wallpapers.length > 1

                        // Ten dots at most, and the run STARTS OVER once you go
                        // past them: with 46 wallpapers the marker used to fall
                        // off the end at the eleventh and nothing was lit at all.
                        readonly property int dotCount: Math.min(win.wallpapers.length, 10)
                        readonly property int litDot: dotCount > 0 ? win.currentIndex % dotCount : 0
                        readonly property int runStart: dotCount > 0
                            ? Math.floor(win.currentIndex / dotCount) * dotCount : 0

                        Repeater {
                            model: dotsRow.dotCount
                            delegate: Rectangle {
                                required property int index
                                readonly property bool lit: dotsRow.litDot === index
                                width: lit ? 20 : 7
                                height: 7; radius: 4
                                color: lit ? Services.Colors.ghost : Services.Colors.snowAlpha(0.2)
                                gradient: Services.Prefs.useGradients && lit ? Services.Colors.accentGradient : null
                                Behavior on width { NumberAnimation { duration: Services.Sizes.msStandard } }
                                Behavior on color { ColorAnimation { duration: Services.Sizes.msStandard } }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    // Within the run you are on, so a dot still
                                    // takes you where it looks like it will.
                                    onClicked: {
                                        const t = Math.min(dotsRow.runStart + index,
                                                           win.wallpapers.length - 1)
                                        win.currentIndex = t
                                        view.currentIndex = t
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
