import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Mpris
import Quickshell.Services.Pam
import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Layouts
import "root:/services" as Services

Scope {
    id: root

    IpcHandler {
        target: "lockscreen"
        function lock() {
            sessionLock.locked = true
        }
    }

    WlSessionLock {
        id: sessionLock


        WlSessionLockSurface {
            id: surface

            // Material Symbols codepoints (modules/glyph/data/material_symbols.txt)
            readonly property string glyphLock: "\uE899"
            readonly property string glyphLockOpen: "\uE898"

            property string currentTime: Qt.formatDateTime(new Date(), Services.Prefs.timeFormat)
            property string currentSecs: Qt.formatDateTime(new Date(), "ss")
            property string currentDate: Qt.formatDateTime(new Date(), "MMMM d, yyyy")
            property string currentDay: Qt.locale().dayName(new Date().getDay())
            property string password: ""
            property string errorMsg: ""
            property bool checking: false
            property bool showPower: false
            property bool showProfiles: false
            property int battery: 0
            property bool charging: false
            property string wallpaper: ""
            property bool revealed: false
            property bool unlocking: false

            // Intro: the padlock snaps shut before the lock screen itself fades in
            property bool introDone: false
            property bool lockShut: false

            property var activePlayer: {
                let list = Mpris.players.values.filter(p => p.playbackState !== MprisPlaybackState.Stopped)
                if (list.length === 0) return null
                let playing = list.find(p => p.isPlaying)
                return playing !== undefined ? playing : list[0]
            }
            property bool hasPlayer: activePlayer !== null
            property string stableArtUrl: ""
            function updateArt() {
                if (!surface.hasPlayer) { surface.stableArtUrl = ""; return }
                if (surface.activePlayer.trackArtUrl !== "") surface.stableArtUrl = surface.activePlayer.trackArtUrl
            }
            onActivePlayerChanged: updateArt()
            Connections {
                target: surface.activePlayer
                ignoreUnknownSignals: true
                function onTrackArtUrlChanged() { surface.updateArt() }
            }

            function formatTime(seconds) {
                if (!seconds || seconds <= 0) return "0:00"
                let m = Math.floor(seconds / 60)
                let s = Math.floor(seconds % 60)
                return m + ":" + (s < 10 ? "0" : "") + s
            }

            // MPRIS only emits position on demand
            Timer {
                interval: 1000
                repeat: true
                running: surface.hasPlayer && surface.activePlayer.isPlaying
                onTriggered: if (surface.hasPlayer) surface.activePlayer.positionChanged()
            }

            property var availableProfiles: []
            property string activeProfile: ""
            function refreshProfiles() { profProc.running = true }
            function setProfile(name) {
                if (!surface.availableProfiles.includes(name)) return
                Quickshell.execDetached(["sh", "-c", "powerprofilesctl set " + name])
                surface.activeProfile = name
            }

            color: Services.Colors.abyss

            Component.onCompleted: {
                surface.updateArt()
                surface.refreshProfiles()
                introAnim.start()
            }

            Timer {
                interval: 1000
                running: true
                repeat: true
                onTriggered: {
                    let now = new Date()
                    surface.currentTime = Qt.formatDateTime(now, Services.Prefs.timeFormat)
                    surface.currentSecs = Qt.formatDateTime(now, "ss")
                    surface.currentDate = Qt.formatDateTime(now, "MMMM d, yyyy")
                    surface.currentDay = Qt.locale().dayName(now.getDay())
                }
            }

            Process {
                id: batProc
                command: ["sh", "-c", "cat /sys/class/power_supply/BAT0/capacity"]
                running: true
                stdout: StdioCollector { onStreamFinished: surface.battery = parseInt(text.trim()) || 0 }
            }
            Process {
                id: chargeProc
                command: ["sh", "-c", "cat /sys/class/power_supply/AC0/online"]
                running: true
                stdout: StdioCollector { onStreamFinished: surface.charging = text.trim() === "1" }
            }
            Process {
                id: wallpaperProc
                // The live wallpaper may be a video (mpvpaper), which QML can't
                // draw as a still. So resolve to a paintable image: a still
                // wallpaper is used as-is; for video/gif we fall back to the
                // frame ashen-wallpaper.sh extracts (same one matugen samples).
                command: ["sh", "-c",
                    "w=$(cat \"$HOME/.cache/ashen_wallpaper.txt\" 2>/dev/null); " +
                    "case \"$(printf '%s' \"$w\" | tr '[:upper:]' '[:lower:]')\" in " +
                    "*.png|*.jpg|*.jpeg|*.webp) printf '%s' \"$w\" ;; " +
                    "*) printf '%s' \"$HOME/.cache/ashen_wall_frame.png\" ;; " +
                    "esac"]
                running: true
                stdout: StdioCollector { onStreamFinished: surface.wallpaper = text.trim() }
            }
            Timer {
                interval: 30000; running: true; repeat: true
                onTriggered: { batProc.running = true; chargeProc.running = true }
            }

            Process {
                id: profProc
                command: ["sh", "-c", "powerprofilesctl list"]
                running: false
                stdout: StdioCollector {
                    onStreamFinished: {
                        let lines = text.split("\n")
                        let profiles = []
                        let active = ""
                        for (let line of lines) {
                            let m = line.match(/^\s*(\*?)\s*([\w-]+):$/)
                            if (m) {
                                profiles.push(m[2])
                                if (m[1] === "*") active = m[2]
                            }
                        }
                        surface.availableProfiles = profiles
                        surface.activeProfile = active
                    }
                }
            }

            PamContext {
                id: pam

                config: "login"

                onPamMessage: {
                    if (responseRequired)
                        respond(surface.password)
                }

                onCompleted: result => {
                    surface.checking = false

                    if (result === PamResult.Success) {
                        surface.unlocking = true
                        unlockTimer.start()
                    } else {
                        surface.errorMsg = result === PamResult.Error ? "Auth error" : "Incorrect password"
                        surface.password = ""
                        passInput.text = ""
                        errorTimer.restart()
                        shakeAnim.restart()
                    }
                }
            }

            Timer {
                id: unlockTimer
                interval: 340
                onTriggered: sessionLock.locked = false
            }

            Timer {
                id: errorTimer
                interval: 2500
                onTriggered: surface.errorMsg = ""
            }

            function tryUnlock() {
                if (surface.password.length === 0) {
                    surface.errorMsg = "Please enter your password"
                    errorTimer.restart()
                    shakeAnim.restart()
                    return
                }
                if (pam.active)
                    return

                surface.checking = true
                surface.errorMsg = ""
                pam.start()
            }

            // ── Main content (with enter/exit animation) ──
            Item {
                id: content
                anchors.fill: parent
                opacity: surface.unlocking ? 0.0 : (surface.revealed ? 1.0 : 0.0)
                scale: surface.unlocking ? 1.04 : (surface.revealed ? 1.0 : 1.05)
                Behavior on opacity { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
                Behavior on scale { NumberAnimation { duration: 420; easing.type: Easing.OutCubic } }

                Rectangle {
                    anchors.fill: parent
                    color: Services.Colors.abyss

                    Image {
                        id: wallImg
                        anchors.fill: parent
                        source: surface.wallpaper !== "" ? ("file://" + surface.wallpaper) : ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        // frame path is fixed but its contents change per video;
                        // no cache or the lock shows the previous wallpaper's frame
                        cache: false
                        visible: false
                    }
                    FastBlur {
                        anchors.fill: parent
                        source: wallImg
                        radius: 64
                        visible: wallImg.status === Image.Ready
                        opacity: 0.45
                    }
                    // Vignette: darker at the edges so the corner pills stay readable
                    Rectangle {
                        anchors.fill: parent
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: Qt.rgba(Services.Colors.abyss.r, Services.Colors.abyss.g, Services.Colors.abyss.b, 0.45) }
                            GradientStop { position: 0.5; color: Qt.rgba(Services.Colors.abyss.r, Services.Colors.abyss.g, Services.Colors.abyss.b, 0.62) }
                            GradientStop { position: 1.0; color: Qt.rgba(Services.Colors.abyss.r, Services.Colors.abyss.g, Services.Colors.abyss.b, 0.80) }
                        }
                    }

                    // ── Centre column: clock · avatar · password ──
                    Column {
                        anchors.centerIn: parent
                        spacing: 28

                        Column {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: 0
                            Row {
                                anchors.horizontalCenter: parent.horizontalCenter
                                spacing: 0
                                Text {
                                    text: surface.currentTime.split(" ")[0]
                                    color: Services.Colors.snow
                                    font.pixelSize: 104
                                    font.family: "JetBrainsMono NF"
                                    font.weight: Font.Bold
                                    font.letterSpacing: -2
                                }
                                Column {
                                    anchors.bottom: parent.bottom
                                    anchors.bottomMargin: 18
                                    spacing: 2
                                    leftPadding: 8
                                    Text {
                                        text: surface.currentSecs
                                        color: Services.Colors.snowAlpha(0.4)
                                        font.pixelSize: 28
                                        font.family: "JetBrainsMono NF"
                                        font.weight: Font.Bold
                                    }
                                    Text {
                                        text: surface.currentTime.split(" ")[1]
                                        color: Services.Colors.snowAlpha(0.4)
                                        font.pixelSize: 14
                                        font.family: "JetBrainsMono NF"
                                        font.weight: Font.Bold
                                    }
                                }
                            }
                            Row {
                                anchors.horizontalCenter: parent.horizontalCenter
                                spacing: 10
                                topPadding: 4
                                Text {
                                    text: surface.currentDay + "  ·  " + surface.currentDate
                                    color: Services.Colors.snowAlpha(0.5)
                                    font.pixelSize: 15
                                    font.family: "JetBrainsMono NF"
                                    font.weight: Font.Bold
                                    font.letterSpacing: 1
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Rectangle {
                                    width: 1; height: 12
                                    color: Services.Colors.snowAlpha(0.2)
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Text {
                                    text: Services.Weather.icon
                                    color: Services.Colors.snowAlpha(0.55)
                                    font.pixelSize: 16
                                    font.family: "Material Symbols Rounded"
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Text {
                                    text: Services.Weather.temp
                                    color: Services.Colors.snowAlpha(0.55)
                                    font.pixelSize: 14
                                    font.family: "JetBrainsMono NF"
                                    font.weight: Font.Bold
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                        }

                        Column {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: 12
                            Rectangle {
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: 116; height: 116
                                radius: 26
                                clip: true
                                color: Services.Colors.ghostAlpha(0.15)
                                border.color: surface.checking ? Services.Colors.ghost : Services.Colors.ghostAlpha(0.35)
                                border.width: 2
                                Behavior on border.color { ColorAnimation { duration: 200 } }
                                Image {
                                    id: faceImg
                                    anchors.fill: parent
                                    anchors.margins: 2
                                    source: Services.AppState.facePath
                                    fillMode: Image.PreserveAspectCrop
                                    cache: false
                                    visible: false
                                }
                                Rectangle {
                                    id: faceMask
                                    anchors.fill: faceImg
                                    radius: 24
                                    visible: false
                                }
                                OpacityMask {
                                    anchors.fill: faceImg
                                    source: faceImg
                                    maskSource: faceMask
                                    visible: faceImg.status === Image.Ready
                                }
                                Text {
                                    anchors.centerIn: parent
                                    text: "\uF0D3"
                                    color: Services.Colors.ghost
                                    font.pixelSize: 68
                                    font.family: "Material Symbols Rounded"
                                    visible: faceImg.status !== Image.Ready
                                }
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: Services.AppState.userLabel
                                color: Services.Colors.snow
                                font.pixelSize: 17
                                font.family: "JetBrainsMono NF"
                                font.weight: Font.Medium
                                font.letterSpacing: 1
                            }
                        }

                        Column {
                            id: authColumn
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: 10

                            // Wrong password: the field shakes instead of only turning red
                            transform: Translate { id: shakeT; x: 0 }
                            SequentialAnimation {
                                id: shakeAnim
                                NumberAnimation { target: shakeT; property: "x"; to:  9; duration: 55 }
                                NumberAnimation { target: shakeT; property: "x"; to: -8; duration: 55 }
                                NumberAnimation { target: shakeT; property: "x"; to:  6; duration: 55 }
                                NumberAnimation { target: shakeT; property: "x"; to: -4; duration: 55 }
                                NumberAnimation { target: shakeT; property: "x"; to:  0; duration: 55 }
                            }

                            Rectangle {
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: 340; height: 52
                                radius: 12
                                color: Services.Colors.surfaceAlpha(0.85)
                                border.color: surface.errorMsg !== "" ? Services.Colors.error_
                                    : passInput.activeFocus ? Services.Colors.ghost
                                    : Services.Colors.ghostAlpha(0.25)
                                border.width: 1
                                Behavior on border.color { ColorAnimation { duration: 150 } }
                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 18
                                    anchors.rightMargin: 18
                                    spacing: 12
                                    Text {
                                        text: surface.glyphLock
                                        color: surface.errorMsg !== "" ? Services.Colors.error_ : Services.Colors.ghost
                                        font.pixelSize: 18
                                        font.family: "Material Symbols Rounded"
                                        Behavior on color { ColorAnimation { duration: 150 } }
                                    }
                                    Item {
                                        Layout.fillWidth: true
                                        height: 30
                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: "Enter password..."
                                            color: Services.Colors.ash
                                            font.pixelSize: 14
                                            font.family: "JetBrainsMono NF"
                                            visible: surface.password.length === 0
                                        }
                                        Row {
                                            anchors.verticalCenter: parent.verticalCenter
                                            spacing: 6
                                            visible: surface.password.length > 0
                                            Repeater {
                                                model: Math.min(surface.password.length, 24)
                                                delegate: Rectangle {
                                                    width: 8; height: 8; radius: 3
                                                    color: Services.Colors.ghost
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    NumberAnimation on scale {
                                                        from: 0; to: 1; duration: 160
                                                        easing.type: Easing.OutBack
                                                        running: true
                                                    }
                                                }
                                            }
                                            Rectangle {
                                                id: blinkCursor
                                                width: 2; height: 16
                                                anchors.verticalCenter: parent.verticalCenter
                                                color: Services.Colors.snow
                                                SequentialAnimation on opacity {
                                                    running: passInput.activeFocus
                                                    loops: Animation.Infinite
                                                    NumberAnimation { to: 0.0; duration: 500 }
                                                    NumberAnimation { to: 1.0; duration: 500 }
                                                }
                                            }
                                        }
                                        Rectangle {
                                            width: 2; height: 16
                                            anchors.verticalCenter: parent.verticalCenter
                                            visible: surface.password.length === 0 && passInput.activeFocus
                                            color: Services.Colors.snow
                                            SequentialAnimation on opacity {
                                                running: passInput.activeFocus
                                                loops: Animation.Infinite
                                                NumberAnimation { to: 0.0; duration: 500 }
                                                NumberAnimation { to: 1.0; duration: 500 }
                                            }
                                        }
                                        TextInput {
                                            id: passInput
                                            width: 1; height: 1
                                            x: -9999; y: -9999
                                            echoMode: TextInput.Password
                                            color: "transparent"
                                            cursorVisible: true
                                            focus: true
                                            onTextChanged: surface.password = text
                                            Keys.onReturnPressed: surface.tryUnlock()
                                            Keys.onEscapePressed: {
                                                text = ""
                                                surface.errorMsg = ""
                                            }
                                        }
                                    }
                                    Text {
                                        text: "\uE627"
                                        color: surface.checking ? Services.Colors.ghost : Services.Colors.ash
                                        font.pixelSize: 18
                                        font.family: "Material Symbols Rounded"
                                        Behavior on color { ColorAnimation { duration: 150 } }
                                        MouseArea {
                                            anchors.fill: parent
                                            anchors.margins: -6
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: surface.tryUnlock()
                                        }
                                        SequentialAnimation on opacity {
                                            running: surface.checking
                                            loops: Animation.Infinite
                                            NumberAnimation { to: 0.2; duration: 500 }
                                            NumberAnimation { to: 1.0; duration: 500 }
                                        }
                                    }
                                }
                            }
                            Item {
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: 340
                                height: 16
                                Text {
                                    anchors.centerIn: parent
                                    text: surface.errorMsg
                                    color: Services.Colors.error_
                                    font.pixelSize: 12
                                    font.family: "JetBrainsMono NF"
                                    opacity: surface.errorMsg !== "" ? 1.0 : 0.0
                                    Behavior on opacity { NumberAnimation { duration: 200 } }
                                }
                            }
                        }
                    }

                    // ── Music card (bottom left) ──
                    Rectangle {
                        id: musicCard
                        anchors.left: parent.left
                        anchors.bottom: parent.bottom
                        anchors.margins: 24
                        width: 400
                        height: 116
                        radius: 16
                        clip: true
                        color: Services.Colors.surfaceAlpha(0.85)
                        border.color: Services.Colors.ghostAlpha(0.25)
                        border.width: 1

                        opacity: surface.hasPlayer ? 1.0 : 0.0
                        visible: opacity > 0
                        Behavior on opacity { NumberAnimation { duration: 250 } }
                        transform: Translate {
                            y: surface.hasPlayer ? 0 : 16
                            Behavior on y { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                        }

                        // Same Cava service the bar uses, drawn as the card's backdrop
                        Canvas {
                            id: cavaCanvas
                            anchors.fill: parent
                            opacity: Services.Cava.isActive ? 1.0 : 0.0
                            Behavior on opacity { NumberAnimation { duration: 400 } }
                            Connections {
                                target: Services.Cava
                                function onBarValuesChanged() { cavaCanvas.requestPaint() }
                            }
                            onPaint: {
                                var ctx = getContext("2d")
                                ctx.reset()
                                let vals = Services.Cava.barValues
                                if (!vals || vals.length === 0) return
                                var n = vals.length
                                var barW = width / n
                                ctx.fillStyle = Services.Colors.ghostAlpha(0.16)
                                for (var i = 0; i < n; i++) {
                                    var v = Math.max(0, Math.min(100, vals[i])) / 100.0
                                    var h = v * height * 0.75
                                    ctx.fillRect(i * barW, height - h, Math.max(1, barW - 1), h)
                                }
                            }
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 14
                            spacing: 14

                            Item {
                                width: 68; height: 68
                                Layout.alignment: Qt.AlignVCenter

                                Image {
                                    id: lockArtImg
                                    anchors.fill: parent
                                    source: surface.stableArtUrl
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                    visible: false
                                }
                                Rectangle {
                                    id: lockArtMask
                                    anchors.fill: parent
                                    radius: 12
                                    visible: false
                                }
                                OpacityMask {
                                    anchors.fill: parent
                                    source: lockArtImg
                                    maskSource: lockArtMask
                                    visible: lockArtImg.status === Image.Ready
                                }
                                Rectangle {
                                    anchors.fill: parent
                                    radius: 12
                                    color: Services.Colors.abyss
                                    visible: lockArtImg.status !== Image.Ready
                                    Text {
                                        anchors.centerIn: parent
                                        text: "\uE405"
                                        color: Services.Colors.ghost
                                        font.pixelSize: 24
                                        font.family: "Material Symbols Rounded"
                                    }
                                }
                                Rectangle {
                                    anchors.fill: parent
                                    radius: 12
                                    color: "transparent"
                                    border.color: Services.Colors.ghostAlpha(0.2)
                                    border.width: 1
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                spacing: 3

                                Text {
                                    text: surface.hasPlayer ? (surface.activePlayer.trackTitle || "Untitled") : ""
                                    color: Services.Colors.snow
                                    font.pixelSize: 13
                                    font.bold: true
                                    font.family: "JetBrainsMono NF"
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                                Text {
                                    text: surface.hasPlayer ? (surface.activePlayer.trackArtist || "") : ""
                                    color: Services.Colors.mist
                                    font.pixelSize: 10
                                    font.family: "JetBrainsMono NF"
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }

                                Item { Layout.fillHeight: true }

                                // Progress
                                Item {
                                    Layout.fillWidth: true
                                    height: 4
                                    Rectangle {
                                        anchors.fill: parent
                                        radius: 2
                                        color: Services.Colors.ghostAlpha(0.18)
                                    }
                                    Rectangle {
                                        height: parent.height
                                        radius: 2
                                        color: Services.Colors.ghost
                                        width: {
                                            if (!surface.hasPlayer || surface.activePlayer.length <= 0) return 0
                                            return parent.width * (surface.activePlayer.position / surface.activePlayer.length)
                                        }
                                        Behavior on width { NumberAnimation { duration: 300 } }
                                    }
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 8

                                    Text {
                                        text: surface.hasPlayer ? surface.formatTime(surface.activePlayer.position) : "0:00"
                                        color: Services.Colors.ash
                                        font.pixelSize: 9
                                        font.family: "JetBrainsMono NF"
                                    }
                                    Item { Layout.fillWidth: true }

                                    Text {
                                        text: "\uE045"
                                        font.family: "Material Symbols Rounded"
                                        font.pixelSize: 15
                                        color: surface.hasPlayer && surface.activePlayer.canGoPrevious ? Services.Colors.snow : Services.Colors.ash
                                        MouseArea {
                                            anchors.fill: parent; anchors.margins: -6
                                            cursorShape: Qt.PointingHandCursor
                                            enabled: surface.hasPlayer && surface.activePlayer.canGoPrevious
                                            onClicked: surface.activePlayer.previous()
                                        }
                                    }
                                    Rectangle {
                                        width: 30; height: 30; radius: 9
                                        color: Services.Colors.ghost
                                        Text {
                                            anchors.centerIn: parent
                                            text: surface.hasPlayer && surface.activePlayer.isPlaying ? "\uE034" : "\uE037"
                                            font.family: "Material Symbols Rounded"
                                            font.pixelSize: 15
                                            color: Services.Colors.abyss
                                        }
                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            enabled: surface.hasPlayer
                                            onClicked: surface.activePlayer.togglePlaying()
                                        }
                                    }
                                    Text {
                                        text: "\uE044"
                                        font.family: "Material Symbols Rounded"
                                        font.pixelSize: 15
                                        color: surface.hasPlayer && surface.activePlayer.canGoNext ? Services.Colors.snow : Services.Colors.ash
                                        MouseArea {
                                            anchors.fill: parent; anchors.margins: -6
                                            cursorShape: Qt.PointingHandCursor
                                            enabled: surface.hasPlayer && surface.activePlayer.canGoNext
                                            onClicked: surface.activePlayer.next()
                                        }
                                    }

                                    Item { Layout.fillWidth: true }
                                    Text {
                                        text: surface.hasPlayer ? surface.formatTime(surface.activePlayer.length) : "0:00"
                                        color: Services.Colors.ash
                                        font.pixelSize: 9
                                        font.family: "JetBrainsMono NF"
                                    }
                                }
                            }
                        }
                    }

                    // ── Bottom right corner: fixed, independent anchors ──
                    Item {
                        id: cornerArea
                        anchors.bottom: parent.bottom
                        anchors.right: parent.right
                        anchors.margins: 24
                        width: powerPill.width
                        height: powerPill.height

                        // -- Power: pill fixed on the right, options expand UPWARDS --
                        Rectangle {
                            id: powerPill
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            width: 44; height: 44
                            radius: 10
                            color: Services.Colors.surfaceAlpha(0.85)
                            border.color: Services.Colors.ghostAlpha(0.25)
                            border.width: 1
                            Text {
                                anchors.centerIn: parent
                                text: "\uF8C7"
                                color: surface.showPower ? Services.Colors.snow : Services.Colors.mist
                                font.pixelSize: 20
                                font.family: "Material Symbols Rounded"
                                Behavior on color { ColorAnimation { duration: 150 } }
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: surface.showPower = !surface.showPower
                            }
                        }

                        Column {
                            anchors.right: powerPill.right
                            anchors.bottom: powerPill.top
                            anchors.bottomMargin: 8
                            spacing: 6
                            opacity: surface.showPower ? 1.0 : 0.0
                            visible: opacity > 0
                            Behavior on opacity { NumberAnimation { duration: 200 } }
                            Repeater {
                                model: [
                                    { icon: "\uF8C7", cmd: "systemctl poweroff", color: Services.Colors.error_ },
                                    { icon: "\uF053", cmd: "systemctl reboot",   color: Services.Colors.mist },
                                    { icon: "\uF159", cmd: "systemctl suspend",  color: Services.Colors.mist },
                                ]
                                delegate: Rectangle {
                                    id: powerItem
                                    required property var modelData
                                    anchors.right: parent.right
                                    width: 44; height: 44
                                    radius: 10
                                    // Declarative hover: assigning color in onEntered kills the binding
                                    color: powerHover.containsMouse ? Services.Colors.ghostAlpha(0.2)
                                                                    : Services.Colors.surfaceAlpha(0.92)
                                    border.color: Services.Colors.ghostAlpha(0.25)
                                    border.width: 1
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                    Text {
                                        anchors.centerIn: parent
                                        text: powerItem.modelData.icon
                                        color: powerItem.modelData.color
                                        font.pixelSize: 20
                                        font.family: "Material Symbols Rounded"
                                    }
                                    MouseArea {
                                        id: powerHover
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        hoverEnabled: true
                                        onClicked: Quickshell.execDetached(["sh", "-c", powerItem.modelData.cmd])
                                    }
                                }
                            }
                        }

                        // -- Battery: pill fixed left of power, profiles expand to the LEFT --
                        Rectangle {
                            id: batteryPill
                            anchors.right: powerPill.left
                            anchors.rightMargin: 10
                            anchors.bottom: parent.bottom
                            width: 78; height: 44
                            radius: 10
                            color: Services.Colors.surfaceAlpha(0.85)
                            border.color: Services.Colors.ghostAlpha(0.25)
                            border.width: 1
                            Row {
                                anchors.centerIn: parent
                                spacing: 4
                                Text {
                                    text: surface.charging ? "\uE1A3" : surface.battery >= 90 ? "\uE1A5" : surface.battery >= 50 ? "\uF0A1" : surface.battery >= 20 ? "\uF09F" : "\uE19C"
                                    color: surface.battery < 20 && !surface.charging ? Services.Colors.error_ : Services.Colors.mist
                                    font.pixelSize: 18
                                    font.family: "Material Symbols Rounded"
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Text {
                                    text: surface.battery + "%"
                                    color: surface.battery < 20 && !surface.charging ? Services.Colors.error_ : Services.Colors.mist
                                    font.pixelSize: 12
                                    font.family: "JetBrainsMono NF"
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: surface.showProfiles = !surface.showProfiles
                            }
                        }

                        Row {
                            anchors.right: batteryPill.left
                            anchors.rightMargin: 8
                            anchors.verticalCenter: batteryPill.verticalCenter
                            spacing: 6
                            opacity: surface.showProfiles ? 1.0 : 0.0
                            visible: opacity > 0
                            Behavior on opacity { NumberAnimation { duration: 200 } }
                            Repeater {
                                model: [
                                    { id: "power-saver", icon: "\uEC1A" },
                                    { id: "balanced", icon: "\uEAF6" },
                                    { id: "performance", icon: "\uEB9B" },
                                ]
                                delegate: Rectangle {
                                    id: profItem
                                    required property var modelData
                                    property bool available: surface.availableProfiles.includes(modelData.id)
                                    width: 38; height: 38
                                    radius: 8
                                    color: surface.activeProfile === modelData.id ? Services.Colors.ghost : Services.Colors.surfaceAlpha(0.85)
                                    opacity: available ? 1.0 : 0.3
                                    border.color: Services.Colors.ghostAlpha(0.25)
                                    border.width: 1
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                    Text {
                                        anchors.centerIn: parent
                                        text: profItem.modelData.icon
                                        font.family: "Material Symbols Rounded"
                                        font.pixelSize: 16
                                        color: surface.activeProfile === profItem.modelData.id ? Services.Colors.abyss : Services.Colors.mist
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: profItem.available ? Qt.PointingHandCursor : Qt.ForbiddenCursor
                                        enabled: profItem.available
                                        onClicked: surface.setProfile(profItem.modelData.id)
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ── Intro: padlock snaps shut, then the lock screen fades in behind it ──
            Rectangle {
                id: introOverlay
                anchors.fill: parent
                color: Services.Colors.abyss
                z: 100
                opacity: 1.0
                visible: !surface.introDone

                Item {
                    id: introLock
                    anchors.centerIn: parent
                    width: 128; height: 128
                    scale: 0.55
                    opacity: 0.0

                    // Pulse that fires the moment the shackle snaps: a rounded
                    // square, not a circle — the rest of Ashen has no circles
                    Rectangle {
                        id: introRing
                        anchors.centerIn: parent
                        width: 128; height: 128
                        radius: width * 0.23
                        color: "transparent"
                        border.color: Services.Colors.ghost
                        border.width: 2
                        opacity: 0.0
                    }

                    Rectangle {
                        id: introTile
                        anchors.fill: parent
                        radius: 30
                        color: Services.Colors.surfaceAlpha(0.85)
                        border.color: Services.Colors.ghostAlpha(0.35)
                        border.width: 2

                        Text {
                            id: introGlyph
                            anchors.centerIn: parent
                            text: surface.lockShut ? surface.glyphLock : surface.glyphLockOpen
                            color: surface.lockShut ? Services.Colors.snow : Services.Colors.ghost
                            font.pixelSize: 64
                            font.family: "Material Symbols Rounded"
                            Behavior on color { ColorAnimation { duration: 180 } }
                        }
                    }
                }

                SequentialAnimation {
                    id: introAnim

                    // 1. padlock drops in, still open
                    ParallelAnimation {
                        NumberAnimation { target: introLock; property: "opacity"; to: 1.0; duration: 340; easing.type: Easing.OutCubic }
                        NumberAnimation { target: introLock; property: "scale"; to: 1.0; duration: 540; easing.type: Easing.OutBack }
                    }
                    // beat: the padlock sits there, open, long enough to read
                    PauseAnimation { duration: 340 }

                    // 2. shackle snaps shut: glyph swap + recoil + pulse
                    ScriptAction { script: surface.lockShut = true }
                    ParallelAnimation {
                        SequentialAnimation {
                            NumberAnimation { target: introLock; property: "scale"; to: 1.18; duration: 130; easing.type: Easing.OutQuad }
                            NumberAnimation { target: introLock; property: "scale"; to: 1.0; duration: 340; easing.type: Easing.OutBack }
                        }
                        ParallelAnimation {
                            NumberAnimation { target: introRing; property: "opacity"; from: 0.7; to: 0.0; duration: 700; easing.type: Easing.OutCubic }
                            NumberAnimation { target: introRing; property: "width"; from: 128; to: 300; duration: 700; easing.type: Easing.OutCubic }
                            NumberAnimation { target: introRing; property: "height"; from: 128; to: 300; duration: 700; easing.type: Easing.OutCubic }
                        }
                    }
                    PauseAnimation { duration: 380 }

                    // 3. hand off to the lock screen
                    ScriptAction { script: surface.revealed = true }
                    ParallelAnimation {
                        NumberAnimation { target: introOverlay; property: "opacity"; to: 0.0; duration: 520; easing.type: Easing.InOutQuad }
                        NumberAnimation { target: introLock; property: "opacity"; to: 0.0; duration: 380; easing.type: Easing.InQuad }
                        NumberAnimation { target: introLock; property: "scale"; to: 1.6; duration: 520; easing.type: Easing.InCubic }
                    }
                    ScriptAction { script: surface.introDone = true }
                }
            }
        }
    }
}
