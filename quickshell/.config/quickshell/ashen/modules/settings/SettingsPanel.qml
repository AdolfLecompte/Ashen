import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import "root:/services" as Services

Scope {
    id: root

    IpcHandler {
        target: "settings"
        function toggle() {
            Services.AppState.toggleOverlay("settingsVisible")
        }
    }

    PanelWindow {
    id: win
    anchors { top: true; left: true; right: true; bottom: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    // stays mapped through the close animation, so the exit plays in reverse
    readonly property bool shown: Services.AppState.settingsVisible
    visible: shown || closeDelay.running
    onShownChanged: if (!shown) closeDelay.restart()
    Timer { id: closeDelay; interval: 300 }

    WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    property var categories: [
        { id: "system", icon: "", label: "System" },
        { id: "wifi", icon: "", label: "Wi-Fi" },
        { id: "bluetooth", icon: "", label: "Bluetooth" },
        { id: "theme", icon: "", label: "Theme" },
        { id: "about", icon: "", label: "About" },
    ]

    function tabSource(id) {
        if (id === "wifi") return "SettingsWifiTab.qml"
        if (id === "bluetooth") return "SettingsBluetoothTab.qml"
        if (id === "system") return "SettingsSystemTab.qml"
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

    Rectangle {
        id: card
        anchors.centerIn: parent
        width: 1080
        height: 660
        radius: 18
        color: Services.Colors.surfaceAlpha(0.96)
        border.color: Services.Colors.ghostAlpha(0.2)
        border.width: 0
        clip: true

        opacity: Services.AppState.settingsVisible ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
        transform: Translate {
            x: Services.AppState.settingsVisible ? 0 : -24
            Behavior on x { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
        }

        MouseArea { anchors.fill: parent; onClicked: {} }

        Item {
            id: sidebar
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            width: 88

            Column {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                // Starts level with the divider (same 28) instead of riding
                // above where the line begins
                anchors.topMargin: 28
                anchors.bottomMargin: 28
                spacing: 8

                Repeater {
                    model: win.categories
                    delegate: Rectangle {
                        required property var modelData
                        width: parent.width
                        height: 48
                        radius: 12
                        color: Services.AppState.settingsTab === modelData.id ? Services.Colors.ghost : Services.Colors.ghostAlpha(0.08)
                        Behavior on color { ColorAnimation { duration: 150 } }

                        Text {
                            anchors.centerIn: parent
                            text: modelData.icon
                            font.family: "Material Symbols Rounded"
                            font.pixelSize: 20
                            color: Services.AppState.settingsTab === modelData.id ? Services.Colors.abyss : Services.Colors.mist
                        }

                        MouseArea {
                            id: hoverArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Services.AppState.settingsTab = modelData.id
                        }
                    }
                }
            }
        }

        Rectangle {
            anchors.top: parent.top
            anchors.topMargin: 28
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 28
            anchors.left: sidebar.right
            width: 1
            radius: 0.5
            color: Services.Colors.ghostAlpha(0.15)
        }

        // ── Content: one module per tab, loaded with a Loader (anchors, not RowLayout) ──
        Loader {
            id: tabLoader
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.left: sidebar.right
            anchors.leftMargin: 1
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
}
