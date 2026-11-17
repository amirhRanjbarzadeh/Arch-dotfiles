import QtQuick
import "../styles"

// Sliding selection pill for island list views: an accent tint with a bar on the left.
// Use as a ListView `highlight`; the ListView sizes it to the current row.
Rectangle {
    radius: 12
    color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.14)
    border.width: 1
    border.color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.35)

    Rectangle {
        anchors.left: parent.left
        anchors.leftMargin: 4
        anchors.verticalCenter: parent.verticalCenter
        width: 3
        height: Math.min(20, parent.height - 16)
        radius: 2
        color: Theme.accent
    }
}
