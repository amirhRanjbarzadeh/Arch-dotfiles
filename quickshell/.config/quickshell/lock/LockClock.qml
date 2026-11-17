pragma ComponentBehavior: Bound

import QtQuick
import "../styles"

// Big clock. Each character rolls up to its new value when it changes.
Column {
    id: root

    property date now: new Date()
    readonly property string time: Qt.formatDateTime(now, "h:mm")
    readonly property string period: Qt.formatDateTime(now, "AP")
    readonly property string greeting: {
        const hour = now.getHours();
        if (hour < 5)
            return "Good night";
        if (hour < 12)
            return "Good morning";
        return hour < 18 ? "Good afternoon" : "Good evening";
    }
    property string name: ""

    spacing: 4

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.now = new Date()
    }

    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 10

        Row {
            id: digits

            Repeater {
                model: root.time.length

                delegate: Item {
                    id: slot

                    required property int index
                    readonly property string value: root.time.charAt(index)
                    property string shown: value

                    // The colon gets a narrower cell than the monospace digits.
                    width: value === ":" ? current.implicitWidth * 0.62 : current.implicitWidth
                    height: current.implicitHeight
                    clip: true

                    onValueChanged: {
                        previous.text = shown;
                        shown = value;
                        roll.restart();
                    }

                    Text {
                        id: previous
                        x: current.x
                        opacity: 0
                        color: Theme.text
                        font: current.font
                    }

                    Text {
                        id: current
                        x: Math.round((slot.width - implicitWidth) / 2)
                        text: slot.shown
                        color: Theme.text
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 118
                        font.weight: Font.Bold
                    }

                    ParallelAnimation {
                        id: roll

                        NumberAnimation { target: current; property: "y"; from: slot.height * 0.7; to: 0; duration: 520; easing.type: Easing.OutBack; easing.overshoot: 1.2 }
                        NumberAnimation { target: current; property: "opacity"; from: 0; to: 1; duration: 360; easing.type: Easing.OutCubic }
                        NumberAnimation { target: previous; property: "y"; from: 0; to: -slot.height * 0.7; duration: 420; easing.type: Easing.OutCubic }
                        NumberAnimation { target: previous; property: "opacity"; from: 1; to: 0; duration: 300; easing.type: Easing.OutCubic }
                    }
                }
            }
        }

        Text {
            anchors.baseline: digits.bottom
            anchors.baselineOffset: -30
            text: root.period
            color: Theme.accent
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 26
            font.weight: Font.Bold
        }
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: Qt.formatDateTime(root.now, "dddd, d MMMM")
        color: Theme.text
        font.pixelSize: 20
        font.weight: Font.DemiBold
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        topPadding: 2
        text: root.greeting + (root.name !== "" ? ", " + root.name.split(" ")[0] : "")
        color: Theme.subtle
        font.pixelSize: 14
    }
}
