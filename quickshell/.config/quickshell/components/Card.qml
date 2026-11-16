import QtQuick
import QtQuick.Effects
import "../styles"

// Rounded surface shared by every island view and popup.
Rectangle {
    id: root

    default property alias content: contentItem.data
    property int padding: Theme.popupPadding
    property bool shadowEnabled: true

    radius: Theme.popupRadius
    color: Theme.popupBackground
    border.width: Theme.popupBorderWidth
    border.color: Theme.border

    layer.enabled: shadowEnabled
    layer.effect: MultiEffect {
        shadowEnabled: true
        shadowColor: Theme.shadow
        shadowBlur: 0.8
        shadowVerticalOffset: 7
        shadowScale: 1.03
    }

    Item {
        id: contentItem
        anchors.fill: parent
        anchors.margins: root.padding
    }
}
