pragma ComponentBehavior: Bound

import QtQuick
import "../styles"

// Row of keyboard hints ("↵ open") shown at the bottom of island list views.
Row {
    id: root

    // [{ keys: "↵", label: "open" }, …]
    property var hints: []

    height: 18
    spacing: 16

    Repeater {
        model: root.hints

        delegate: Row {
            id: hint

            required property var modelData

            height: root.height
            spacing: 6

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: keyText.implicitWidth + 10
                height: 16
                radius: 4
                color: Theme.surface
                border.width: 1
                border.color: Theme.border

                Text {
                    id: keyText
                    anchors.centerIn: parent
                    text: hint.modelData.keys
                    color: Theme.subtle
                    font.pixelSize: 9
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: hint.modelData.label
                color: Theme.muted
                font.pixelSize: 10
            }
        }
    }
}
