import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import "root:/services" as Services
import "root:/modules/settings/components"

PanelWindow {
    id: win
    anchors { top: true; left: true; right: true; bottom: true }
    screen: Services.Screens.active
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    // stays mapped through the close animation, so the exit plays in reverse
    readonly property bool shown: Services.AppState.settingsVisible
    visible: shown || closeDelay.running
    onShownChanged: if (!shown) closeDelay.restart()
    Timer { id: closeDelay; interval: 300 }

    WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // One tab per question the user is actually asking ("how does the bar look?",
    // "what is this machine talking to?"). Wi-Fi and Bluetooth share one, since
    // they are the same question, and each tab is small enough to scan.
    property var categories: [
        { id: "system", icon: "\ue429", label: "System" },
        { id: "bar", icon: "", label: "Bar" },
        { id: "display", icon: "\ueb97", label: "Display" },
        { id: "sound", icon: "\ue050", label: "Sound" },
        { id: "network", icon: "\ue1ba", label: "Network" },
        { id: "input", icon: "\ue312", label: "Input" },
        { id: "notifications", icon: "\ue7f5", label: "Notifications" },
        { id: "theme", icon: "\ue40a", label: "Appearance" },
        { id: "about", icon: "\ue88e", label: "About" },
    ]

    function tabSource(id) {
        // "wifi" and "bluetooth" still resolve: they were tab ids of their own
        // before the Network merge, and old ipc calls or launcher entries may
        // still ask for them.
        if (id === "wifi" || id === "bluetooth" || id === "network") return "SettingsNetworkTab.qml"
        if (id === "system") return "SettingsSystemTab.qml"
        if (id === "bar") return "SettingsBarTab.qml"
        if (id === "display") return "SettingsDisplayTab.qml"
        if (id === "sound") return "SettingsSoundTab.qml"
        if (id === "input") return "SettingsInputTab.qml"
        if (id === "notifications") return "SettingsNotificationsTab.qml"
        if (id === "theme") return "SettingsThemeTab.qml"
        if (id === "about") return "SettingsAboutTab.qml"
        return ""
    }

    MouseArea {
        anchors.fill: parent
        z: -1
        onClicked: Services.AppState.settingsVisible = false
    }

    FocusScope {
        anchors.fill: parent
        focus: win.shown
        Keys.onEscapePressed: Services.AppState.settingsVisible = false
    }

    // Right-hand drawer: full height between the bar and the far edge, wide
    // enough for the tabs that the old centred card used to hold.
    Rectangle {
        id: card
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        anchors.topMargin: Services.Sizes.marginTop
        anchors.bottomMargin: Services.Sizes.marginBottom
        anchors.rightMargin: Services.Sizes.marginRight
        width: 560
        radius: 18
        color: Services.Colors.surfaceAlpha(0.96)
        border.color: Services.Colors.ghostAlpha(0.2)
        border.width: 0
        clip: true

        // Slides in from the right edge it is docked to
        opacity: win.shown ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
        transform: Translate {
            x: win.shown ? 0 : 48
            Behavior on x { NumberAnimation { duration: 280; easing.type: Easing.OutQuint } }
        }

        MouseArea { anchors.fill: parent; onClicked: {} }

        // ── Header: section title over the category rail ──────────────────
        // The rail runs across the top instead of down the side: the drawer is
        // already a tall narrow column, and a second vertical strip inside it
        // fought the content for width.
        Item {
            id: header
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 118

            readonly property string title: {
                for (const c of win.categories)
                    if (c.id === Services.AppState.settingsTab) return c.label
                return ""
            }

            Text {
                id: titleText
                anchors.left: parent.left
                anchors.leftMargin: 24
                anchors.top: parent.top
                anchors.topMargin: 20
                text: header.title
                color: Services.Colors.snow
                font.pixelSize: 20
                font.bold: true
                font.family: "JetBrainsMono NF"
            }

            // Same travelling accent as the workspace pill, so picking a
            // section reads like every other exclusive choice in the shell.
            Segmented {
                id: rail
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.leftMargin: 20
                anchors.rightMargin: 20
                anchors.bottomMargin: 16
                iconOnly: true
                cellHeight: 40
                options: win.categories
                current: Services.AppState.settingsTab
                onPicked: id => Services.AppState.settingsTab = id
            }
        }

        Rectangle {
            anchors.top: header.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 24
            anchors.rightMargin: 24
            height: 1
            color: Services.Colors.ghostAlpha(0.15)
        }

        // ── Content: one module per tab, loaded with a Loader (anchors, not RowLayout) ──
        Loader {
            id: tabLoader
            anchors.top: header.bottom
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            source: win.tabSource(Services.AppState.settingsTab)
            onStatusChanged: {
                if (status === Loader.Error) {
                    console.log("[SettingsPanel] ERROR loading", source, ":", sourceComponent ? sourceComponent.errorString() : "no details")
                } else if (status === Loader.Ready) {
                    console.log("[SettingsPanel] OK cargado:", source)
                }
            }
        }
    }
}
