pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root
    property int volume: 0
    property bool muted: false
    property bool headphones: false
    function toggleMute() {
        Quickshell.execDetached(["sh", "-c", "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"])
    }

    // shared by the pill, the OSD and the volume panel
    function icon(vol, isMuted, isHeadphones) {
        if (isMuted || vol === 0)
            return "\ue04f"
        if (isHeadphones)
            return "\uf01f"
        return vol < 66 ? "\ue04d" : "\ue050"
    }

    property int micVolume: 0
    property bool micMuted: false
    function toggleMicMute() {
        Quickshell.execDetached(["sh", "-c", "wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"])
    }
    function setMicVolume(pct) {
        Quickshell.execDetached(["sh", "-c", "wpctl set-volume @DEFAULT_AUDIO_SOURCE@ " + pct + "%"])
    }

    // ── Output/input device switching (like Noctalia) ──────────────────────
    // Each entry: { name: <pactl node name>, desc: <human label> }.
    property var sinks: []
    property var sources: []
    property string defaultSink: ""
    property string defaultSource: ""

    // Strip the long controller prefix so the picker shows just the port name.
    function shortName(desc) {
        return (desc || "").replace(/^.*High Definition Audio Controller /, "")
                           .replace(/^Monitor of /, "Monitor: ")
    }

    // Set the default and move every already-running stream over, so the switch
    // is immediate instead of only affecting apps opened afterwards.
    function setSink(name) {
        Quickshell.execDetached(["sh", "-c",
            "pactl set-default-sink '" + name + "'; " +
            "for i in $(pactl list short sink-inputs | cut -f1); do pactl move-sink-input $i '" + name + "'; done"])
        root.defaultSink = name
        refreshDevices()
    }
    function setSource(name) {
        Quickshell.execDetached(["sh", "-c",
            "pactl set-default-source '" + name + "'; " +
            "for i in $(pactl list short source-outputs | cut -f1); do pactl move-source-output $i '" + name + "'; done"])
        root.defaultSource = name
        refreshDevices()
    }
    function refreshDevices() {
        sinkListProc.running = true
        srcListProc.running = true
        srcDefaultProc.running = true
    }


    Process {
        id: volProc
        command: ["sh", "-c", "wpctl get-volume @DEFAULT_AUDIO_SINK@"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                root.muted = text.indexOf("MUTED") !== -1
                let match = text.match(/([0-9]*\.?[0-9]+)/)
                root.volume = match ? Math.round(parseFloat(match[1]) * 100) : 0
            }
        }
    }
    Process {
        id: micProc
        command: ["sh", "-c", "wpctl get-volume @DEFAULT_AUDIO_SOURCE@"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                root.micMuted = text.indexOf("MUTED") !== -1
                let match = text.match(/([0-9]*\.?[0-9]+)/)
                root.micVolume = match ? Math.round(parseFloat(match[1]) * 100) : 0
            }
        }
    }


    Process {
        id: sinkProc
        command: ["sh", "-c", "pactl get-default-sink"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                root.defaultSink = text.trim()
                root.headphones = /headphone|headset|bluez/i.test(text)
            }
        }
    }
    Process {
        id: srcDefaultProc
        command: ["sh", "-c", "pactl get-default-source"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: { root.defaultSource = text.trim() }
        }
    }

    Process {
        id: sinkListProc
        command: ["sh", "-c", "pactl -f json list sinks"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let arr = JSON.parse(text)
                    root.sinks = arr.map(s => ({ name: s.name, desc: root.shortName(s.description) }))
                } catch (e) { root.sinks = [] }
            }
        }
    }
    Process {
        id: srcListProc
        command: ["sh", "-c", "pactl -f json list sources"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    // Drop the monitor sources (loopbacks of every sink) — only
                    // real capture devices (microphones) belong in the picker.
                    let arr = JSON.parse(text).filter(s => !s.name.endsWith(".monitor"))
                    root.sources = arr.map(s => ({ name: s.name, desc: root.shortName(s.description) }))
                } catch (e) { root.sources = [] }
            }
        }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: { volProc.running = true; micProc.running = true; sinkProc.running = true }
    }
    // Device lists change rarely (plug/unplug); poll them slower.
    Timer {
        interval: 3000
        running: true
        repeat: true
        onTriggered: root.refreshDevices()
    }
}
