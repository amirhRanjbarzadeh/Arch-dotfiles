import QtQuick
import "../styles"

Text {
    id: root

    property date currentTime: new Date()

    text: Qt.formatDateTime(currentTime, "h:mm AP")
    color: Theme.text
    font.pixelSize: 13
    font.bold: true

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.currentTime = new Date()
    }

    HoverHandler {
        id: hover
    }

    BarTooltip {
        target: root
        text: Qt.formatDateTime(root.currentTime, "dddd, d MMMM yyyy")
        hovered: hover.hovered
    }
}
