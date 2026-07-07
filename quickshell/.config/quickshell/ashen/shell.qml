import Quickshell
import QtQuick

import "root:/modules/bar"
import "root:/modules/lock"
import "root:/modules/launcher"

ShellRoot {
    Bar {}
    PowerMenu {}
    Calendar {}
    NetworkPanel {}
    BluetoothPanel {}
    LockScreen {}
    Launcher {}
}
