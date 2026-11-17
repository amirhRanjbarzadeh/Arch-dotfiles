import QtQuick
import QtQuick.Layouts
import "../styles"

// Icon + title (+ optional detail line) with an on/off switch. The whole row is clickable.
Item {
    id: root

    property string icon: ""
    property string title: ""
    property string detail: ""
    property bool checked: false
    // Tint for the icon while on (recording uses the error red).
    property color activeColor: Theme.accent

    signal toggled

    implicitHeight: 34
    opacity: enabled ? 1 : 0.5

    Rectangle {
        anchors.fill: parent
        radius: Theme.itemRadius
        color: mouseArea.containsMouse && root.enabled ? Theme.surface : "transparent"

        Behavior on color { ColorAnimation { duration: 120 } }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 6
        anchors.rightMargin: 4
        spacing: 10

        Text {
            Layout.preferredWidth: 20
            horizontalAlignment: Text.AlignHCenter
            text: root.icon
            color: root.checked ? root.activeColor : Theme.muted
            font.pixelSize: 16

            Behavior on color { ColorAnimation { duration: 150 } }
        }

        Column {
            Layout.fillWidth: true

            Text {
                width: parent.width
                text: root.title
                color: Theme.text
                font.pixelSize: 11
                font.bold: true
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                visible: root.detail !== ""
                text: root.detail
                color: Theme.muted
                font.pixelSize: 10
                elide: Text.ElideRight
            }
        }

        Toggle {
            checked: root.checked
            enabled: root.enabled
            onToggled: root.toggled()
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        // Under the switch, which handles its own clicks.
        z: -1
        hoverEnabled: true
        enabled: root.enabled
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled()
    }
}
