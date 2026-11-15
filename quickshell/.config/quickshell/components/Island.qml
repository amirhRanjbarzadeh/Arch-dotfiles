import QtQuick
import "../styles"

Item {
    id: root

    default property alias content: contentLayer.data

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: Theme.background
        border.width: 1
        border.color: Theme.border
    }

    Item {
        id: contentLayer
        anchors.fill: parent
    }
}
