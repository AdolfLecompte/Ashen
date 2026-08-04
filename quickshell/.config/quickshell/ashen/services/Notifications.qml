pragma Singleton
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import QtQuick
import "root:/services" as Services

Singleton {
    id: root

    readonly property string historyPath: Paths.notificationHistory

    property var history: []
    property var activePopups: []

    // A burst of notifications used to stack toasts until they covered the
    // screen. Only the newest few are drawn; the rest are counted.
    readonly property int maxPopups: Prefs.maxToasts
    readonly property var shownPopups: activePopups.slice(0, maxPopups)
    readonly property int hiddenPopupCount: Math.max(0, activePopups.length - maxPopups)

    // ── Toast lifecycle ───────────────────────────────────────────────────
    // The countdown lives here, not in a Timer inside the delegate. The toast
    // Repeater is fed a plain JS array, and reassigning one rebuilds EVERY
    // delegate: a new notification used to restart the countdown of the toasts
    // already on screen and replay their entry animation, so a busy minute
    // left a stack that never drained.

    // Ids on their way out, so the view can play an exit before the entry goes.
    // Published as its own list: mutating an entry in place notifies nobody.
    property var leavingIds: []
    // A hovered stack is being read, so hold every countdown -- not just the
    // card under the pointer, since they all shuffle as soon as one leaves.
    property int hoverHolds: 0
    readonly property int leaveMs: 400

    function popupHold(entry) {
        // Critical never ages out on its own; it has to be acknowledged.
        if (entry.urgency === 2) return 0
        if (entry.source === "system") return 1800
        return Math.max(1, Prefs.toastSeconds) * 1000
    }

    function isLeaving(id) { return root.leavingIds.indexOf(id) !== -1 }
    // Already on its way out, whether it has started moving or is still
    // waiting its turn in the sweep.
    function isPending(id) {
        if (root.isLeaving(id)) return true
        for (let i = 0; i < root.sweepQueue.length; i++) if (root.sweepQueue[i].id === id) return true
        return false
    }

    Timer {
        id: popupClock
        interval: 100
        repeat: true
        running: root.activePopups.length > 0
        onTriggered: root.tickPopups()
    }

    // Bumped on every tick so a card can draw how much time it has left
    // without a timer of its own. `expiresAt` is mutated in place and notifies
    // nobody, so this is what the bindings actually hang off.
    property int popupTick: 0

    function tickPopups() {
        const now = Date.now()
        root.popupTick++
        const shown = root.shownPopups
        let expired = []
        for (let i = 0; i < shown.length; i++) {
            let p = shown[i]
            // The clock starts when a toast reaches the drawn part of the
            // stack, so the ones waiting behind the +N row keep their full time.
            if (!p.expiresAt) {
                if (p.holdMs > 0) p.expiresAt = now + p.holdMs
                continue
            }
            if (root.hoverHolds > 0) { p.expiresAt += popupClock.interval; continue }
            if (now >= p.expiresAt && !root.isPending(p.id)) expired.push(p.id)
        }
        // Oldest first, so a row that runs out together drains from the far end.
        if (expired.length > 0) root.queueLeave(expired.reverse(), false)

        // Anything whose exit has finished playing is really gone now.
        let done = root.activePopups.filter(p => p.leaveAt && now >= p.leaveAt).map(p => p.id)
        if (done.length > 0) root.dropPopups(done)
    }

    // Starts the exit. `byUser` separates "I closed this" from "it timed out",
    // which is what the sender is told over D-Bus.
    function beginLeave(id, byUser) {
        if (root.isLeaving(id)) return
        let ent = root.activePopups.find(p => p.id === id)
        if (!ent) return
        ent.leaveAt = Date.now() + root.leaveMs
        root.leavingIds = root.leavingIds.concat([id])
        root.releaseLive(id, byUser)
    }

    function dropPopups(ids) {
        root.activePopups = root.activePopups.filter(p => ids.indexOf(p.id) === -1)
        root.leavingIds = root.leavingIds.filter(i => ids.indexOf(i) === -1)
        root.seenPopups = root.seenPopups.filter(i => ids.indexOf(i) === -1)
    }

    // ── Sweeping several at once ──────────────────────────────────────────
    // A stack that vanishes in one frame reads as a glitch; one card after
    // another reads as a sweep. Everything that leaves in a batch -- the sweep
    // button, and a row of toasts whose time runs out together -- goes through
    // this queue instead of all calling beginLeave in the same tick.
    property var sweepQueue: []
    readonly property int sweepStepMs: 80

    Timer {
        id: sweepTimer
        interval: root.sweepStepMs
        repeat: true
        running: root.sweepQueue.length > 0
        onTriggered: {
            let q = root.sweepQueue.slice()
            const next = q.shift()
            root.sweepQueue = q
            root.beginLeave(next.id, next.byUser)
        }
    }

    function queueLeave(ids, byUser) {
        if (ids.length === 0) return
        // The first one goes immediately: a sweep that starts with a pause
        // feels unresponsive.
        root.beginLeave(ids[0], byUser)
        if (ids.length < 2) return
        let add = []
        for (let i = 1; i < ids.length; i++) add.push({ id: ids[i], byUser: byUser })
        root.sweepQueue = root.sweepQueue.concat(add)
    }

    // ── Which cards have already made their entrance ──────────────────────
    // The Repeater rebuilds every delegate whenever the array is reassigned,
    // so a card would replay its entry animation each time a new notification
    // arrived. The view asks here whether it is genuinely new. Plain array, no
    // published copy: it is only ever read while a delegate is being built.
    property var seenPopups: []
    function hasEntered(id) { return root.seenPopups.indexOf(id) !== -1 }
    function markEntered(id) { if (!root.hasEntered(id)) root.seenPopups.push(id) }

    function pushPopup(entry) {
        let popupEntry = Object.assign({}, entry)
        popupEntry.holdMs = root.popupHold(entry)
        popupEntry.expiresAt = 0
        popupEntry.leaveAt = 0
        root.activePopups = [popupEntry].concat(root.activePopups)
    }

    // Sweeps the toast stack only; the history keeps every entry. Bottom of
    // the stack first: the pile collapses towards the pill it came from.
    function dismissAllPopups() {
        const ids = root.activePopups.map(p => p.id).reverse()
        root.queueLeave(ids, true)
    }

    function dismissPopup(id) { root.beginLeave(id, true) }

    // ── Live D-Bus notifications ──────────────────────────────────────────
    // The Notification object is the only thing that can invoke an action or
    // tell the sender the notice was closed, so it is kept alive past its
    // toast for anything the panel can still act on. Everything else is
    // released as its toast leaves, or the shell would sit on every
    // notification of the session.
    property var liveNotifs: ({})
    // What the views bind against: a plain object mutation notifies nobody.
    property var liveIds: []
    readonly property int maxLive: 60

    function publishLive() { root.liveIds = Object.keys(root.liveNotifs) }

    function trackLive(id, notif) {
        root.liveNotifs[id] = notif
        let ids = Object.keys(root.liveNotifs)
        if (ids.length > root.maxLive) {
            // Our ids start with the epoch millis they were made, so plain
            // string order is oldest first.
            ids.sort()
            for (let i = 0; i < ids.length - root.maxLive; i++) root.closeLive(ids[i], false)
        }
        root.publishLive()
    }

    function closeLive(id, byUser) {
        let n = root.liveNotifs[id]
        if (!n) return
        delete root.liveNotifs[id]
        root.publishLive()
        if (byUser) n.dismiss()
        else n.expire()
    }

    // A toast just left the screen: keep the ones that still offer something
    // to press, let the rest go.
    function releaseLive(id, byUser) {
        if (!byUser) {
            let ent = root.history.find(e => e.id === id)
            if (ent && ent.actions && ent.actions.length > 0) return
        }
        root.closeLive(id, byUser)
    }

    function isActionable(id) { return root.liveIds.indexOf(id) !== -1 }

    // Housekeeping the sender offers about ITSELF rather than about the thing
    // it is telling you. Brave puts "Site settings" on every web notification;
    // it is a button that leaves what you were doing to open a settings page.
    readonly property var chromeActions: ["settings", "site-settings", "close"]
    function isChrome(action) {
        const id = (action.identifier || "").toLowerCase()
        if (root.chromeActions.indexOf(id) !== -1) return true
        const t = (action.text || "").toLowerCase()
        return t === "settings" || t === "site settings" || t === "configuración del sitio"
    }

    function invokeAction(id, actionId) {
        let n = root.liveNotifs[id]
        if (!n) return
        let acts = n.actions || []
        for (let i = 0; i < acts.length; i++) {
            if (acts[i].identifier === actionId) { acts[i].invoke(); break }
        }
        // invoke() closes the notification unless it is resident, so the
        // reference is dropped here rather than closed a second time.
        delete root.liveNotifs[id]
        root.publishLive()
        root.markRead(id)
        root.beginLeave(id, true)
    }

    // Clicking the body takes you to what it is about. Senders put that behind
    // an action called "default"; when there is none, go to the app itself.
    // From the history: same destination, but the entry stays. A record you
    // click should not vanish because you followed it.
    function activateFromHistory(id) {
        const n = root.liveNotifs[id]
        if (n) {
            const acts = n.actions || []
            for (let i = 0; i < acts.length; i++) {
                if (acts[i].identifier === "default") {
                    root.invokeAction(id, "default")
                    root.markRead(id)
                    return
                }
            }
        }
        root.openSender(id)
        root.markRead(id)
    }

    function activateDefault(id) {
        let n = root.liveNotifs[id]
        if (n) {
            const acts = n.actions || []
            for (let i = 0; i < acts.length; i++) {
                if (acts[i].identifier === "default") {
                    root.invokeAction(id, "default")
                    return
                }
            }
        }
        root.openSender(id)
        root.markRead(id)
        root.beginLeave(id, true)
    }

    // Raise the app that sent it: its window if it has one, otherwise its
    // launcher entry. Hyprland's config here is Lua, so the dispatcher is
    // `hl.dsp.focus({ window = ... })` -- the plain `dispatch focuswindow`
    // form does not even parse, and still exits 0.
    function openSender(id) {
        const ent = root.history.find(e => e.id === id)
        if (!ent) return
        const live = root.liveNotifs[id]
        const de = live && live.desktopEntry ? String(live.desktopEntry) : ""
        // A Brave PWA's class is its own app id, so the desktop entry is the
        // better key whenever the sender gave us one.
        const key = de !== "" ? de.replace(/\.desktop$/, "")
                              : String(ent.appName || "").toLowerCase()
        if (key === "") return
        root.senderProc.command = ["sh", "-c",
            'out=$(hyprctl dispatch \'hl.dsp.focus({ window = "class:(?i)\'"$1"\'" })\' 2>&1); ' +
            'case "$out" in ok*) exit 0 ;; esac; ' +
            'gtk-launch "$1" >/dev/null 2>&1 || gtk-launch "$1.desktop" >/dev/null 2>&1',
            "sh", key]
        root.senderProc.running = true
    }
    property alias senderProc: senderProcess
    Process { id: senderProcess; running: false }

    // The sender took its notification back: the toast goes with it.
    function onLiveClosed(id) {
        if (root.liveNotifs[id]) {
            delete root.liveNotifs[id]
            root.publishLive()
        }
        if (root.activePopups.find(p => p.id === id)) root.beginLeave(id, true)
    }

    property bool lastCapsLock: false
    property bool lastNumLock: false
    property string lastPowerProfile: ""
    property bool initialized: false

    // Brave PWAs (WhatsApp Web) all report appName "Brave" with the generic
    // Brave-lion appIcon — no dbus field distinguishes them. In this setup
    // Brave notifications are WhatsApp, so remap them to the WhatsApp PWA icon
    // resolved from its .desktop (via the icon theme, no hardcoded path).
    // Returns a ready-to-use Image source (image://, file:// or http URL) so
    // both the panel and the lock screen can bind it directly.
    readonly property string whatsappIconId: "brave-hnpfjngllnobngcgfapefoaidbinmjnm-Default"
    function resolveIcon(appName, appIcon) {
        if (appName === "Brave") {
            let p = Quickshell.iconPath(root.whatsappIconId, true)
            if (p && p !== "") return p
        }
        // Discord ships no appIcon over dbus, so the toast fell back to a
        // generic Material glyph. Resolve its theme icon by name instead.
        if ((appName || "").toLowerCase().indexOf("discord") !== -1) {
            let d = Quickshell.iconPath("discord", true)
            if (d && d !== "") return d
        }
        let ic = appIcon || ""
        if (ic.startsWith("image://") || ic.startsWith("file://") || ic.startsWith("http")) return ic
        if (ic.startsWith("/")) return "file://" + ic
        if (ic !== "") {
            // Bare icon-theme name (e.g. "discord", "steam")
            let p = Quickshell.iconPath(ic, true)
            if (p && p !== "") return p
        }
        // Last resort: try the app's own name as a theme icon name.
        if (appName && appName !== "") return Quickshell.iconPath(appName.toLowerCase(), true)
        return ""
    }

    function addEntry(entry, notif) {
        entry.id = Date.now() + "-" + Math.floor(Math.random() * 100000)
        entry.timestamp = Date.now()
        entry.read = false
        if (notif) {
            // Only each action's label is stored; pressing one goes back
            // through the live object, the only thing that can invoke it.
            let acts = []
            const raw = notif.actions || []
            for (let i = 0; i < raw.length; i++) {
                if (root.isChrome(raw[i])) continue
                acts.push({ id: raw[i].identifier, text: raw[i].text })
            }
            entry.actions = acts
            root.trackLive(entry.id, notif)
            notif.closed.connect(function(reason) { root.onLiveClosed(entry.id) })
        }
        // A transient notification is a passing status (another shell's volume
        // popup, a download bar): show it, never log it.
        if (!entry.transient) {
            const dropped = root.history.slice(299)
            for (let d = 0; d < dropped.length; d++) root.closeLive(dropped[d].id, false)
            root.history = [entry].concat(root.history).slice(0, 300)
        }
        // Do Not Disturb hides toasts, but urgency 2 (critical) always breaks
        // through -- low-battery and the like must not be swallowed.
        if (!Services.AppState.doNotDisturb || entry.urgency === 2) {
            root.pushPopup(entry)
            root.playSound(entry)
        }
        saveHistory()
    }

    // ── Sound ──────────────────────────────────────────────────────────────
    // Off by default. A system that makes noise without being asked to is a
    // system you end up muting altogether.
    readonly property string defaultSound: Services.Paths.shellSounds + "/ashen-notif.mp3"

    // What the picker offers: whatever is actually THERE, in the shell's own
    // folder first and the system theme after it. It used to be five names
    // written into the settings page, which is a list that goes stale and says
    // nothing about what the machine has.
    property var soundChoices: []
    function refreshSounds() { soundList.running = false; soundList.running = true }

    Process {
        id: soundList
        running: false
        // Everything in the shell's own folder, whatever it is -- drop a file
        // there and it shows up. From the system theme only the handful that
        // are actually alerts: the set also ships channel tests and phone
        // tones, and a picker with thirty-four entries is not a choice.
        readonly property var themePicks: ["message", "message-new-instant", "bell",
                                           "complete", "dialog-information", "window-attention"]
        command: ["sh", "-c",
                  '[ -d "$1" ] && for f in "$1"/*.ogg "$1"/*.oga "$1"/*.wav "$1"/*.mp3 "$1"/*.flac "$1"/*.opus; do ' +
                  '  [ -f "$f" ] && printf "%s\\n" "$f"; done; ' +
                  'for n in ' + soundList.themePicks.join(" ") + '; do ' +
                  '  f="/usr/share/sounds/freedesktop/stereo/$n.oga"; ' +
                  '  [ -f "$f" ] && printf "%s\\n" "$f"; done',
                  "sh", Services.Paths.shellSounds]
        stdout: StdioCollector {
            onStreamFinished: {
                let out = []
                for (const line of text.split("\n")) {
                    const p = line.trim()
                    if (p === "") continue
                    const base = p.split("/").pop().replace(/\.[^.]+$/, "")
                    out.push({ path: p, name: base, mine: p.indexOf(Services.Paths.shellSounds) === 0 })
                }
                root.soundChoices = out
            }
        }
    }
    readonly property string soundFile: Services.Prefs.notifySoundFile !== ""
        ? Services.Prefs.notifySoundFile : root.defaultSound

    function playSound(entry) {
        if (!Services.Prefs.notifySound) return
        if (Services.Prefs.notifySoundCriticalOnly && entry.urgency !== 2) return
        // A system toast is the shell talking to itself (screenshot taken,
        // night light on); it already showed you the thing it is about.
        if (entry.source === "system") return
        root.play(root.soundFile)
    }

    // Also used by the Settings preview button.
    function play(file) {
        if (!file || file === "") return
        soundProc.running = false
        // pw-play is part of pipewire, which Ashen already requires; paplay is
        // there for a machine still running the pulse daemon.
        soundProc.command = ["sh", "-c",
                             'pw-play --volume "$2" "$1" 2>/dev/null || paplay "$1" 2>/dev/null',
                             "sh", file, String(Services.Prefs.soundVolume)]
        soundProc.running = true
    }

    Process { id: soundProc; running: false }

    // ── Unread ─────────────────────────────────────────────────────────────
    readonly property int unreadCount: {
        let n = 0
        for (let i = 0; i < root.history.length; i++) if (!root.history[i].read) n++
        return n
    }

    function markRead(id) {
        let arr = root.history.slice()
        let hit = false
        for (let i = 0; i < arr.length; i++) {
            if (arr[i].id === id && !arr[i].read) { arr[i] = Object.assign({}, arr[i], { read: true }); hit = true }
        }
        if (!hit) return
        root.history = arr
        saveHistory()
    }

    function markAllRead() {
        if (root.unreadCount === 0) return
        root.history = root.history.map(e => e.read ? e : Object.assign({}, e, { read: true }))
        saveHistory()
    }

    // ── Grouping ───────────────────────────────────────────────────────────
    // The history is one long column of rows otherwise, and a chatty app buries
    // everything else. Groups come out newest-first because the history is.
    function groupKey(entry) {
        if (entry.source === "system") return "System"
        return entry.appName || "Unknown"
    }

    readonly property var groupedHistory: {
        let out = []
        let byApp = ({})
        for (let i = 0; i < root.history.length; i++) {
            const e = root.history[i]
            const key = root.groupKey(e)
            if (!byApp[key]) {
                byApp[key] = { app: key, icon: e.icon || "", items: [], unread: 0, latest: e.timestamp }
                out.push(byApp[key])
            }
            let g = byApp[key]
            g.items.push(e)
            if (!e.read) g.unread++
            if (!g.icon && e.icon) g.icon = e.icon
            if (e.timestamp > g.latest) g.latest = e.timestamp
        }
        return out
    }

    // ── Relative time ──────────────────────────────────────────────────────
    // Bumped on a slow tick so the labels age without a timer per row.
    property int clockTick: 0
    Timer { interval: 30000; running: true; repeat: true; onTriggered: root.clockTick++ }

    // `tick` is passed in by the caller so its binding depends on it plainly;
    // reading it inside the function only is too easy to lose in a refactor.
    function relTime(ts, tick) {
        if (!ts) return ""
        const d = Date.now() - ts
        if (d < 45000) return "now"
        if (d < 3600000) return Math.max(1, Math.round(d / 60000)) + "m"
        if (d < 86400000) return Math.round(d / 3600000) + "h"
        if (d < 604800000) return Math.round(d / 86400000) + "d"
        return Qt.formatDateTime(new Date(ts), "MMM d")
    }

    function addSystemToast(message, glyph, isLetter, typeKey) {
        // System ones are only shown as a toast, never stored in the history.
        // Replaces any other active one of the same "type" (typeKey) instead of stacking.
        root.activePopups = root.activePopups.filter(p => !(p.source === "system" && p.typeKey === typeKey))
        let entry = {
            appName: "System",
            summary: "SYSTEM ALERT",
            body: message,
            glyph: glyph || "",
            glyphIsLetter: isLetter || false,
            typeKey: typeKey || message,
            icon: "",
            urgency: 0,
            source: "system",
            id: Date.now() + "-" + Math.floor(Math.random() * 100000),
            timestamp: Date.now()
        }
        root.pushPopup(entry)
    }

    // By id, not by row: grouping means a row's position is no longer its
    // index in the history.
    function removeById(id) {
        root.closeLive(id, true)
        root.history = root.history.filter(e => e.id !== id)
        saveHistory()
    }

    function clearApp(app) {
        const gone = root.history.filter(e => root.groupKey(e) === app)
        for (let i = 0; i < gone.length; i++) root.closeLive(gone[i].id, true)
        root.history = root.history.filter(e => root.groupKey(e) !== app)
        saveHistory()
    }

    function clearAll() {
        const ids = Object.keys(root.liveNotifs)
        for (let i = 0; i < ids.length; i++) root.closeLive(ids[i], true)
        root.history = []
        saveHistory()
    }

    // The JSON travels as an argv entry, never through the shell's parser: the
    // old route base64-encoded it with Qt.btoa, which Qt deprecated and warned
    // about on every write.
    function saveHistory() {
        // Until the file on disk has been read, the file is the truth. Writing
        // over it first is how entries vanished: a notification arriving in the
        // gap between startup and the read landing wrote a one-entry history
        // over everything that was already there.
        if (!root.initialized) return
        saveDebounce.restart()
    }

    // A burst of notifications used to start -- and immediately kill -- one
    // write per entry. Coalesced into a single write once things settle.
    Timer {
        id: saveDebounce
        interval: 250
        onTriggered: root.writeHistory()
    }

    function writeHistory() {
        // `image` is an image:// handle owned by a live Notification and
        // `actions` need one to be invoked, so neither survives a restart.
        // Writing them would only leave rows with dead art and dead buttons.
        const body = JSON.stringify(root.history, function(k, v) {
            return (k === "image" || k === "actions") ? undefined : v
        })
        saveProc.running = false
        // Write to a temporary file and move it into place. `> "$2"` truncates
        // the real file the instant the shell starts, so a write cut short --
        // by the next save restarting the Process, or by a reload tearing it
        // down -- left an EMPTY history behind. That is how the whole file was
        // lost. A rename is atomic: the worst a killed write can leave now is
        // a stray .tmp.
        saveProc.command = ["sh", "-c",
                            "mkdir -p \"$(dirname \"$2\")\" && printf %s \"$1\" > \"$2.tmp\" && mv -f \"$2.tmp\" \"$2\"",
                            "sh", body, root.historyPath]
        saveProc.running = true
    }

    Component.onCompleted: { loadProc.running = true; root.refreshSounds() }

    Process {
        id: loadProc
        command: ["sh", "-c", "cat " + root.historyPath + " 2>/dev/null || echo '[]'"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                let loaded = []
                try {
                    let parsed = JSON.parse(text.trim() || "[]")
                    // Entries written before this session count as seen: a
                    // history file from last week is not a pile of unread.
                    if (Array.isArray(parsed))
                        loaded = parsed.map(e => e.read === undefined ? Object.assign({}, e, { read: true }) : e)
                } catch (e) {
                    loaded = []
                }
                // Notifications that landed while the file was being read are
                // already in `history`; the read must join them, not replace
                // them. A reload takes long enough for this to happen often.
                const pending = root.history
                let seen = ({})
                let merged = []
                const all = pending.concat(loaded)
                for (let i = 0; i < all.length; i++) {
                    if (seen[all[i].id]) continue
                    seen[all[i].id] = true
                    merged.push(all[i])
                }
                merged.sort((a, b) => (b.timestamp || 0) - (a.timestamp || 0))
                root.history = merged.slice(0, 300)
                root.initialized = true
                if (pending.length > 0) root.saveHistory()
            }
        }
    }

    Process {
        id: saveProc
        running: false
    }


    // --- Real D-Bus notification server (org.freedesktop.Notifications) ---
    NotificationServer {
        id: notifServer
        bodySupported: true
        imageSupported: true
        keepOnReload: true

        // Chromium queries GetCapabilities on startup and refuses the D-Bus
        // route unless the server advertises actions and persistence, falling
        // back to its own in-window message center. Brave notifications
        // (WhatsApp Web) depend on these two being advertised.
        actionsSupported: true
        persistenceSupported: true

        onNotification: notification => {
            notification.tracked = true
            root.addEntry({
                appName: notification.appName || "Unknown",
                summary: notification.summary || "",
                body: notification.body || "",
                icon: root.resolveIcon(notification.appName, notification.appIcon),
                // The image hint is the notification's own art (a contact's
                // avatar, album cover) and beats a generic app icon when it is
                // there. It dies with the live object, so it is never saved.
                image: notification.image || "",
                urgency: notification.urgency,
                transient: notification.transient === true,
                source: "app"
            }, notification)
        }
    }

    // --- Caps Lock / Num Lock (poll via hyprctl -j devices) ---
    Process {
        id: kbStateProc
        command: ["sh", "-c", "hyprctl -j devices"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let data = JSON.parse(text)
                    let kb = data.keyboards && data.keyboards.find(k => k.main) || (data.keyboards ? data.keyboards[0] : null)
                    if (!kb) return
                    if (root.initialized) {
                        if (kb.capsLock !== root.lastCapsLock) {
                            root.addSystemToast(kb.capsLock ? "CAPS LOCK ON" : "CAPS LOCK OFF", "", false, "capslock")
                        }
                        if (kb.numLock !== root.lastNumLock) {
                            root.addSystemToast(kb.numLock ? "NUM LOCK ON" : "NUM LOCK OFF", "\uf2af", false, "numlock")
                        }
                    }
                    root.lastCapsLock = kb.capsLock
                    root.lastNumLock = kb.numLock
                } catch (e) {}
            }
        }
    }

    Timer {
        interval: 500
        running: true
        repeat: true
        onTriggered: kbStateProc.running = true
    }

    // --- Power profile changes (powerprofilesctl monitor, streaming) ---
    // --- Cargador conectado/desconectado ---
    property bool lastCharging: false
    Process {
        id: chargerProc
        command: ["sh", "-c", "cat /sys/class/power_supply/AC0/online 2>/dev/null || cat /sys/class/power_supply/ADP1/online 2>/dev/null || echo ''"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                let val = text.trim()
                if (val === "") return
                let charging = val === "1"
                if (root.initialized && charging !== root.lastCharging) {
                    root.addSystemToast(charging ? "CHARGER CONNECTED" : "CHARGER DISCONNECTED", charging ? "" : "", false, "charger")
                }
                root.lastCharging = charging
            }
        }
    }
    Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: chargerProc.running = true
    }

    Process {
        id: profileMonitor
        command: ["sh", "-c", "powerprofilesctl monitor"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                let line = data.trim()
                if (line.length === 0) return
                if (root.initialized && root.lastPowerProfile !== "" && line !== root.lastPowerProfile) {
                    let profIcon = line.indexOf("saver") !== -1 ? ""
                        : line.indexOf("performance") !== -1 ? ""
                        : ""
                    root.addSystemToast("PROFILE: " + line.toUpperCase(), profIcon, false, "powerprofile")
                }
                root.lastPowerProfile = line
            }
        }
        onRunningChanged: if (!running) running = true
    }

    // --- Low battery warnings (20/10/5%), once per threshold ---
    property bool warned20: false
    property bool warned10: false
    property bool warned5: false

    Connections {
        target: Services.Battery
        function onLevelChanged() {
            if (Services.Battery.charging) return
            let lvl = Services.Battery.level
            if (lvl <= 5 && !root.warned5) {
                root.warned5 = true
                root.addSystemToast("BATTERY CRITICAL: 5%", "", false, "battery5")
            } else if (lvl <= 10 && !root.warned10) {
                root.warned10 = true
                root.addSystemToast("BATTERY LOW: 10%", "", false, "battery10")
            } else if (lvl <= 20 && !root.warned20) {
                root.warned20 = true
                root.addSystemToast("BATTERY LOW: 20%", "", false, "battery20")
            }
        }
        function onChargingChanged() {
            if (Services.Battery.charging) {
                root.warned20 = false
                root.warned10 = false
                root.warned5 = false
            }
        }
    }

    // System notice when Do Not Disturb is toggled
    Connections {
        target: Services.AppState
        function onDoNotDisturbChanged() {
            root.addSystemToast(
                Services.AppState.doNotDisturb ? "DO NOT DISTURB ON" : "DO NOT DISTURB OFF",
                "",
                false,
                "dnd"
            )
        }
        function onKeepAwakeChanged() {
            root.addSystemToast(
                Services.AppState.keepAwake ? "KEEP AWAKE ON" : "KEEP AWAKE OFF",
                "",
                false,
                "keepawake"
            )
        }
        function onRecordingChanged() {
            root.addSystemToast(
                Services.AppState.recording ? "SCREEN RECORDING STARTED" : "SCREEN RECORDING STOPPED",
                "",
                false,
                "recording"
            )
        }
    }
}
