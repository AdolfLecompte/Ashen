import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

// The scrollable body every settings tab shares: same margins, same scrollbar,
// same spacing between cards. Children are stacked in the column, so a tab is
// just its list of Cards plus whatever state it needs.
Item {
    id: page
    default property alias content: col.data
    anchors.fill: parent

    Flickable {
        anchors.fill: parent
        anchors.margins: 28
        contentHeight: col.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded; width: 4 }

        ColumnLayout {
            id: col
            width: parent.width
            spacing: 14
        }
    }
}
