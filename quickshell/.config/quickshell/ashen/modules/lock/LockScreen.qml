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
            property bool showProfiles: false
            property int battery: 0
            property bool charging: false
            property string wallpaper: ""
            property bool revealed: false
            property bool unlocking: false

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
                    if (!surface.unlocking && !passInput.activeFocus) passInput.forceActiveFocus()
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
            }

            // ── Main content (with enter/exit animation) ──
            Item {
                id: content
                anchors.fill: parent
                opacity: surface.unlocking ? 0.0 : (surface.revealed ? 1.0 : 0.0)
                scale: surface.unlocking ? 1.04 : (surface.revealed ? 1.0 : 1.05)
                Behavior on opacity { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
                Behavior on scale { NumberAnimation { duration: 420; easing.type: Easing.OutCubic } }

                Item {
                    anchors.fill: parent

                    // ── Clock: editorial, anchored top-left ──
                    Column {
                        id: clockCol
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.margins: 48
                        spacing: 0
                        Row {
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
                        Row {
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

                    // ── Recent notifications: last 5 app notifications, under the clock ──
                    Column {
                        anchors.top: clockCol.bottom
                        anchors.left: clockCol.left
                        anchors.topMargin: 30
                        spacing: 12
                        width: 360

                        Repeater {
                            model: Services.Notifications.history.filter(n => n.source !== "system").slice(0, 5)
                            delegate: Row {
                                required property var modelData
                                spacing: 10

                                // App icon (e.g. WhatsApp); falls back to the accent
                                // dot when the notification carries no usable icon.
                                Item {
                                    width: 18; height: 18
                                    y: 1
                                    Image {
                                        id: notifIcon
                                        anchors.fill: parent
                                        source: modelData.icon || ""
                                        sourceSize.width: 36
                                        sourceSize.height: 36
                                        fillMode: Image.PreserveAspectFit
                                        smooth: true
                                        visible: status === Image.Ready
                                    }
                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: 6; height: 6; radius: 3
                                        color: Services.Colors.ghost
                                        gradient: Services.Prefs.useGradients ? Services.Colors.accentGradient : null
                                        visible: notifIcon.status !== Image.Ready
                                    }
                                }
                                Column {
                                    spacing: 1
                                    Text {
                                        text: modelData.summary && modelData.summary.length > 0 ? modelData.summary : (modelData.appName || "")
                                        color: Services.Colors.snowAlpha(0.85)
                                        font.pixelSize: 12
                                        font.family: "JetBrainsMono NF"
                                        font.weight: Font.Bold
                                        elide: Text.ElideRight
                                        width: 324
                                    }
                                    Text {
                                        text: modelData.body || ""
                                        visible: text.length > 0
                                        color: Services.Colors.snowAlpha(0.45)
                                        font.pixelSize: 11
                                        font.family: "JetBrainsMono NF"
                                        elide: Text.ElideRight
                                        width: 324
                                    }
                                }
                            }
                        }
                    }

                    // ── Centre: avatar · password ──
                    Row {
                        anchors.centerIn: parent
                        spacing: 24

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 180; height: 180
                            radius: 34
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
                                Behavior on border.color { ColorAnimation { duration: 150 } }

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
                                                    width: 11; height: 11; radius: 5
                                                    color: Services.Colors.ghost
                                                    gradient: Services.Prefs.useGradients ? Services.Colors.accentGradient : null
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    // Fade in (no bounce): OutBack scale felt springy
                                                    NumberAnimation on opacity {
                                                        from: 0; to: 1; duration: 150
                                                        easing.type: Easing.OutCubic
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
                                    Behavior on opacity { NumberAnimation { duration: 200 } }
                                }
                            }
                        }
                    }

                    // ── Music card (top right) ──
                    // The very same item the bar's media panel morphs into, so
                    // the two never drift apart: this screen just puts a plate
                    // behind it and lets it be.
                    Rectangle {
                        id: musicCard
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 48
                        width: lockMedia.contentW + lockMedia.pad * 2
                        height: lockMedia.artSize + lockMedia.pad * 2
                        radius: 20
                        clip: true
                        color: Services.Colors.surfacePill

                        opacity: lockMedia.hasPlayer ? 1.0 : 0.0
                        // Settings > System > Lock Screen can drop the card
                        visible: Services.Prefs.lockShowMedia && opacity > 0
                        Behavior on opacity { NumberAnimation { duration: 250 } }
                        transform: Translate {
                            y: lockMedia.hasPlayer ? 0 : -16
                            Behavior on y { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                        }

                        Widgets.MediaCard {
                            id: lockMedia
                            anchors.centerIn: parent
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
                            color: powerPillHover.containsMouse ? Services.Colors.elevated : Services.Colors.surfacePill
                            Behavior on color { ColorAnimation { duration: 150 } }
                            Text {
                                anchors.centerIn: parent
                                text: "\uF8C7"
                                color: surface.showPower ? Services.Colors.snow : Services.Colors.mist
                                font.pixelSize: 20
                                font.family: "Material Symbols Rounded"
                                Behavior on color { ColorAnimation { duration: 150 } }
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
                            Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                            transform: Translate {
                                y: surface.showPower ? 0 : 12
                                Behavior on y { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                            }
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
                                    // Declarative hover: assigning color in onEntered kills the binding.
                                    // Opaque hover tone (not a translucent ghost) so it brightens
                                    // smoothly instead of jumping to transparent over the backdrop.
                                    color: powerHover.containsMouse ? Services.Colors.elevated
                                                                    : Services.Colors.surfacePill
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
                            color: batteryPillHover.containsMouse ? Services.Colors.elevated : Services.Colors.surfacePill
                            Behavior on color { ColorAnimation { duration: 150 } }
                            Row {
                                anchors.centerIn: parent
                                spacing: 4
                                Text {
                                    text: surface.charging ? "\uE1A3" : surface.battery >= 90 ? "\uE1A5" : surface.battery >= 50 ? "\uF0A1" : surface.battery >= 20 ? "\uF09F" : "\uE19C"
                                    // Charging = accent (ghost) so the state reads at a glance;
                                    // error_ only for a genuinely low battery on its own power.
                                    color: surface.charging ? Services.Colors.ghost
                                        : surface.battery < 20 ? Services.Colors.error_ : Services.Colors.mist
                                    font.pixelSize: 18
                                    font.family: "Material Symbols Rounded"
                                    anchors.verticalCenter: parent.verticalCenter
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                }
                                Text {
                                    text: surface.battery + "%"
                                    color: surface.charging ? Services.Colors.ghost
                                        : surface.battery < 20 ? Services.Colors.error_ : Services.Colors.mist
                                    font.pixelSize: 12
                                    font.family: "JetBrainsMono NF"
                                    anchors.verticalCenter: parent.verticalCenter
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                }
                            }
                            MouseArea {
                                id: batteryPillHover
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                hoverEnabled: true
                                onClicked: surface.showProfiles = !surface.showProfiles
                            }
                        }

                        // Profiles as a single capsule (like the bar workspaces): one
                        // pill holds the three icons, with a sliding accent indicator
                        // behind the active one — instead of three separate tiles.
                        Rectangle {
                            id: profileCapsule
                            anchors.right: batteryPill.left
                            anchors.rightMargin: 8
                            anchors.verticalCenter: batteryPill.verticalCenter
                            height: 44
                            radius: 10
                            color: Services.Colors.surfacePill
                            width: profRow.width + 16
                            opacity: surface.showProfiles ? 1.0 : 0.0
                            visible: opacity > 0
                            // Same deploy as the system (bar) panels: fade + slide in
                            // from the direction it opens — leftwards, so it enters from the right.
                            Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                            transform: Translate {
                                x: surface.showProfiles ? 0 : 12
                                Behavior on x { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                            }

                            readonly property var profModel: [
                                { id: "power-saver", icon: "" },
                                { id: "balanced", icon: "" },
                                { id: "performance", icon: "" },
                            ]
                            readonly property int activeIdx: {
                                for (let i = 0; i < profModel.length; i++)
                                    if (profModel[i].id === surface.activeProfile) return i
                                return -1
                            }

                            // Sliding accent indicator behind the active profile
                            Rectangle {
                                id: profSlide
                                width: 34; height: 34; radius: 8
                                color: Services.Colors.ghost
                                gradient: Services.Prefs.useGradients ? Services.Colors.accentGradient : null
                                y: (parent.height - height) / 2
                                x: 8 + profileCapsule.activeIdx * (34 + 4)
                                opacity: profileCapsule.activeIdx >= 0 ? 1 : 0
                                Behavior on opacity { NumberAnimation { duration: 200 } }
                                Behavior on x { SmoothedAnimation { duration: 250 } }
                            }

                            Row {
                                id: profRow
                                anchors.centerIn: parent
                                spacing: 4
                                Repeater {
                                    model: profileCapsule.profModel
                                    delegate: Item {
                                    id: profItem
                                    required property var modelData
                                    property bool available: surface.availableProfiles.includes(modelData.id)
                                    property bool isActive: surface.activeProfile === modelData.id
                                    width: 34; height: 34
                                    opacity: available ? 1.0 : 0.3

                                    // Hover brightens available, non-active slots
                                    Rectangle {
                                        anchors.fill: parent
                                        radius: 8
                                        color: Services.Colors.ghost
                                        gradient: Services.Prefs.useGradients ? Services.Colors.accentGradient : null
                                        opacity: profHover.containsMouse && profItem.available && !profItem.isActive ? 0.2 : 0
                                        Behavior on opacity { NumberAnimation { duration: 150 } }
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        text: profItem.modelData.icon
                                        font.family: "Material Symbols Rounded"
                                        font.pixelSize: 16
                                        color: profItem.isActive ? Services.Colors.abyss : Services.Colors.mist
                                        z: 1
                                        Behavior on color { ColorAnimation { duration: 200 } }
                                    }

                                    MouseArea {
                                        id: profHover
                                        anchors.fill: parent
                                        hoverEnabled: true
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
