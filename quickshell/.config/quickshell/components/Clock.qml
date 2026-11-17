import QtQuick
import "../styles"

// Time in the middle of the bar. Hover for the full date, click for the calendar.
Item {
    id: root

    property date currentTime: new Date()
    property bool active: false

    signal clicked

    implicitWidth: label.implicitWidth + 16
    implicitHeight: 24

    Rectangle {
        anchors.fill: parent
        radius: Theme.itemRadius
        color: root.active || hover.hovered ? Theme.surface : "transparent"
        border.width: root.active ? 1 : 0
        border.color: Theme.border
        scale: tap.pressed ? 0.96 : 1

        Behavior on color { ColorAnimation { duration: 120 } }
        Behavior on scale { NumberAnimation { duration: 90 } }
    }

    Text {
        id: label
        anchors.centerIn: parent
        text: Qt.formatDateTime(root.currentTime, "h:mm AP")
        color: Theme.text
        font.pixelSize: 13
        font.bold: true
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.currentTime = new Date()
    }

    HoverHandler {
        id: hover
        cursorShape: Qt.PointingHandCursor
    }

    // A TapHandler (not a MouseArea) so wheel events still reach the bar's page switcher.
    TapHandler {
        id: tap
        onTapped: root.clicked()
    }

    BarTooltip {
        target: root
        text: Qt.formatDateTime(root.currentTime, "dddd, d MMMM yyyy")
        hovered: hover.hovered && !root.active
    }
}
