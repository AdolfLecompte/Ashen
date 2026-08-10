pragma Singleton
import Quickshell
import Quickshell.Services.Mpris
import QtQuick

// Transport, for whoever is not holding a player already. The pill and the
// card each keep their own sticky player (they have to: it drops to null for a
// few ms between tracks, and their whole layout would collapse), so this is
// for the media keys, which have nothing.
Singleton {
    id: root

    readonly property var player: {
        const live = Mpris.players.values.filter(p => p.playbackState !== MprisPlaybackState.Stopped)
        if (live.length === 0) return null
        const playing = live.find(p => p.isPlaying)
        return playing !== undefined ? playing : live[0]
    }

    // Saying which way it goes before jumping is the whole point of routing the
    // keys through here: the sweep reads the same flag the buttons set.
    function next() {
        if (root.player === null) return
        AppState.mediaStep(1)
        if (root.player.canGoNext) root.player.next()
    }
    function previous() {
        if (root.player === null) return
        AppState.mediaStep(-1)
        if (root.player.canGoPrevious) root.player.previous()
    }
    function playPause() {
        if (root.player !== null) root.player.togglePlaying()
    }
}
