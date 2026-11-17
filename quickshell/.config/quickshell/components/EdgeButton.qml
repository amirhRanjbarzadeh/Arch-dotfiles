import QtQuick
import "../styles"

// A round button in the bar's style, pinned to a screen edge outside the island.
Item {
    id: root

    property string icon: ""
    property color iconColor: Theme.text
    property int iconSize: 16
    property string tooltip: ""
    property bool active: false
    // Horizontal nudge for glyphs that don't sit centered in their font box.
    property real iconOffsetX: 0

    signal clicked

    implicitWidth: Theme.barHeight
    implicitHeight: Theme.barHeight

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: root.active || mouseArea.containsMouse ? Theme.surface : Theme.background
        border.width: 1
        border.color: root.active ? Theme.accent : Theme.border
        scale: mouseArea.pressed ? 0.92 : 1

        Behavior on color { ColorAnimation { duration: 120 } }
        Behavior on border.color { ColorAnimation { duration: 120 } }
        Behavior on scale { NumberAnimation { duration: 90 } }

        Text {
            anchors.centerIn: parent
            anchors.horizontalCenterOffset: root.iconOffsetX
            text: root.icon
            color: root.iconColor
            font.pixelSize: root.iconSize
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }

    BarTooltip {
        target: root
        text: root.tooltip
        hovered: mouseArea.containsMouse
    }
}
