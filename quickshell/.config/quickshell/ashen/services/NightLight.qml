// Ashen — night light (blue-light filter) via wlsunset.  by Adolf
pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick
import "root:/services" as Services

// Drives wlsunset from the persisted prefs: manual holds a constant warm
// temperature, scheduled warms only between From and To. The daemon is
// killed when disabled; wlsunset restores the gamma to identity on SIGTERM,
// so "off" is clean.
Singleton {
    id: root

    // Readonly mirrors of the persisted state (Prefs is the single source).
    readonly property bool enabled: Services.Prefs.nightLightEnabled
    readonly property bool scheduled: Services.Prefs.nightLightScheduled
    readonly property int temperature: Services.Prefs.nightLightTemp
    readonly property string fromTime: Services.Prefs.nightLightFrom
    readonly property string toTime: Services.Prefs.nightLightTo

    // Mutations go through Prefs so they persist. setEnabled fires the system
    // toast (like Keep Awake / DND) — done here, not on the property change, so
    // loading the saved value at startup doesn't pop a spurious notification.
    function setEnabled(b) {
        if (Services.Prefs.nightLightEnabled === b) return
        Services.Prefs.nightLightEnabled = b
        Services.Notifications.addSystemToast(b ? "NIGHT LIGHT ON" : "NIGHT LIGHT OFF", "\ue51c", false, "nightlight")
    }
    function toggle() { setEnabled(!Services.Prefs.nightLightEnabled) }
    function setScheduled(b) { Services.Prefs.nightLightScheduled = b }
    function setTemperature(t) { Services.Prefs.nightLightTemp = Math.round(t) }
    function setFrom(s) { Services.Prefs.nightLightFrom = s }
    function setTo(s) { Services.Prefs.nightLightTo = s }

    // wlsunset needs times OR a location, so we always pass times, and it
    // insists high temp > low temp. Scheduled: warm between -s=From and -S=To.
    // Manual: a ~24h "night" window (sunrise 00:00, sunset 00:01) so it holds
    // the warm temp constantly.
    readonly property var args: scheduled
        ? ["wlsunset", "-S", toTime, "-s", fromTime, "-T", "6500", "-t", String(temperature)]
        : ["wlsunset", "-S", "00:00", "-s", "00:01", "-T", "6500", "-t", String(temperature)]

    readonly property bool shouldRun: Services.Prefs.loaded && enabled

    // Process doesn't re-exec when `command` changes, so restart explicitly on
    // any change: drop the daemon, then bring it back (if it should run) with
    // the fresh args after a short beat.
    function apply() { proc.running = false; applyTimer.restart() }
    onArgsChanged: apply()
    onShouldRunChanged: apply()
    Component.onCompleted: if (shouldRun) apply()

    Timer { id: applyTimer; interval: 120; onTriggered: proc.running = root.shouldRun }

    Process {
        id: proc
        command: root.args
        running: false
    }
}
