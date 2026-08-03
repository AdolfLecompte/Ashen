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
    // What kind of thing the sound is coming out of, read off the node name
    // PipeWire gives it: how it is connected is what you actually want to know
    // ("the Bluetooth ones" or "the jack"), not the model of the chip.
    function deviceKind(name) {
        const n = String(name).toLowerCase()
        if (n.indexOf("bluez") !== -1) return "bluetooth"
        if (n.indexOf("hdmi") !== -1) return "hdmi"
        if (n.indexOf("usb") !== -1) return "usb"
        if (n.indexOf("headphone") !== -1 || n.indexOf("headset") !== -1) return "headphones"
        return "speakers"
    }
    function kindGlyph(kind) {
        if (kind === "bluetooth") return "\ue60f"
        if (kind === "hdmi") return "\ue333"
        if (kind === "usb") return "\ue1e0"
        if (kind === "headphones") return "\ue310"
        return "\ue050"
    }
    function kindLabel(kind) {
        if (kind === "bluetooth") return "Bluetooth"
        if (kind === "hdmi") return "HDMI"
        if (kind === "usb") return "USB"
        if (kind === "headphones") return "Wired"
        return "Built-in"
    }
    function descOf(list, name) {
        for (const d of list) if (d.name === name) return root.shortName(d.desc)
        return ""
    }
    // The one in use right now, either side.
    readonly property string activeSinkName: root.descOf(root.sinks, root.defaultSink)
    readonly property string activeSourceName: root.descOf(root.sources, root.defaultSource)

    // Per-app streams: what each open program is playing, and how loud.
    // [{ id, app, name, volume, muted }]
    property var streams: []
    function refreshStreams() { streamProc.running = true }
    function setStreamVolume(id, pct) {
        Quickshell.execDetached(["sh", "-c",
            "pactl set-sink-input-volume " + id + " " + Math.round(pct) + "%"])
    }
    function toggleStreamMute(id) {
        Quickshell.execDetached(["sh", "-c", "pactl set-sink-input-mute " + id + " toggle"])
        streamSettle.restart()
    }
    Timer { id: streamSettle; interval: 120; onTriggered: root.refreshStreams() }

    Process {
        id: streamProc
        command: ["sh", "-c", "pactl -f json list sink-inputs"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const list = JSON.parse(text).map(s => {
                        const props = s.properties || {}
                        // The volume map is per channel; they move together
                        // here, so the first channel is the whole story.
                        const vols = s.volume ? Object.keys(s.volume) : []
                        const pct = vols.length
                            ? parseInt(String(s.volume[vols[0]].value_percent).replace("%", "")) : 0
                        return {
                            id: s.index,
                            app: props["application.name"] || props["media.name"] || "Audio",
                            name: props["media.name"] || "",
                            volume: isNaN(pct) ? 0 : pct,
                            muted: s.mute === true
                        }
                    })
                    root.streams = list
                } catch (e) { root.streams = [] }
            }
        }
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
        onTriggered: { root.refreshDevices(); root.refreshStreams() }
    }
}
