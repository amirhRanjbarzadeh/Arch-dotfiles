import QtQuick
import "../styles"

Item {
    id: root

    property bool active: false
    signal clicked

    implicitWidth: 30
    implicitHeight: 24
    width: implicitWidth
    height: implicitHeight

    Rectangle {
        anchors.fill: parent
        radius: 8
        color: root.active || trayMouseArea.containsMouse ? Theme.surface : "transparent"
        border.width: root.active ? 1 : 0
        border.color: Theme.border

        Text {
            anchors.centerIn: parent
            text: "󰅀"
            color: root.active ? Theme.accent : Theme.text
            font.pixelSize: 15
            rotation: root.active ? 180 : 0
            transformOrigin: Item.Center

            Behavior on rotation {
                NumberAnimation {
                    duration: 280
                    easing.type: Easing.InOutCubic
                }
            }
        }

        MouseArea {
            id: trayMouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.clicked()
        }
    }

}
