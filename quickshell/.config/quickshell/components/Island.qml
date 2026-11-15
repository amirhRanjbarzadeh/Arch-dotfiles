import QtQuick
import "../styles"

Item {
    id: root

    default property alias content: contentLayer.data
    property bool backgroundVisible: true

    Rectangle {
        anchors.fill: parent
        visible: root.backgroundVisible
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
