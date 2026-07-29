import QtQuick
import QtQuick.Layouts

// Collapsible slot: same slide-open feel as the volume/mic DevicePicker.
// Wraps its children in a clipped Item whose height eases 0 <-> content, so
// sections grow/shrink smoothly instead of snapping in.
Item {
    id: cl
    property bool open: false
    property int gap: 10
    default property alias content: inner.data
    Layout.fillWidth: true
    clip: true
    implicitHeight: open ? inner.implicitHeight : 0
    Behavior on implicitHeight { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
    opacity: open ? 1.0 : 0.0
    Behavior on opacity { NumberAnimation { duration: 160 } }
    ColumnLayout {
        id: inner
        width: cl.width
        spacing: cl.gap
    }
}
