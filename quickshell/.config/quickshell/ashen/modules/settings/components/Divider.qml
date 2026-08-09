import QtQuick
import QtQuick.Layouts
import "root:/services" as Services

// Hairline between two groups of rows.
Rectangle {
    Layout.fillWidth: true
    height: 1
    color: Services.Colors.fillLine
}
