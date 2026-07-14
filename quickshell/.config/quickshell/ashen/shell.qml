import Quickshell
import QtQuick

import "root:/modules/bar"
import "root:/modules/lock"
import "root:/modules/launcher"
import "root:/modules/wallpaper"
import "root:/modules/settings"
import "root:/modules/emojis"
import "root:/modules/glyph"
import "root:/modules/clipboard"

ShellRoot {
    Bar {}
    MediaPanel {}
    OsdPanel {}
    VolumePanel {}
    BrightnessPanel {}
    BatteryPanel {}
    NotificationPanel {}
    NotificationToast {}
    SettingsPanel {}
    PowerMenu {}
    Calendar {}
    NetworkPanel {}
    BluetoothPanel {}
    USBPanel {}
    TrayMenu {}
    LockScreen {}
    Launcher {}
    WallpaperPicker {}
    Emojis {}
    Glyph {}
    Clipboard {}
}
