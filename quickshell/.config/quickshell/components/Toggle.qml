import QtQuick
import "../styles"

// Pill-shaped on/off switch.
Item {
    id: root

    property bool checked: false
    signal toggled

    implicitWidth: 34
    implicitHeight: 18
    opacity: enabled ? 1 : 0.5

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: root.checked ? Theme.accent : Theme.surface
        border.width: 1
        border.color: root.checked ? Theme.accent : Theme.border

        Behavior on color { ColorAnimation { duration: 150 } }

        Rectangle {
            width: parent.height - 6
            height: width
            radius: width / 2
            anchors.verticalCenter: parent.verticalCenter
            x: root.checked ? parent.width - width - 3 : 3
            color: root.checked ? Theme.accentText : Theme.muted

            Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled()
    }
}
