import Quickshell
import Quickshell.Services.Mpris
import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import "root:/services" as Services

Item {
    id: root
    readonly property int pillH: 44

    // Raw MPRIS read: drops to null for a few ms while the player changes track
    property var livePlayer: {
        let list = Mpris.players.values.filter(p => p.playbackState !== MprisPlaybackState.Stopped)
        if (list.length === 0) return null
        let playing = list.find(p => p.isPlaying)
        return playing !== undefined ? playing : list[0]
    }

    // Held across that gap so the pill does not collapse or flicker
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
        onTriggered: if (root.livePlayer === null) {
            root.activePlayer = null
            root.stableArtUrl = ""
        }
    }
    function formatTime(seconds) {
        if (!seconds || seconds <= 0) return "0:00"
        let m = Math.floor(seconds / 60)
        let s = Math.floor(seconds % 60)
        return m + ":" + (s < 10 ? "0" : "") + s
    }
    function seekPrev() {
        if (!root.hasPlayer) return
        let p = root.activePlayer
        if (p.canGoPrevious) { p.previous(); return }
        if (p.canSeek) p.position = Math.max(0, p.position - 10)
    }
    function seekNext() {
        if (!root.hasPlayer) return
        let p = root.activePlayer
        if (p.canGoNext) { p.next(); return }
        if (p.canSeek) p.position = Math.min(p.length, p.position + 10)
    }
    property string stableArtUrl: ""
    function updateArt() {
        if (!root.hasPlayer) {
            root.stableArtUrl = ""
        } else if (root.activePlayer.trackArtUrl !== "") {
            root.stableArtUrl = root.activePlayer.trackArtUrl
        }
    }
    onActivePlayerChanged: updateArt()
    Connections {
        target: root.activePlayer
        ignoreUnknownSignals: true
        function onTrackArtUrlChanged() { root.updateArt() }
    }

    height: pillH
    width: hasPlayer ? expandedRow.implicitWidth + 20 : 0
    opacity: hasPlayer ? 1.0 : 0.0
    Behavior on width { SmoothedAnimation { duration: 280 } }
    Behavior on opacity { NumberAnimation { duration: 200 } }

    // Reports its real on-screen position so MediaPanel can center below it
    function reportPosition() {
        let g = root.mapToGlobal(0, 0)
        Services.AppState.mediaPillCenterX = g.x + root.width / 2
    }
    onXChanged: reportPosition()
onWidthChanged: reportPosition()
Component.onCompleted: { activePlayer = livePlayer; updateArt(); reportPosition() }

    Rectangle {
        anchors.fill: parent
        radius: 10
        color: Services.Colors.surfaceAlpha(0.82)
        border.color: Services.Colors.ghostAlpha(0.2)
        border.width: 1
        clip: true

        Row {
            id: expandedRow
            visible: root.hasPlayer
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.leftMargin: 10
            spacing: 8

            Rectangle {
    id: artFrame
    width: 30; height: 30
    radius: 8
    color: Services.Colors.abyss
    anchors.verticalCenter: parent.verticalCenter
    Image {
        id: pillArt
        anchors.fill: parent
        source: root.stableArtUrl
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        visible: false
        layer.enabled: true
        onSourceChanged: console.log("[MediaPill] trackArtUrl:", source)
        onStatusChanged: console.log("[MediaPill] Image status:", status, "for source:", source)
    }
    Rectangle {
        id: pillArtMask
        anchors.fill: parent
        radius: 8
        visible: false
        layer.enabled: true
    }
    OpacityMask {
        anchors.fill: parent
        source: pillArt
        maskSource: pillArtMask
        visible: pillArt.status === Image.Ready
    }
    Text {
        anchors.centerIn: parent
        visible: pillArt.status !== Image.Ready
        text: ""
        color: Services.Colors.ash
        font.family: "Material Symbols Rounded"
        font.pixelSize: 14
    }
}

            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 3
                width: 120

                Text {
                    width: parent.width
                    text: root.hasPlayer ? (root.activePlayer.trackTitle || "Untitled") : ""
                    color: Services.Colors.snow
                    font.pixelSize: 11
                    font.bold: true
                    font.family: "JetBrainsMono NF"
                    elide: Text.ElideRight
                }
                
    Text {
        width: parent.width
        visible: root.hasPlayer
        text: root.hasPlayer ? (root.formatTime(root.activePlayer.position) + "/" + root.formatTime(root.activePlayer.length)) : ""
        color: Services.Colors.mist
        font.pixelSize: 10
        font.family: "JetBrainsMono NF"
    }
            }

            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                Text {
                    text: ""
                    font.family: "Material Symbols Rounded"
                    font.pixelSize: 18
                    color: root.hasPlayer && root.activePlayer.canGoPrevious ? Services.Colors.ghost : Services.Colors.ash
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -6
                        cursorShape: Qt.PointingHandCursor
                        enabled: root.hasPlayer && root.activePlayer.canGoPrevious
                        onClicked: root.activePlayer.previous()
                    }
                }
                Text {
                    text: root.hasPlayer && root.activePlayer.isPlaying ? "" : ""
                    font.family: "Material Symbols Rounded"
                    font.pixelSize: 20
                    color: Services.Colors.ghost
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -6
                        cursorShape: Qt.PointingHandCursor
                        enabled: root.hasPlayer
                        onClicked: root.activePlayer.togglePlaying()
                    }
                }
                Text {
                    text: ""
                    font.family: "Material Symbols Rounded"
                    font.pixelSize: 18
                    color: root.hasPlayer && root.activePlayer.canGoNext ? Services.Colors.ghost : Services.Colors.ash
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -6
                        cursorShape: Qt.PointingHandCursor
                        enabled: root.hasPlayer && root.activePlayer.canGoNext
                        onClicked: root.activePlayer.next()
                    }
                }
            }
            
}

        
    }

    // Clicking any free area of the pill opens the expanded panel
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        z: -1
        onClicked: {
            if (root.hasPlayer) Services.AppState.mediaVisible = !Services.AppState.mediaVisible
        }
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.hasPlayer && root.activePlayer.isPlaying
        onTriggered: if (root.hasPlayer) root.activePlayer.positionChanged()
    }
}
