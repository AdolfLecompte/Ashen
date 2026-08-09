import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Services.Pam
import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Layouts
import "root:/services" as Services
import "root:/modules/widgets" as Widgets

Scope {
    id: root

    IpcHandler {
        target: "lockscreen"
        function lock() {
            sessionLock.locked = true
        }
    }

    // The in-process route, for callers that are already inside this shell.
    Connections {
        target: Services.AppState
        function onLockRequested() { sessionLock.locked = true }
    }

    WlSessionLock {
        id: sessionLock


        WlSessionLockSurface {
            id: surface

            // Material Symbols codepoints
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
            // The two readings at the foot of the screen, each of which opens
            // into its own card. Only one at a time: two morphs on top of each
            // other is a mess, and the second one covers the first.
            property bool lockBatteryOpen: false
            property bool lockWeatherOpen: false
            function openLockCard(which) {
                surface.lockBatteryOpen = which === "battery" && !surface.lockBatteryOpen
                surface.lockWeatherOpen = which === "weather" && !surface.lockWeatherOpen
            }
            property int battery: 0
            property bool charging: false
            property string wallpaper: ""
            property bool revealed: false
            property bool unlocking: false

            // The Wayland protocol builds one of these PER OUTPUT, so with two
            // screens there are two of everything below -- two password fields
            // with a caret blinking in each, two PamContexts, and only one of
            // them receiving keys. The login belongs to the screen you are
            // looking at; the rest stay at rest, showing the time.
            //
            // Screens.active always resolves to exactly one screen (it falls
            // back to the first), so this can never be true twice or false
            // everywhere -- which is what would lock you out.
            readonly property bool loginFace: {
                const a = Services.Screens.active
                if (!a || !surface.screen) return true
                return surface.screen.name === a.name
            }

            // Two states, one driver. At rest the screen only tells you things:
            // the time, the weather, the battery, what is playing. Touch it and
            // it becomes something to answer -- the clock steps aside, and the
            // face and the field take the middle.
            property bool authing: false
            property real auth: 0
            Behavior on auth {
                NumberAnimation { duration: Services.Sizes.msPanel; easing.type: Services.Sizes.easeOut }
            }
            onAuthingChanged: surface.auth = authing ? 1 : 0
            // Typing is asking to log in, so the field never has to be found
            // first. It already holds focus, which is what makes this work.
            function beginAuth() {
                // A key or a click on a screen that is not the login one must
                // not turn it into a second question.
                if (!surface.authing && surface.loginFace) surface.authing = true
            }

            // Intro: the padlock snaps shut before the lock screen itself fades in
            property bool introDone: false
            property bool lockShut: false

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
                    // After resume the field can lose keyboard focus (mouse still
                    // works). Re-grab it so the password is always typeable without
                    // needing a click. No-op when it already has focus.
                    // Only from the login screen: with a surface per output, every
                    // one of them grabbing once a second is a tug of war.
                    if (surface.loginFace && !surface.unlocking && !passInput.activeFocus)
                        passInput.forceActiveFocus()
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
                // Adapter name varies (AC0/ADP1/…); read whichever exposes `online`.
                command: ["sh", "-c", "cat /sys/class/power_supply/A*/online 2>/dev/null | grep -q 1 && echo 1 || echo 0"]
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

            // Persistent blurred-wallpaper backdrop, shared by the intro overlay
            // and the lock content so both sit on the same background (no black
            // flash during the intro). surface.wallpaper is already resolved to a
            // still — or the extracted video frame — by wallpaperProc.
            Item {
                id: bgLayer
                anchors.fill: parent

                // The veil is the background tone, so on a light palette it is
                // pale: laid on as thick as the dark one it turns the wallpaper
                // into a white film. Light schemes need only enough of it to
                // keep the near-black text legible.
                readonly property bool pale: Services.Colors.lightTheme
                readonly property real wallOpacity: pale ? 0.85 : 0.45
                readonly property real veilTop: pale ? 0.12 : 0.45
                readonly property real veilMid: pale ? 0.20 : 0.62
                readonly property real veilBottom: pale ? 0.38 : 0.80

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
                    opacity: bgLayer.wallOpacity
                }
                // Vignette: the background tone deepens towards the edges so the
                // corner pills stay readable over any wallpaper.
                Rectangle {
                    anchors.fill: parent
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: Qt.rgba(Services.Colors.abyss.r, Services.Colors.abyss.g, Services.Colors.abyss.b, bgLayer.veilTop) }
                        GradientStop { position: 0.5; color: Qt.rgba(Services.Colors.abyss.r, Services.Colors.abyss.g, Services.Colors.abyss.b, bgLayer.veilMid) }
                        GradientStop { position: 1.0; color: Qt.rgba(Services.Colors.abyss.r, Services.Colors.abyss.g, Services.Colors.abyss.b, bgLayer.veilBottom) }
                    }
                }
            }

            // ── Main content (with enter/exit animation) ──
            Item {
                id: content
                anchors.fill: parent
                opacity: surface.unlocking ? 0.0 : (surface.revealed ? 1.0 : 0.0)
                scale: surface.unlocking ? 1.04 : (surface.revealed ? 1.0 : 1.05)
                Behavior on opacity { NumberAnimation { duration: Services.Sizes.msEmphasis; easing.type: Services.Sizes.easeOut } }
                Behavior on scale { NumberAnimation { duration: Services.Sizes.msPanel; easing.type: Services.Sizes.easeOut } }

                Item {
                    anchors.fill: parent

                    // Anything at all asks to log in: at rest this screen is a
                    // readout, and the first touch turns it into a question.
                    MouseArea {
                        anchors.fill: parent
                        z: -1
                        onClicked: surface.beginAuth()
                    }

                    // ── At rest: the time, the weather, the battery, the music ──
                    Item {
                        id: idleGroup
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: parent.width
                        // Measured by the clock alone. The music fades in place
                        // and must not drag the login around as it goes.
                        height: clockCol.height
                        // Steps up out of the way rather than vanishing: it is
                        // the same clock, just no longer the whole screen.
                        y: (parent.height - height) / 2 - surface.auth * 200

                                Column {
                                    id: clockCol
                                    anchors.top: parent.top
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    spacing: 0
                                    // Smaller once it is no longer the only thing here.
                                    scale: 1 - surface.auth * 0.32
                                    transformOrigin: Item.Center
                                    Row {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        spacing: 0
                                        Text {
                                            text: surface.currentTime.split(" ")[0].split(":").slice(0, 2).join(":")
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
                                    // Only the date: the weather glyph and the battery have capsules of
                                    // their own at the foot of the screen now.
                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        topPadding: 6
                                        text: surface.currentDay + "  ·  " + surface.currentDate
                                        color: Services.Colors.snowAlpha(0.5)
                                        font.pixelSize: 15
                                        font.family: "JetBrainsMono NF"
                                        font.weight: Font.Bold
                                        font.letterSpacing: 1
                                    }
                                }

                                // ── What is playing, under the clock ──
                                // The very same item the bar's media panel morphs into, so
                                // the two never drift apart: this screen just puts a plate
                                // behind it and lets it be.
                                Rectangle {
                                    id: musicCard
                                    anchors.top: clockCol.bottom
                                    anchors.topMargin: 28
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    width: lockMedia.contentW + lockMedia.pad * 2
                                    height: lockMedia.artSize + lockMedia.pad * 2
                                    radius: 20
                                    clip: true
                                    color: Services.Colors.surfacePill

                                    // Arriving with the player is its own fade; going away because the screen
                                    // is asking for a password rides the driver. One Behavior over both
                                    // smoothed an already animated value twice.
                                    property real playerFade: lockMedia.hasPlayer ? 1.0 : 0.0
                                    Behavior on playerFade { NumberAnimation { duration: Services.Sizes.msPronounced } }
                                    // Gone by halfway, because the login lands
                                    // in the space it is leaving: the two must
                                    // never be on screen together.
                                    // On the login screen only: its transport is
                                    // something you press, and three copies of
                                    // one song is noise, not information.
                                    opacity: surface.loginFace
                                        ? playerFade * (1 - Math.min(1, surface.auth * 2)) : 0
                                    // Settings > System > Lock Screen can drop the card
                                    visible: Services.Prefs.lockShowMedia && opacity > 0.01
                                    transform: Translate {
                                        y: lockMedia.hasPlayer ? 0 : -16
                                        Behavior on y { NumberAnimation { duration: Services.Sizes.msPronounced; easing.type: Services.Sizes.easeOut } }
                                    }

                                    Widgets.MediaCard {
                                        id: lockMedia
                                        anchors.centerIn: parent
                                    }
                                }
                    }

                    // ── Once asked: the face and the field ──
                    Item {
                        id: authGroup
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: idleGroup.y + idleGroup.height + 56
                        width: authRow.width
                        height: authRow.height
                        // The second half of the move, once the music has gone.
                        readonly property real enter: Math.max(0, surface.auth * 2 - 1)
                        opacity: surface.loginFace ? authGroup.enter : 0
                        visible: opacity > 0.01
                        transform: Translate { y: (1 - authGroup.enter) * 26 }

                    // The face and the field, once you have asked to log in.
                    Row {
                        id: authRow
                        spacing: 24

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 180; height: 180
                            radius: 34
                            clip: true
                            color: Services.Colors.ghostAlpha(0.15)
                            border.color: surface.checking ? Services.Colors.ghost : Services.Colors.ghostAlpha(0.35)
                            border.width: 2
                            Behavior on border.color { ColorAnimation { duration: Services.Sizes.msStandard } }
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
                                radius: 32
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
                                font.pixelSize: 88
                                font.family: "Material Symbols Rounded"
                                visible: faceImg.status !== Image.Ready
                            }
                        }

                        // Right block spans the avatar height: name pinned to the top,
                        // password field pinned to the bottom (no card, just aligned edges).
                        Item {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 340
                            height: 180

                            Text {
                                anchors.bottom: passField.top
                                anchors.bottomMargin: 12
                                anchors.left: passField.left
                                text: Services.AppState.userLabel
                                color: Services.Colors.snow
                                font.pixelSize: 24
                                font.family: "JetBrainsMono NF"
                                font.weight: Font.Bold
                                font.letterSpacing: 1
                            }

                            SequentialAnimation {
                                id: shakeAnim
                                NumberAnimation { target: shakeT; property: "x"; to:  9; duration: 55 }
                                NumberAnimation { target: shakeT; property: "x"; to: -8; duration: 55 }
                                NumberAnimation { target: shakeT; property: "x"; to:  6; duration: 55 }
                                NumberAnimation { target: shakeT; property: "x"; to: -4; duration: 55 }
                                NumberAnimation { target: shakeT; property: "x"; to:  0; duration: 55 }
                            }

                            // Password field pinned to the avatar's bottom edge; it shakes
                            // on a wrong password (the transform lives on the field now).
                            Rectangle {
                                id: passField
                                anchors.bottom: parent.bottom
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: 340; height: 52
                                transform: Translate { id: shakeT; x: 0 }
                                radius: 12
                                color: Services.Colors.surfacePill
                                border.color: surface.errorMsg !== "" ? Services.Colors.error_
                                    : passInput.activeFocus ? Services.Colors.ghost
                                    : Services.Colors.ghostAlpha(0.25)
                                border.width: 1
                                Behavior on border.color { ColorAnimation { duration: Services.Sizes.msMicro } }

                                // Click to (re)grab keyboard focus. Helps when the
                                // field loses activeFocus (e.g. after resume) so the
                                // user can recover it with the mouse instead of typing.
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.IBeamCursor
                                    onClicked: passInput.forceActiveFocus()
                                }

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
                                        Behavior on color { ColorAnimation { duration: Services.Sizes.msMicro } }
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
                                                    width: 11; height: 11; radius: 5
                                                    color: Services.Colors.ghost
                                                    gradient: Services.Prefs.useGradients ? Services.Colors.accentGradient : null
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    // Fade in (no bounce): OutBack scale felt springy
                                                    NumberAnimation on opacity {
                                                        from: 0; to: 1; duration: Services.Sizes.msMicro
                                                        easing.type: Services.Sizes.easeOut
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
                                            onTextChanged: {
                                                surface.password = text
                                                if (text.length > 0) surface.beginAuth()
                                            }
                                            Keys.onReturnPressed: surface.tryUnlock()
                                            // Escape clears what you typed; a
                                            // second one hands the screen back
                                            // to the clock.
                                            Keys.onEscapePressed: {
                                                if (text.length === 0) {
                                                    surface.authing = false
                                                    surface.showPower = false
                                                    surface.showProfiles = false
                                                } else {
                                                    text = ""
                                                    surface.errorMsg = ""
                                                }
                                            }
                                        }
                                    }
                                    Text {
                                        text: "\uE627"
                                        color: surface.checking ? Services.Colors.ghost : Services.Colors.ash
                                        font.pixelSize: 18
                                        font.family: "Material Symbols Rounded"
                                        Behavior on color { ColorAnimation { duration: Services.Sizes.msMicro } }
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
                                anchors.top: passField.bottom
                                anchors.topMargin: 6
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
                                    Behavior on opacity { NumberAnimation { duration: Services.Sizes.msStandard } }
                                }
                            }
                        }
                    }
                    }

                    // ── At the foot: the two readings that used to be strung
                    //    through the clock's date line ──
                    // Each capsule BECOMES its card, the way the media pill becomes the media
                    // panel. Readable at rest, gone the moment the screen asks a question.
                    Row {
                        id: capsRow
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 44
                        spacing: 12
                        // The capsules open cards you have to be able to reach,
                        // so they live on the screen the pointer is on. They
                        // stay through the login: typing a password is no reason
                        // to stop being able to read the battery or change a
                        // power profile.
                        opacity: surface.loginFace ? 1 : 0
                        visible: opacity > 0.01

                        LockCapsule {
                            id: batCap
                            glyph: surface.charging ? "\ue1a3"
                                 : surface.battery >= 90 ? "\ue1a5"
                                 : surface.battery >= 50 ? "\uf0a1"
                                 : surface.battery >= 20 ? "\uf09f" : "\ue19c"
                            label: surface.battery + "%"
                            tone: surface.charging ? Services.Colors.ghost
                                : surface.battery < 20 ? Services.Colors.error_
                                : Services.Colors.mist
                            // While its card is wearing its face, the capsule
                            // stands aside rather than sitting under it.
                            standAside: batPanel.wearingFace
                            onPicked: surface.openLockCard("battery")
                        }

                        LockCapsule {
                            id: wxCap
                            glyph: Services.Weather.icon
                            label: Services.Weather.temp
                            standAside: wxPanel.wearingFace
                            onPicked: surface.openLockCard("weather")
                        }
                    }

                    LockBatteryPanel {
                        id: batPanel
                        anchors.fill: parent
                        shown: surface.lockBatteryOpen
                        pillCX: capsRow.x + batCap.x + batCap.width / 2
                        pillCY: capsRow.y + batCap.height / 2
                        pillW: batCap.width
                        pillH: batCap.height
                        battery: surface.battery
                        charging: surface.charging
                        profiles: surface.availableProfiles
                        activeProfile: surface.activeProfile
                        onProfilePicked: id => surface.setProfile(id)
                        onDismissed: surface.lockBatteryOpen = false
                    }

                    LockWeatherPanel {
                        id: wxPanel
                        anchors.fill: parent
                        shown: surface.lockWeatherOpen
                        pillCX: capsRow.x + wxCap.x + wxCap.width / 2
                        pillCY: capsRow.y + wxCap.height / 2
                        pillW: wxCap.width
                        pillH: wxCap.height
                        onDismissed: surface.lockWeatherOpen = false
                    }

                    // ── Bottom right corner: power, and nothing else ──
                    // On screen the whole time, like the capsules at the foot:
                    // the way out of the machine should not be something you
                    // only find by starting to log in.
                    Item {
                        id: cornerArea
                        anchors.bottom: parent.bottom
                        anchors.right: parent.right
                        anchors.margins: 24
                        width: powerPill.width
                        height: powerPill.height
                        opacity: surface.loginFace ? 1 : 0
                        visible: opacity > 0.01

                        // -- Power: pill fixed on the right, options expand UPWARDS --
                        Rectangle {
                            id: powerPill
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            width: 44; height: 44
                            radius: Services.Sizes.innerR
                            color: Services.Colors.surfacePill
                            Text {
                                anchors.centerIn: parent
                                text: "\uF8C7"
                                color: surface.showPower || powerPillHover.containsMouse
                                     ? Services.Colors.snow : Services.Colors.mist
                                font.pixelSize: 24
                                font.family: "Material Symbols Rounded"
                                Behavior on color { ColorAnimation { duration: Services.Sizes.msMicro } }
                                // The shell's one hover language: it grows and
                                // brightens, the plate never lights up.
                                scale: Services.Sizes.hoverScale(powerPillHover.containsMouse, powerPillHover.pressed)
                                Behavior on scale { NumberAnimation { duration: Services.Sizes.pillHoverMs; easing.type: Services.Sizes.easeOut } }
                            }
                            MouseArea {
                                id: powerPillHover
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                hoverEnabled: true
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
                            // Same deploy as the system (bar) panels: fade + slide in
                            // from the direction it opens — upwards, so it rises from below.
                            Behavior on opacity { NumberAnimation { duration: Services.Sizes.msStandard; easing.type: Services.Sizes.easeOut } }
                            transform: Translate {
                                y: surface.showPower ? 0 : 12
                                Behavior on y { NumberAnimation { duration: Services.Sizes.msStandard; easing.type: Services.Sizes.easeOut } }
                            }
                            Repeater {
                                // Nothing here is red: error_ is for something
                                // that went wrong, and shutting the machine down
                                // on purpose is not that.
                                model: [
                                    { icon: "\uF8C7", label: "Shut down", cmd: "systemctl poweroff" },
                                    { icon: "\uF053", label: "Restart",   cmd: "systemctl reboot"   },
                                    { icon: "\uF159", label: "Suspend",   cmd: "systemctl suspend"  },
                                ]
                                delegate: Rectangle {
                                    id: powerItem
                                    required property var modelData
                                    anchors.right: parent.right
                                    width: 44; height: 44
                                    radius: Services.Sizes.innerR
                                    color: Services.Colors.surfacePill

                                    Text {
                                        anchors.centerIn: parent
                                        text: powerItem.modelData.icon
                                        color: powerHover.containsMouse ? Services.Colors.snow
                                                                        : Services.Colors.mist
                                        font.pixelSize: 24
                                        font.family: "Material Symbols Rounded"
                                        Behavior on color { ColorAnimation { duration: Services.Sizes.msMicro } }
                                        scale: Services.Sizes.hoverScale(powerHover.containsMouse, powerHover.pressed)
                                        Behavior on scale { NumberAnimation { duration: Services.Sizes.pillHoverMs; easing.type: Services.Sizes.easeOut } }
                                    }

                                    // The word only while you are on it: the
                                    // tiles are icons, and the name is what says
                                    // which one you are about to press.
                                    Rectangle {
                                        anchors.right: parent.left
                                        anchors.rightMargin: 8
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: tipText.width + 16
                                        height: 26
                                        radius: Services.Sizes.pillR
                                        color: Services.Colors.surfacePill
                                        opacity: powerHover.containsMouse ? 1 : 0
                                        visible: opacity > 0.01
                                        Behavior on opacity { NumberAnimation { duration: Services.Sizes.msMicro } }
                                        Text {
                                            id: tipText
                                            anchors.centerIn: parent
                                            text: powerItem.modelData.label
                                            color: Services.Colors.snow
                                            font.pixelSize: Services.Sizes.fsMeta
                                            font.bold: true
                                            font.family: "JetBrainsMono NF"
                                        }
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

                    }
                }
            }

            // ── Shared pieces ──────────────────────────────────────────
            // A reading at the foot of the lock screen. Hover grows it and
            // brightens what it says; the plate never changes colour.
            component LockCapsule: Rectangle {
                id: cap
                property string glyph: ""
                property string label: ""
                property color tone: Services.Colors.mist
                // Its card has taken over its face.
                property bool standAside: false

                signal picked()

                width: capRow.width + 28
                height: 44
                radius: Services.Sizes.pillR
                color: Services.Colors.surfacePill
                opacity: standAside ? 0 : 1
                Behavior on opacity { NumberAnimation { duration: Services.Sizes.msMicro } }

                scale: Services.Sizes.hoverScale(capHover.containsMouse, capHover.pressed)
                Behavior on scale { NumberAnimation { duration: Services.Sizes.pillHoverMs; easing.type: Services.Sizes.easeOut } }

                Row {
                    id: capRow
                    anchors.centerIn: parent
                    spacing: 8
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: cap.glyph
                        color: capHover.containsMouse ? Services.Colors.snow : cap.tone
                        font.pixelSize: 18
                        font.family: "Material Symbols Rounded"
                        Behavior on color { ColorAnimation { duration: Services.Sizes.msMicro } }
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: cap.label
                        color: capHover.containsMouse ? Services.Colors.snow : cap.tone
                        font.pixelSize: 14
                        font.bold: true
                        font.family: "JetBrainsMono NF"
                        Behavior on color { ColorAnimation { duration: Services.Sizes.msMicro } }
                    }
                }

                MouseArea {
                    id: capHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: cap.picked()
                }
            }

            // ── Intro: padlock snaps shut, then the lock screen fades in behind it ──
            Rectangle {
                id: introOverlay
                anchors.fill: parent
                // transparent: the shared bgLayer blur shows through behind the
                // padlock, instead of a black cover, during the intro
                color: "transparent"
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
                        color: Services.Colors.surfacePill
                        border.color: Services.Colors.ghostAlpha(0.35)
                        border.width: 2

                        Text {
                            id: introGlyph
                            anchors.centerIn: parent
                            text: surface.lockShut ? surface.glyphLock : surface.glyphLockOpen
                            color: surface.lockShut ? Services.Colors.snow : Services.Colors.ghost
                            font.pixelSize: 64
                            font.family: "Material Symbols Rounded"
                            Behavior on color { ColorAnimation { duration: Services.Sizes.msStandard } }
                        }
                    }
                }

                SequentialAnimation {
                    id: introAnim

                    // 1. padlock drops in, still open
                    ParallelAnimation {
                        NumberAnimation { target: introLock; property: "opacity"; to: 1.0; duration: 340; easing.type: Services.Sizes.easeOut }
                        NumberAnimation { target: introLock; property: "scale"; to: 1.0; duration: 540; easing.type: Easing.OutBack; easing.overshoot: Services.Sizes.overshoot }
                    }
                    // beat: the padlock sits there, open, long enough to read
                    PauseAnimation { duration: 340 }

                    // 2. shackle snaps shut: glyph swap + recoil + pulse
                    ScriptAction { script: surface.lockShut = true }
                    ParallelAnimation {
                        SequentialAnimation {
                            NumberAnimation { target: introLock; property: "scale"; to: 1.18; duration: 130; easing.type: Easing.OutQuad }
                            NumberAnimation { target: introLock; property: "scale"; to: 1.0; duration: 340; easing.type: Easing.OutBack; easing.overshoot: Services.Sizes.overshoot }
                        }
                        ParallelAnimation {
                            NumberAnimation { target: introRing; property: "opacity"; from: 0.7; to: 0.0; duration: 700; easing.type: Services.Sizes.easeOut }
                            NumberAnimation { target: introRing; property: "width"; from: 128; to: 300; duration: 700; easing.type: Services.Sizes.easeOut }
                            NumberAnimation { target: introRing; property: "height"; from: 128; to: 300; duration: 700; easing.type: Services.Sizes.easeOut }
                        }
                    }
                    PauseAnimation { duration: 380 }

                    // 3. hand off to the lock screen
                    ScriptAction { script: surface.revealed = true }
                    ParallelAnimation {
                        NumberAnimation { target: introOverlay; property: "opacity"; to: 0.0; duration: 520; easing.type: Easing.InOutQuad }
                        NumberAnimation { target: introLock; property: "opacity"; to: 0.0; duration: 380; easing.type: Easing.InQuad }
                        NumberAnimation { target: introLock; property: "scale"; to: 1.6; duration: 520; easing.type: Services.Sizes.easeIn }
                    }
                    ScriptAction { script: surface.introDone = true }
                }
            }
        }
    }
}
