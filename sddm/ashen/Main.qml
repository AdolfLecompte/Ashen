import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root
    width: 1920
    height: 1080
    color: "#080809"

    // ── Ashen Ghost palette (copied from the shell's Colors.qml; SDDM cannot import the module) ──
    readonly property color abyss: "#080809"
    readonly property color surface: "#1c1c21"
    readonly property color ghost: "#6e6e7a"
    readonly property color snow: "#e8e8ec"
    readonly property color mist: "#9090a0"
    readonly property color ash: "#4a4a54"
    readonly property color error_: "#c87a7a"
    function ghostAlpha(a) { return Qt.rgba(0.431, 0.431, 0.478, a) }
    function surfaceAlpha(a) { return Qt.rgba(0.109, 0.109, 0.129, a) }

    property string selectedUser: userModel.lastUser
    property int sessionIndex: sessionModel.lastIndex >= 0 ? sessionModel.lastIndex : 0
    property string errorMessage: ""

    property string currentTime: Qt.formatDateTime(new Date(), "hh:mm")
    property string currentDate: Qt.formatDateTime(new Date(), "dddd, MMMM d")

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: {
            root.currentTime = Qt.formatDateTime(new Date(), "hh:mm")
            root.currentDate = Qt.formatDateTime(new Date(), "dddd, MMMM d")
        }
    }

    Connections {
        target: sddm
        function onLoginSucceeded() {
            root.errorMessage = ""
        }
        function onLoginFailed() {
            passwordField.text = ""
            root.errorMessage = "Incorrect password"
            shakeAnim.start()
        }
        function onInformationMessage(message) {
            root.errorMessage = message
        }
    }

    function doLogin() {
        if (root.selectedUser.length === 0) return
        sddm.login(root.selectedUser, passwordField.text, root.sessionIndex)
    }

    // ── Reloj ──
    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: parent.height * 0.12
        spacing: 4

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.currentTime
            color: root.snow
            font.pixelSize: 96
            font.bold: true
            font.family: "JetBrainsMono NF"
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.currentDate
            color: root.mist
            font.pixelSize: 18
            font.family: "JetBrainsMono NF"
        }
    }

    // ── Tarjeta de login ──
    Rectangle {
        id: card
        anchors.centerIn: parent
        width: 360
        height: loginCol.height + 48
        radius: 18
        color: root.surfaceAlpha(0.85)
        border.color: root.ghostAlpha(0.2)
        border.width: 1

        transform: Translate {
            id: shakeT
            x: 0
        }
        SequentialAnimation {
            id: shakeAnim
            NumberAnimation { target: shakeT; property: "x"; to: -10; duration: 40 }
            NumberAnimation { target: shakeT; property: "x"; to: 10; duration: 80 }
            NumberAnimation { target: shakeT; property: "x"; to: -6; duration: 80 }
            NumberAnimation { target: shakeT; property: "x"; to: 0; duration: 60 }
        }

        Column {
            id: loginCol
            anchors.centerIn: parent
            width: parent.width - 48
            spacing: 16

            // Avatar
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 64; height: 64
                radius: 32
                color: root.ghostAlpha(0.15)
                border.color: root.ghostAlpha(0.3)
                border.width: 1
                Text {
                    anchors.centerIn: parent
                    text: "\ue7fd"
                    color: root.ghost
                    font.pixelSize: 30
                    font.family: "Material Symbols Rounded"
                }
            }

            // User selector (only if there is more than one)
            Flow {
                width: parent.width
                spacing: 6
                visible: userModel.count > 1
                Repeater {
                    model: userModel
                    delegate: Rectangle {
                        required property string name
                        height: 26
                        width: uLabel.implicitWidth + 16
                        radius: 8
                        color: root.selectedUser === name ? root.ghost : root.ghostAlpha(0.12)
                        Behavior on color { ColorAnimation { duration: 150 } }
                        Text {
                            id: uLabel
                            anchors.centerIn: parent
                            text: name
                            font.pixelSize: 11
                            font.family: "JetBrainsMono NF"
                            color: root.selectedUser === name ? root.abyss : root.mist
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.selectedUser = name
                        }
                    }
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: userModel.count <= 1
                text: root.selectedUser
                color: root.snow
                font.pixelSize: 15
                font.bold: true
                font.family: "JetBrainsMono NF"
            }

            // Contrasena
            Rectangle {
                width: parent.width
                height: 44
                radius: 10
                color: root.ghostAlpha(0.1)
                border.color: passwordField.activeFocus ? root.ghost : root.ghostAlpha(0.25)
                border.width: 1
                Behavior on border.color { ColorAnimation { duration: 150 } }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 8
                    spacing: 8

                    Text {
                        text: "\ue897"
                        color: root.ghost
                        font.pixelSize: 16
                        font.family: "Material Symbols Rounded"
                    }

                    Item {
                        Layout.fillWidth: true
                        height: 26
                        TextInput {
                            id: passwordField
                            anchors.fill: parent
                            verticalAlignment: TextInput.AlignVCenter
                            color: root.snow
                            font.pixelSize: 13
                            font.family: "JetBrainsMono NF"
                            echoMode: showPassBtn.show ? TextInput.Normal : TextInput.Password
                            focus: true
                            Keys.onReturnPressed: root.doLogin()
                        }
                    }

                    Text {
                        id: showPassBtn
                        property bool show: false
                        text: show ? "\ue8f5" : "\ue8f4"
                        color: root.mist
                        font.pixelSize: 15
                        font.family: "Material Symbols Rounded"
                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -6
                            cursorShape: Qt.PointingHandCursor
                            onClicked: showPassBtn.show = !showPassBtn.show
                        }
                    }
                }
            }

            // Mensaje de error
            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                visible: root.errorMessage.length > 0
                text: root.errorMessage
                color: root.error_
                font.pixelSize: 11
                font.family: "JetBrainsMono NF"
            }

            // Boton de login
            Rectangle {
                width: parent.width
                height: 40
                radius: 10
                color: root.ghost
                Text {
                    anchors.centerIn: parent
                    text: "Login"
                    color: root.abyss
                    font.pixelSize: 13
                    font.bold: true
                    font.family: "JetBrainsMono NF"
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.doLogin()
                }
            }

            // Session selector (only if there is more than one)
            Flow {
                width: parent.width
                spacing: 6
                visible: sessionModel.count > 1
                anchors.horizontalCenter: parent.horizontalCenter
                Repeater {
                    model: sessionModel
                    delegate: Rectangle {
                        required property string name
                        required property int index
                        height: 24
                        width: sLabel.implicitWidth + 14
                        radius: 7
                        color: root.sessionIndex === index ? root.ghostAlpha(0.3) : "transparent"
                        Text {
                            id: sLabel
                            anchors.centerIn: parent
                            text: name
                            font.pixelSize: 10
                            font.family: "JetBrainsMono NF"
                            color: root.sessionIndex === index ? root.snow : root.ash
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.sessionIndex = index
                        }
                    }
                }
            }
        }
    }

    // ── Caps Lock ──
    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: card.bottom
        anchors.topMargin: 14
        visible: keyboard.capsLock
        text: "CAPS LOCK ON"
        color: root.error_
        font.pixelSize: 10
        font.bold: true
        font.family: "JetBrainsMono NF"
        font.letterSpacing: 1
    }

    // ── Botones de energia ──
    Row {
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        anchors.margins: 24
        spacing: 10

        Repeater {
            model: [
                { icon: "\uef44", action: "suspend", visible: sddm.canSuspend },
                { icon: "\uf053", action: "reboot", visible: true },
                { icon: "\ue8ac", action: "poweroff", visible: true },
            ]
            delegate: Rectangle {
                required property var modelData
                visible: modelData.visible
                width: 40; height: 40
                radius: 12
                color: "transparent"
                Text {
                    anchors.centerIn: parent
                    text: modelData.icon
                    color: root.mist
                    font.pixelSize: 18
                    font.family: "Material Symbols Rounded"
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onEntered: parent.color = root.ghostAlpha(0.15)
                    onExited: parent.color = "transparent"
                    onClicked: {
                        if (modelData.action === "suspend") sddm.suspend()
                        else if (modelData.action === "reboot") sddm.reboot()
                        else if (modelData.action === "poweroff") sddm.powerOff()
                    }
                }
            }
        }
    }

    Component.onCompleted: passwordField.forceActiveFocus()
}
