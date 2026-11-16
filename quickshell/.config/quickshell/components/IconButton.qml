import QtQuick
import "../styles"

// Small clickable glyph with hover background and an optional tooltip.
Item {
    id: root

    property string icon: ""
    property color iconColor: Theme.text
    property int iconSize: 14
    property real iconRotation: 0
    property string label: ""
    property bool active: false
    property string tooltip: ""
    // When false, wheel events pass through to the parent (the bar uses them to switch pages).
    property bool acceptsWheel: false
    readonly property bool hovered: mouseArea.containsMouse

    signal clicked
    signal scrolled(int delta)

    implicitWidth: Math.max(26, row.implicitWidth + 10)
    implicitHeight: 24

    Rectangle {
        anchors.fill: parent
        radius: Theme.itemRadius
        color: root.active || root.hovered ? Theme.surface : "transparent"
        border.width: root.active ? 1 : 0
        border.color: Theme.border

        Behavior on color { ColorAnimation { duration: 120 } }
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 4

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.icon
            color: root.iconColor
            font.pixelSize: root.iconSize
            rotation: root.iconRotation

            Behavior on rotation { NumberAnimation { duration: 280; easing.type: Easing.InOutCubic } }
            Behavior on color { ColorAnimation { duration: 120 } }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.label !== ""
            text: root.label
            color: root.iconColor
            font.pixelSize: 11
            font.bold: true
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
        onWheel: wheel => {
            if (!root.acceptsWheel) {
                wheel.accepted = false;
                return;
            }
            root.scrolled(wheel.angleDelta.y !== 0 ? wheel.angleDelta.y : wheel.angleDelta.x);
        }
    }

    BarTooltip {
        target: root
        text: root.tooltip
        hovered: root.hovered
    }
}
