import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Mpris
import QtQuick
import QtQuick.Layouts
import "root:/services" as Services

// The "now playing" card, in one place. The bar's media panel and the lock
// screen both draw this exact item — the panel wraps it in the blob it morphs
// out of its pill, the lock screen just puts a plate behind it.
//
// Content only, no background: whoever mounts it owns the surface it sits on.
// `pad` is the padding that background is expected to leave, so both callers
// end up the same size.
//
// The cover sets the height and nothing is allowed past it: text hangs off the
// top edge, transport off the bottom, the way the lock screen's name and
// password sit either side of the avatar.
Item {
    id: root

    // ── Metrics ─────────────────────────────────────────────────────────
    readonly property real artSize: 160
    readonly property real cavaW: 130
    readonly property real gap: 18
    readonly property real pad: 20
    readonly property real contentW: 630
    readonly property real chipLg: 40
    readonly property real playLg: 48

    implicitWidth: contentW
    implicitHeight: artSize
    width: implicitWidth
    height: implicitHeight

    // ── Morph support ───────────────────────────────────────────────────
    // The media panel flies its own copies of the cover, the title, the two
    // times and the three transport chips in from the bar pill. With this on,
    // those pieces are still laid out (they are what the flying copies aim
    // at) but neither drawn nor clickable. Off, this is just the whole card.
    property bool ghostShared: false
    readonly property real sharedOpacity: ghostShared ? 0 : 1

    // Fade for everything the bar pill has no counterpart for. The panel drives
    // it so those pieces arrive after the blob has finished opening; the lock
    // screen leaves it at 1 and shows the whole card at once.
    property real extrasOpacity: 1

    // ── Player ──────────────────────────────────────────────────────────
    // Raw MPRIS read: drops to null for a few ms while the player changes track
    property var livePlayer: {
        let list = Mpris.players.values.filter(p => p.playbackState !== MprisPlaybackState.Stopped)
        if (list.length === 0) return null
        let playing = list.find(p => p.isPlaying)
        return playing !== undefined ? playing : list[0]
    }

    // Held across that gap so the card does not flip to "Nothing playing"
    property var activePlayer: null
    readonly property bool hasPlayer: activePlayer !== null

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

    // MPRIS only emits position on demand
    Timer {
        interval: 1000
        repeat: true
        running: root.activePlayer !== null && root.activePlayer.isPlaying
        onTriggered: if (root.hasPlayer) root.activePlayer.positionChanged()
    }

    function formatTime(seconds) {
        if (!seconds || seconds <= 0) return "0:00"
        let m = Math.floor(seconds / 60)
        let s = Math.floor(seconds % 60)
        return m + ":" + (s < 10 ? "0" : "") + s
    }

    readonly property string titleText: root.hasPlayer
        ? (root.activePlayer.trackTitle || "Untitled") : "Nothing playing"
    readonly property string posText: root.activePlayer !== null ? root.formatTime(root.activePlayer.position) : "0:00"
    readonly property string lenText: root.activePlayer !== null ? root.formatTime(root.activePlayer.length) : "0:00"
    readonly property string playGlyph: root.activePlayer !== null && root.activePlayer.isPlaying ? "\ue034" : "\ue037"

    // ── Where the shared pieces sit, in this item's coordinates ─────────
    // Chained by hand rather than with mapToItem, which is a plain function
    // call and would never re-run when the layout shifts.
    readonly property real artCX: row.x + artSlot.x + artSlot.width / 2
    readonly property real artCY: row.y + artSlot.y + artSlot.height / 2

    readonly property real titleX: row.x + col.x + top.x + titleT.x
    readonly property real titleCY: row.y + col.y + top.y + titleT.y + titleT.height / 2
    readonly property real titleW: titleT.width

    readonly property real posX: row.x + col.x + bottom.x + wave.x + times.x + posT.x
    readonly property real posCY: row.y + col.y + bottom.y + wave.y + times.y + posT.y + posT.height / 2
    readonly property real lenX: row.x + col.x + bottom.x + wave.x + times.x + lenT.x
    readonly property real lenCY: row.y + col.y + bottom.y + wave.y + times.y + lenT.y + lenT.height / 2

    readonly property real ctlY: row.y + col.y + bottom.y + ctl.y
    readonly property real prevCX: row.x + col.x + bottom.x + ctl.x + prevChip.x + prevChip.width / 2
    readonly property real prevCY: ctlY + prevChip.y + prevChip.height / 2
    readonly property real playCX: row.x + col.x + bottom.x + ctl.x + playChip.x + playChip.width / 2
    readonly property real playCY: ctlY + playChip.y + playChip.height / 2
    readonly property real nextCX: row.x + col.x + bottom.x + ctl.x + nextChip.x + nextChip.width / 2
    readonly property real nextCY: ctlY + nextChip.y + nextChip.height / 2

    // ── Layout ──────────────────────────────────────────────────────────
    RowLayout {
        id: row
        anchors.fill: parent
        spacing: root.gap

        ClippingRectangle {
            id: artSlot
            Layout.preferredWidth: root.artSize
            Layout.preferredHeight: root.artSize
            Layout.alignment: Qt.AlignVCenter
            radius: 28
            color: Services.Colors.abyss
            opacity: root.sharedOpacity

            Image {
                id: artImg
                anchors.fill: parent
                source: root.stableArtUrl
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                visible: status === Image.Ready
            }
            Text {
                anchors.centerIn: parent
                visible: artImg.status !== Image.Ready
                text: "\ue405"
                color: Services.Colors.ash
                font.family: "Material Symbols Rounded"
                font.pixelSize: 40
            }
        }

        Item {
            id: col
            Layout.fillWidth: true
            Layout.preferredHeight: root.artSize
            Layout.alignment: Qt.AlignVCenter

            Column {
                id: top
                anchors.top: parent.top
                width: parent.width
                spacing: 4

                Text {
                    id: titleT
                    opacity: root.sharedOpacity
                    width: parent.width
                    text: root.titleText
                    color: Services.Colors.snow
                    font.pixelSize: 18
                    font.bold: true
                    font.family: "JetBrainsMono NF"
                    elide: Text.ElideRight
                }
                Text {
                    opacity: root.extrasOpacity
                    visible: root.stableArtist !== ""
                    width: parent.width
                    text: root.stableArtist
                    color: Services.Colors.mist
                    font.pixelSize: 12
                    font.family: "JetBrainsMono NF"
                    elide: Text.ElideRight
                }
                Text {
                    opacity: root.extrasOpacity
                    visible: root.stableAlbum !== ""
                    width: parent.width
                    text: root.stableAlbum
                    color: Services.Colors.ash
                    font.pixelSize: 10
                    font.family: "JetBrainsMono NF"
                    elide: Text.ElideRight
                }
            }

            Column {
                id: bottom
                anchors.bottom: parent.bottom
                width: parent.width
                spacing: 8

                Item {
                    id: wave
                    width: parent.width
                    height: 38

                    // Snake progress: a sine wave whose played portion glows in
                    // the accent and scrolls while the track plays; the rest is
                    // a dim static wave. A dot rides the crest at the playhead.
                    Item {
                        id: snake
                        anchors.top: parent.top
                        width: parent.width
                        height: 20
                        opacity: root.extrasOpacity

                        property real progress: (root.activePlayer !== null && root.activePlayer.length > 0)
                            ? Math.max(0, Math.min(1, root.activePlayer.position / root.activePlayer.length)) : 0
                        Behavior on progress { NumberAnimation { duration: Services.Sizes.msEmphasis } }
                        property real phase: 0
                        readonly property bool playing: root.activePlayer !== null && root.activePlayer.isPlaying

                        // 0 = flat line (paused), 1 = full wave (playing). Animated
                        // so the straight<->snake transition morphs smoothly.
                        property real ampFactor: playing ? 1 : 0
                        Behavior on ampFactor { NumberAnimation { duration: 550; easing.type: Services.Sizes.easeInOut } }

                        onProgressChanged: waveCanvas.requestPaint()
                        onPhaseChanged: waveCanvas.requestPaint()
                        onAmpFactorChanged: waveCanvas.requestPaint()
                        NumberAnimation on phase {
                            running: snake.playing
                            from: 0; to: 2 * Math.PI
                            duration: 1600; loops: Animation.Infinite
                        }

                        Canvas {
                            id: waveCanvas
                            anchors.fill: parent
                            readonly property real amp: height * 0.30
                            readonly property real waves: 3.5
                            function trace(ctx) {
                                var mid = height / 2
                                ctx.beginPath()
                                for (var px = 0; px <= width; px += 2) {
                                    var y = mid + amp * parent.ampFactor * Math.sin((px / width) * waves * 2 * Math.PI + parent.phase)
                                    if (px === 0) ctx.moveTo(px, y); else ctx.lineTo(px, y)
                                }
                            }
                            onPaint: {
                                var ctx = getContext("2d")
                                ctx.reset()
                                ctx.lineWidth = 5
                                ctx.lineCap = "round"
                                // Dim full wave
                                ctx.strokeStyle = Services.Colors.ghostAlpha(0.18)
                                trace(ctx); ctx.stroke()
                                // Accent wave, clipped to the played fraction
                                var pw = width * parent.progress
                                if (pw > 0) {
                                    ctx.save()
                                    ctx.beginPath(); ctx.rect(0, 0, pw, height); ctx.clip()
                                    ctx.strokeStyle = Services.Colors.ghost
                                    trace(ctx); ctx.stroke()
                                    ctx.restore()
                                }
                            }
                        }

                        // Dot rides the wave at the playhead
                        Rectangle {
                            width: 9; height: 9; radius: 5
                            color: Services.Colors.snow
                            x: Math.max(0, parent.width * parent.progress - width / 2)
                            y: parent.height / 2 - height / 2
                                + waveCanvas.amp * parent.ampFactor * Math.sin(parent.progress * waveCanvas.waves * 2 * Math.PI + parent.phase)
                            Behavior on x { NumberAnimation { duration: Services.Sizes.msEmphasis } }
                        }
                    }

                    Item {
                        id: times
                        anchors.bottom: parent.bottom
                        width: parent.width
                        height: 14

                        Text {
                            id: posT
                            opacity: root.sharedOpacity
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.posText
                            color: Services.Colors.mist
                            font.pixelSize: 10; font.bold: true
                            font.family: "JetBrainsMono NF"
                        }
                        Text {
                            id: lenT
                            opacity: root.sharedOpacity
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.lenText
                            color: Services.Colors.mist
                            font.pixelSize: 10; font.bold: true
                            font.family: "JetBrainsMono NF"
                        }
                    }
                }

                // Shuffle and repeat are only ever here, so they stay put; the
                // middle three are what the panel's morph replaces. They are
                // laid out either way, which is what makes the flying chips'
                // targets stand still.
                Row {
                    id: ctl
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 10

                    CtlChip {
                        anchors.verticalCenter: parent.verticalCenter
                        opacity: root.extrasOpacity
                        size: root.chipLg
                        glyphSize: 20
                        glyph: "\ue043"
                    }
                    CtlChip {
                        id: prevChip
                        anchors.verticalCenter: parent.verticalCenter
                        opacity: root.sharedOpacity
                        inert: root.ghostShared
                        size: root.chipLg
                        glyphSize: 20
                        glyph: "\ue045"
                        available: root.activePlayer !== null && root.activePlayer.canGoPrevious
                        onTriggered: if (root.activePlayer) root.activePlayer.previous()
                    }
                    CtlChip {
                        id: playChip
                        anchors.verticalCenter: parent.verticalCenter
                        opacity: root.sharedOpacity
                        inert: root.ghostShared
                        size: root.playLg
                        glyphSize: 24
                        glyph: root.playGlyph
                        available: root.hasPlayer
                        active: root.activePlayer !== null && root.activePlayer.isPlaying
                        onTriggered: if (root.activePlayer) root.activePlayer.togglePlaying()
                    }
                    CtlChip {
                        id: nextChip
                        anchors.verticalCenter: parent.verticalCenter
                        opacity: root.sharedOpacity
                        inert: root.ghostShared
                        size: root.chipLg
                        glyphSize: 20
                        glyph: "\ue044"
                        available: root.activePlayer !== null && root.activePlayer.canGoNext
                        onTriggered: if (root.activePlayer) root.activePlayer.next()
                    }
                    CtlChip {
                        anchors.verticalCenter: parent.verticalCenter
                        opacity: root.extrasOpacity
                        size: root.chipLg
                        glyphSize: 20
                        glyph: "\ue040"
                    }
                }
            }
        }

        // ── Spectrum column ─────────────────────────────────────────────
        // Cava used to wash the whole card as a backdrop. It has its own room
        // now: bars laid on their side and mirrored about the centre line, so
        // the column reads as a swell rather than a row of teeth.
        Item {
            id: cavaCol
            Layout.preferredWidth: root.cavaW
            Layout.preferredHeight: root.artSize
            Layout.alignment: Qt.AlignVCenter
            opacity: root.extrasOpacity * (Services.Cava.isActive ? 1.0 : 0.35)
            Behavior on opacity { NumberAnimation { duration: Services.Sizes.msPanel } }

            // Axis the bars grow out of. Silence collapses every bar to its cap,
            // and without something to sit on those caps read as a column of
            // stray dots rather than a level meter.
            Rectangle {
                anchors.centerIn: parent
                width: 2
                height: parent.height
                radius: 1
                color: Services.Colors.ghostAlpha(0.12)
            }

            Canvas {
                id: cavaCanvas
                anchors.fill: parent

                // 96 raw bars in 160 px would be slivers; folded down to two
                // dozen they have room to be read as waves.
                readonly property int rows: 24
                readonly property real barH: 4

                Connections {
                    target: Services.Cava
                    function onBarValuesChanged() { cavaCanvas.requestPaint() }
                }

                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    const src = Services.Cava.barValues
                    if (!src || src.length === 0) return

                    const n = rows
                    const group = Math.max(1, Math.floor(src.length / n))
                    let vals = []
                    for (let i = 0; i < n; i++) {
                        let sum = 0
                        for (let k = 0; k < group; k++) sum += src[i * group + k] || 0
                        vals.push(Math.max(0, Math.min(100, sum / group)) / 100)
                    }
                    // One pass of neighbour averaging: without it the column is
                    // noise, with it the peaks roll.
                    const sm = vals.map((v, i) => (vals[Math.max(0, i - 1)] + v
                                                 + vals[Math.min(n - 1, i + 1)]) / 3)

                    const gap = (height - n * barH) / (n - 1)
                    const cx = width / 2
                    const maxLen = width / 2

                    ctx.fillStyle = Services.Colors.ghostAlpha(0.45)
                    for (let i = 0; i < n; i++) {
                        const half = Math.max(barH / 2, sm[i] * maxLen)
                        const y = i * (barH + gap)
                        ctx.beginPath()
                        ctx.roundedRect(cx - half, y, half * 2, barH, barH / 2, barH / 2)
                        ctx.fill()
                    }
                }
            }
        }
    }
}
