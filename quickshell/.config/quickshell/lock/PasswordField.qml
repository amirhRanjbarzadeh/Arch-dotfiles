pragma ComponentBehavior: Bound

import QtQuick
import "../styles"

// Password pill. Shows one dot per character (popping in as you type), waves
// them while PAM checks, shakes on a wrong password and turns green on success.
Rectangle {
    id: root

    property int length: 0
    property bool checking: false
    property bool success: false
    property bool capsLock: false
    property bool focused: true
    property int failCount: 0
    property string placeholder: "Enter password"

    // Red border for a moment after a failed attempt.
    property bool failFlash: false
    // Wave phase while checking.
    property real phase: 0
    readonly property int maxDots: 22

    implicitWidth: 300
    implicitHeight: 46
    radius: height / 2
    color: Theme.surface
    border.width: 1
    border.color: {
        if (success)
            return Theme.success;
        if (failFlash)
            return Theme.error;
        if (checking || focused)
            return Theme.accent;
        return Theme.border;
    }

    Behavior on border.color { ColorAnimation { duration: 180 } }

    transform: Translate { id: shakeOffset }

    onFailCountChanged: {
        failFlash = true;
        failTimer.restart();
        shake.restart();
    }

    Timer {
        id: failTimer
        interval: 1400
        onTriggered: root.failFlash = false
    }

    SequentialAnimation {
        id: shake

        NumberAnimation { target: shakeOffset; property: "x"; to: -14; duration: 50; easing.type: Easing.OutQuad }
        NumberAnimation { target: shakeOffset; property: "x"; to: 12; duration: 70; easing.type: Easing.InOutQuad }
        NumberAnimation { target: shakeOffset; property: "x"; to: -9; duration: 65; easing.type: Easing.InOutQuad }
        NumberAnimation { target: shakeOffset; property: "x"; to: 6; duration: 60; easing.type: Easing.InOutQuad }
        NumberAnimation { target: shakeOffset; property: "x"; to: -3; duration: 55; easing.type: Easing.InOutQuad }
        NumberAnimation { target: shakeOffset; property: "x"; to: 0; duration: 50; easing.type: Easing.OutQuad }
    }

    NumberAnimation on phase {
        running: root.checking
        from: 0
        to: 2 * Math.PI
        duration: 900
        loops: Animation.Infinite
    }

    // Lock icon; opens up on success.
    Text {
        id: lockIcon

        anchors.left: parent.left
        anchors.leftMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        text: root.success ? Icons.lockOpen : Icons.lock
        color: root.success ? Theme.success : root.failFlash ? Theme.error : Theme.accent
        font.pixelSize: 18
        scale: root.success ? 1.2 : 1

        Behavior on color { ColorAnimation { duration: 180 } }
        Behavior on scale { NumberAnimation { duration: 320; easing.type: Easing.OutBack; easing.overshoot: 3 } }
    }

    Item {
        id: field

        anchors.left: lockIcon.right
        anchors.leftMargin: 10
        anchors.right: capsBadge.left
        anchors.rightMargin: 10
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        clip: true

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.placeholder
            color: Theme.muted
            font.pixelSize: 14
            opacity: root.length === 0 && !root.checking ? 1 : 0
            x: root.length === 0 ? 0 : 12

            Behavior on opacity { NumberAnimation { duration: 160 } }
            Behavior on x { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
        }

        Row {
            id: dots

            anchors.verticalCenter: parent.verticalCenter
            // Grow from the left, keep the newest dot in view once it overflows.
            x: Math.min(0, field.width - width)
            spacing: 7

            Behavior on x { NumberAnimation { duration: 120 } }

            Repeater {
                model: Math.min(root.length, root.maxDots)

                delegate: Rectangle {
                    id: dot

                    required property int index

                    width: 9
                    height: 9
                    radius: 4.5
                    color: root.success ? Theme.success : root.checking ? Theme.accent : Theme.text
                    transform: Translate {
                        y: root.checking ? -4 * Math.sin(root.phase - dot.index * 0.55) : 0
                    }

                    Behavior on color { ColorAnimation { duration: 160 } }

                    NumberAnimation on scale {
                        from: 0
                        to: 1
                        duration: 220
                        easing.type: Easing.OutBack
                        easing.overshoot: 2.4
                    }
                }
            }
        }
    }

    // Caps Lock warning.
    Rectangle {
        id: capsBadge

        anchors.right: parent.right
        anchors.rightMargin: root.capsLock ? 10 : 4
        anchors.verticalCenter: parent.verticalCenter
        width: root.capsLock ? capsText.implicitWidth + 14 : 0
        height: 22
        radius: height / 2
        color: Qt.rgba(Theme.warning.r, Theme.warning.g, Theme.warning.b, 0.16)
        opacity: root.capsLock ? 1 : 0
        clip: true

        Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: 160 } }
        Behavior on anchors.rightMargin { NumberAnimation { duration: 200 } }

        Text {
            id: capsText
            anchors.centerIn: parent
            text: "CAPS"
            color: Theme.warning
            font.pixelSize: 10
            font.bold: true
        }
    }
}
