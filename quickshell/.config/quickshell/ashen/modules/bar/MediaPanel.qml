import Quickshell
import Quickshell.Services.Mpris
import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Layouts
import "root:/services" as Services

PanelWindow {
    id: root
    anchors { top: true; left: true; right: true; bottom: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    visible: Services.AppState.mediaVisible

    // Raw MPRIS read: drops to null for a few ms while the player changes track
    property var livePlayer: {
        let list = Mpris.players.values.filter(p => p.playbackState !== MprisPlaybackState.Stopped)
        if (list.length === 0) return null
        let playing = list.find(p => p.isPlaying)
        return playing !== undefined ? playing : list[0]
    }

    // Held across that gap so the panel does not flip to "Nothing playing"
    property var activePlayer: null
    property bool hasPlayer: activePlayer !== null

    onLivePlayerChanged: {
        if (livePlayer !== null) {
            dropTimer.stop()
            activePlayer = livePlayer
        } else {
            dropTimer.restart()
        }
    }

    Timer {
        id: dropTimer
        interval: 5000
        onTriggered: if (root.livePlayer === null) root.activePlayer = null
    }

    // Cache the values the browser sends intermittently
    // (they sometimes arrive empty for an instant before coming back)
    property string stableArtUrl: ""
    property string stableArtist: ""
    property string stableAlbum: ""
    function updateTrackInfo() {
        if (!root.hasPlayer) {
            root.stableArtUrl = ""
            root.stableArtist = ""
            root.stableAlbum = ""
            return
        }
        if (root.activePlayer.trackArtUrl !== "") root.stableArtUrl = root.activePlayer.trackArtUrl
        if (root.activePlayer.trackArtist !== "") root.stableArtist = root.activePlayer.trackArtist
        if (root.activePlayer.trackAlbum !== "") root.stableAlbum = root.activePlayer.trackAlbum
    }
    onActivePlayerChanged: {
        root.stableArtist = ""
        root.stableAlbum = ""
        updateTrackInfo()
    }
    Component.onCompleted: { activePlayer = livePlayer; updateTrackInfo() }
    Connections {
        target: root.activePlayer
        ignoreUnknownSignals: true
        function onTrackArtUrlChanged() { root.updateTrackInfo() }
        function onTrackArtistChanged() { root.updateTrackInfo() }
        function onTrackAlbumChanged() { root.updateTrackInfo() }
        function onTrackTitleChanged() {
            // new title = possibly a new song, so reset the old artist/album
            // to avoid carrying the previous one over if the new one is slow
            root.stableArtist = ""
            root.stableAlbum = ""
            root.updateTrackInfo()
        }
    }

    function formatTime(seconds) {
        if (!seconds || seconds <= 0) return "0:00"
        let m = Math.floor(seconds / 60)
        let s = Math.floor(seconds % 60)
        return m + ":" + (s < 10 ? "0" : "") + s
    }

    MouseArea {
        anchors.fill: parent
        z: -1
        onClicked: Services.AppState.mediaVisible = false
    }

    FocusScope {
        anchors.fill: parent
        focus: root.visible
        Keys.onEscapePressed: Services.AppState.mediaVisible = false
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.hasPlayer && root.activePlayer.isPlaying
        onTriggered: if (root.hasPlayer) root.activePlayer.positionChanged()
    }

    Rectangle {
        id: card
        anchors.top: parent.top
        anchors.topMargin: 64
        width: 520
        height: 190
        x: Math.max(12, Math.min(parent.width - width - 12, Services.AppState.mediaPillCenterX - width / 2))
        radius: 16
        color: Services.Colors.surfaceAlpha(0.95)
        border.color: Services.Colors.ghostAlpha(0.2)
        border.width: 1
        clip: true

        opacity: Services.AppState.mediaVisible ? 1.0 : 0.0
        scale: Services.AppState.mediaVisible ? 1.0 : 0.92
        Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

        transform: Translate {
            y: Services.AppState.mediaVisible ? 0 : -24
            Behavior on y { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
        }

        MouseArea { anchors.fill: parent; onClicked: {} }

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
                ctx.fillStyle = Services.Colors.ghostAlpha(0.10)
                for (var i = 0; i < n; i++) {
                    var v = Math.max(0, Math.min(100, vals[i])) / 100.0
                    var h = v * height * 0.6
                    ctx.fillRect(i * barW, height - h, Math.max(1, barW - 1), h)
                }
            }
        }

        RowLayout {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 18

            // Square art with rounded corners
            Item {
                width: 130; height: 130
                Layout.alignment: Qt.AlignVCenter

                Image {
                    id: art
                    anchors.fill: parent
                    source: root.stableArtUrl
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    visible: false
                }

                Rectangle {
                    id: artMask
                    anchors.fill: parent
                    radius: 16
                    visible: false
                }

                OpacityMask {
                    anchors.fill: parent
                    source: art
                    maskSource: artMask
                    visible: art.status === Image.Ready
                }

                Rectangle {
                    anchors.fill: parent
                    radius: 16
                    color: Services.Colors.abyss
                    visible: art.status !== Image.Ready
                    Text {
                        anchors.centerIn: parent
                        text: ""
                        color: Services.Colors.ash
                        font.family: "Material Symbols Rounded"
                        font.pixelSize: 28
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    radius: 16
                    color: "transparent"
                    border.color: Services.Colors.ghostAlpha(0.2)
                    border.width: 1
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 8

                Text {
                    text: root.hasPlayer ? (root.activePlayer.trackTitle || "Untitled") : "Nothing playing"
                    color: Services.Colors.snow
                    font.pixelSize: 18
                    font.bold: true
                    font.family: "JetBrainsMono NF"
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
                Text {
                    visible: root.stableArtist !== ""
                    text: root.stableArtist
                    color: Services.Colors.mist
                    font.pixelSize: 12
                    font.family: "JetBrainsMono NF"
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
                Text {
                    visible: root.stableAlbum !== ""
                    text: root.stableAlbum
                    color: Services.Colors.ash
                    font.pixelSize: 10
                    font.family: "JetBrainsMono NF"
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                Item { Layout.fillHeight: true }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    Item {
                        Layout.fillWidth: true
                        height: 6

                        Rectangle {
                            anchors.fill: parent
                            radius: 3
                            color: Services.Colors.ghostAlpha(0.15)
                        }

                        Rectangle {
                            id: fillBar
                            height: parent.height
                            radius: 3
                            color: Services.Colors.ghost
                            width: {
                                if (!root.hasPlayer || root.activePlayer.length <= 0) return 0
                                return parent.width * (root.activePlayer.position / root.activePlayer.length)
                            }
                            Behavior on width { NumberAnimation { duration: 300 } }
                        }

                        Rectangle {
                            id: thumb
                            width: 10; height: 10; radius: 5
                            color: Services.Colors.snow
                            anchors.verticalCenter: parent.verticalCenter
                            x: Math.max(0, fillBar.width - width / 2)
                            Behavior on x { NumberAnimation { duration: 300 } }

                            SequentialAnimation on scale {
                                running: root.hasPlayer && root.activePlayer.isPlaying
                                loops: Animation.Infinite
                                NumberAnimation { from: 0.85; to: 1.25; duration: 700; easing.type: Easing.InOutSine }
                                NumberAnimation { from: 1.25; to: 0.85; duration: 700; easing.type: Easing.InOutSine }
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: root.hasPlayer ? root.formatTime(root.activePlayer.position) : "0:00"
                            color: Services.Colors.ash
                            font.pixelSize: 10
                            font.family: "JetBrainsMono NF"
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: root.hasPlayer ? root.formatTime(root.activePlayer.length) : "0:00"
                            color: Services.Colors.ash
                            font.pixelSize: 10
                            font.family: "JetBrainsMono NF"
                        }
                    }
                }

                // Controls: prev/next enabled ONLY if the player really
                // supports skipping tracks (no seek fallback)
                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 20

                    Text {
                        text: ""
                        font.family: "Material Symbols Rounded"
                        font.pixelSize: 16
                        color: Services.Colors.mist
                        MouseArea { anchors.fill: parent; anchors.margins: -6; cursorShape: Qt.PointingHandCursor }
                    }
                    Text {
                        text: ""
                        font.family: "Material Symbols Rounded"
                        font.pixelSize: 20
                        color: root.hasPlayer && root.activePlayer.canGoPrevious ? Services.Colors.snow : Services.Colors.ash
                        MouseArea {
                            anchors.fill: parent; anchors.margins: -6
                            cursorShape: Qt.PointingHandCursor
                            enabled: root.hasPlayer && root.activePlayer.canGoPrevious
                            onClicked: root.activePlayer.previous()
                        }
                    }
                    Rectangle {
                        width: 44; height: 44; radius: 22
                        color: Services.Colors.ghost
                        Text {
                            anchors.centerIn: parent
                            text: root.hasPlayer && root.activePlayer.isPlaying ? "" : ""
                            font.family: "Material Symbols Rounded"
                            font.pixelSize: 20
                            color: Services.Colors.abyss
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            enabled: root.hasPlayer
                            onClicked: root.activePlayer.togglePlaying()
                        }
                    }
                    Text {
                        text: ""
                        font.family: "Material Symbols Rounded"
                        font.pixelSize: 20
                        color: root.hasPlayer && root.activePlayer.canGoNext ? Services.Colors.snow : Services.Colors.ash
                        MouseArea {
                            anchors.fill: parent; anchors.margins: -6
                            cursorShape: Qt.PointingHandCursor
                            enabled: root.hasPlayer && root.activePlayer.canGoNext
                            onClicked: root.activePlayer.next()
                        }
                    }
                    Text {
                        text: ""
                        font.family: "Material Symbols Rounded"
                        font.pixelSize: 16
                        color: Services.Colors.mist
                        MouseArea { anchors.fill: parent; anchors.margins: -6; cursorShape: Qt.PointingHandCursor }
                    }
                }
            }
        }
    }
}
