import QtQuick
import "../styles"

// Themed text button (replaces the unstyled QtQuick.Controls Button).
Rectangle {
    id: root

    property string text: ""
    property bool primary: false
    signal clicked

    implicitWidth: label.implicitWidth + 24
    implicitHeight: 28
    radius: Theme.itemRadius
    opacity: enabled ? 1 : 0.45

    color: {
        if (primary)
            return mouseArea.containsMouse ? Qt.lighter(Theme.accent, 1.08) : Theme.accent;
        return mouseArea.containsMouse ? Theme.border : Theme.surface;
    }

    Behavior on color { ColorAnimation { duration: 120 } }

    Text {
        id: label
        anchors.centerIn: parent
        text: root.text
        color: root.primary ? Theme.accentText : Theme.text
        font.pixelSize: 11
        font.bold: true
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        enabled: root.enabled
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
