import QtQuick
import "root:/services" as Services
import "root:/modules/settings/components"

// Wi-Fi and Bluetooth are one question — "what is this machine talking to?" —
// so they share a tab and a switch instead of two rail slots. Each list is
// still its own file; this only decides which one is on screen.
Item {
    id: tab
    anchors.fill: parent

    property string section: "wifi"

    Segmented {
        id: picker
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.topMargin: 28
        anchors.leftMargin: 28
        anchors.rightMargin: 28
        cellHeight: 38
        options: [
            { id: "wifi", icon: "", label: "Wi-Fi" },
            { id: "bluetooth", icon: "", label: "Bluetooth" }
        ]
        current: tab.section
        onPicked: id => tab.section = id
    }

    Loader {
        anchors.top: picker.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        // The loaded tab brings its own 28px margins, so it only needs the gap
        // under the switch.
        anchors.topMargin: 4
        source: tab.section === "wifi" ? "SettingsWifiTab.qml" : "SettingsBluetoothTab.qml"
    }
}
