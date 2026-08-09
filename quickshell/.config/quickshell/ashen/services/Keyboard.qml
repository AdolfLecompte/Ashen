pragma Singleton
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick
import "root:/services" as Services

Singleton {
    id: root

    // Everything comes from the main keyboard: `layout` is the whole configured
    // list ("latam,us") and `active_layout_index` says which one is live.
    property var layouts: []
    property int activeIndex: 0
    property string keymap: ""

    readonly property string code: activeIndex >= 0 && activeIndex < layouts.length
        ? layouts[activeIndex] : ""
    readonly property string label: code === "" ? "--" : code.toUpperCase()
    readonly property bool multiple: layouts.length > 1

    function refresh() { devProc.running = true }

    // Resolved from $HOME at runtime, and via the stowed config location rather
    // than the repo path, so it holds no matter where the repo was cloned.
    readonly property string inputConf:
        (Quickshell.env("HOME") || "") + "/.config/hypr/conf/input.lua"

    // XKB only has 4 groups. Hyprland will happily accept and echo back a 5th
    // layout, but switchxkblayout answers "layout idx out of range of 4", so it
    // can never be selected -- a phantom entry. Refuse to create one.
    readonly property int maxLayouts: 4
    readonly property bool canAdd: layouts.length < maxLayouts

    // Every layout xkeyboard-config knows: [{ code, name }].
    // xkeyboard-config ships with libxkbcommon, which Hyprland requires, so
    // this file is always there -- nothing extra to install.
    property var available: []
    Process {
        id: availProc
        command: ["sh", "-c",
            "awk '/^! layout/{f=1;next} /^! /{f=0} f && NF {code=$1; $1=\"\"; sub(/^[ \\t]+/,\"\"); print code \"\\t\" $0}' " +
            "/usr/share/X11/xkb/rules/evdev.lst 2>/dev/null"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                let out = []
                for (let line of text.split("\n")) {
                    let p = line.split("\t")
                    if (p.length === 2 && p[0].length > 0) out.push({ code: p[0], name: p[1] })
                }
                root.available = out
            }
        }
    }

    function nameFor(code) {
        let hit = root.available.find(l => l.code === code)
        return hit ? hit.name : code.toUpperCase()
    }

    // hyprctl *keyword* does not work on this Lua config ("non-legacy parsers,
    // use eval"), so: eval applies it live, sed makes it survive the next login.
    function applyLayouts(list) {
        // Codes come from evdev.lst and are [a-z0-9_], but this string is
        // interpolated into a shell command -- so validate rather than trust.
        let clean = list.filter(c => /^[a-z0-9_]+$/.test(c)).slice(0, root.maxLayouts)
        if (clean.length === 0) return
        let joined = clean.join(",")
        Quickshell.execDetached(["sh", "-c",
            "hyprctl eval 'hl.config({ input = { kb_layout = \"" + joined + "\" } })' >/dev/null 2>&1; " +
            "sed -i 's/kb_layout = \"[^\"]*\"/kb_layout = \"" + joined + "\"/' " + root.inputConf
        ])
        refreshLater.restart()
    }

    function addLayout(code) {
        if (!root.canAdd || root.layouts.includes(code)) return
        applyLayouts(root.layouts.concat([code]))
    }

    // Never remove the last one: a keyboard with zero layouts types nothing.
    function removeLayout(code) {
        if (root.layouts.length <= 1 || !root.layouts.includes(code)) return
        // Drop a remembered pick that is being removed, or it would silently
        // come back the moment the layout is added again.
        if (Services.Prefs.keyboardLayout === code) Services.Prefs.keyboardLayout = ""
        applyLayouts(root.layouts.filter(c => c !== code))
    }

    // hyprctl runs detached, so give it a beat before re-reading the state
    Timer { id: refreshLater; interval: 250; onTriggered: root.refresh() }

    // `all`, not the device name: the laptop reports a dozen keyboards and
    // switching only the main one desyncs them. The list is deliberately NOT
    // reordered to persist the pick -- that swapped the cards under the cursor
    // and the next click landed on the wrong one. Prefs remembers it instead.
    function setLayout(i) {
        if (i < 0 || i >= layouts.length) return
        Services.Prefs.keyboardLayout = layouts[i]
        if (i === activeIndex) return
        Quickshell.execDetached(["hyprctl", "switchxkblayout", "all", String(i)])
        refresh()
    }

    // Re-apply the remembered layout: login always starts on index 0 (the first
    // in kb_layout), and eval on add/remove resets it too.
    function restorePick() {
        let want = Services.Prefs.keyboardLayout
        if (want === "") return
        let i = root.layouts.indexOf(want)
        if (i < 0 || i === root.activeIndex) return
        Quickshell.execDetached(["hyprctl", "switchxkblayout", "all", String(i)])
    }

    function cycle() {
        if (layouts.length < 2) return
        setLayout((activeIndex + 1) % layouts.length)
    }

    Process {
        id: devProc
        command: ["hyprctl", "devices", "-j"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let kbs = JSON.parse(text).keyboards || []
                    let main = kbs.find(k => k.main) || kbs[0]
                    if (!main) return
                    root.layouts = (main.layout || "").split(",").map(s => s.trim()).filter(s => s.length > 0)
                    root.activeIndex = main.active_layout_index || 0
                    root.keymap = main.active_keymap || ""
                    // Converges: the switch fires an activelayout event -> refresh
                    // -> this runs again, finds the pick already active, no-ops.
                    root.restorePick()
                } catch (e) {
                    // hyprctl not up yet; the next refresh will catch it
                }
            }
        }
    }

    // Hyprland announces every layout change, whoever caused it
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "activelayout")
                root.refresh()
        }
    }
}
