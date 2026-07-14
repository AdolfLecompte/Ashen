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
    visible: Services.AppState.settingsVisible

    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    property var categories: [
        { id: "general", icon: "", label: "General" },
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
        if (id === "general") return "SettingsGeneralTab.qml"
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
        focus: win.visible
        Keys.onEscapePressed: Services.AppState.settingsVisible = false
    }

    Rectangle {
        id: card
        anchors.centerIn: parent
        width: 900
        height: 620
        radius: 18
        color: Services.Colors.surfaceAlpha(0.96)
        border.color: Services.Colors.ghostAlpha(0.2)
        border.width: 1
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
                anchors.margins: 12
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

                        Rectangle {
                            visible: hoverArea.containsMouse
                            anchors.left: parent.right
                            anchors.leftMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            height: 28
                            width: tipText.implicitWidth + 16
                            radius: 6
                            color: Services.Colors.abyss
                            z: 100
                            Text {
                                id: tipText
                                anchors.centerIn: parent
                                text: modelData.label
                                color: Services.Colors.snow
                                font.pixelSize: 11
                                font.family: "JetBrainsMono NF"
                            }
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
            anchors.bottom: parent.bottom
            anchors.left: sidebar.right
            width: 1
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
