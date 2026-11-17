import QtQuick
import "../styles"

// Round power button that only fires after being held, so a click that just
// wakes the screen never reboots the machine. Fills up while held.
Item {
    id: root

    property string icon: ""
    property string label: ""
    property color tint: Theme.accent
    property int holdDuration: 700
    property real progress: 0

    signal activated

    implicitWidth: 44
    implicitHeight: 44

    Rectangle {
        id: circle

        anchors.fill: parent
        radius: width / 2
        color: Theme.background
        border.width: 1
        border.color: mouse.containsMouse ? root.tint : Theme.border
        scale: mouse.pressed ? 0.92 : mouse.containsMouse ? 1.06 : 1
        clip: true

        Behavior on border.color { ColorAnimation { duration: 140 } }
        Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutBack } }

        // Fill rises from the bottom while held.
        Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width
            height: parent.height * root.progress
            color: root.tint
            opacity: 0.9
        }

        Text {
            anchors.centerIn: parent
            text: root.icon
            color: root.progress > 0.5 ? Theme.accentText : root.tint
            font.pixelSize: 18

            Behavior on color { ColorAnimation { duration: 120 } }
        }
    }

    // Label pops up above while hovered.
    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.top
        anchors.bottomMargin: mouse.containsMouse ? 10 : 4
        width: labelText.implicitWidth + 16
        height: 22
        radius: 11
        color: Theme.background
        border.width: 1
        border.color: Theme.border
        opacity: mouse.containsMouse ? 1 : 0

        Behavior on opacity { NumberAnimation { duration: 140 } }
        Behavior on anchors.bottomMargin { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

        Text {
            id: labelText
            anchors.centerIn: parent
            text: mouse.pressed ? "Hold to " + root.label.toLowerCase() : root.label
            color: Theme.subtle
            font.pixelSize: 10
        }
    }

    NumberAnimation {
        id: fill
        target: root
        property: "progress"
        to: 1
        duration: root.holdDuration * (1 - root.progress)
        onFinished: {
            if (root.progress >= 1) {
                root.activated();
                drain.restart();
            }
        }
    }

    NumberAnimation {
        id: drain
        target: root
        property: "progress"
        to: 0
        duration: 250
        easing.type: Easing.OutCubic
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onPressed: {
            drain.stop();
            fill.restart();
        }
        onReleased: {
            if (root.progress < 1) {
                fill.stop();
                drain.restart();
            }
        }
        onCanceled: {
            fill.stop();
            drain.restart();
        }
    }
}
