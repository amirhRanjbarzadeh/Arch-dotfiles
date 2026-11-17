pragma ComponentBehavior: Bound

import Quickshell.Widgets
import QtQuick
import "../styles"

// Now-playing pill beside the launcher button, outside the island: cover art,
// bouncing bars while playing (still while paused), title and artist.
// Click to open the media panel.
Item {
    id: root

    property var player: null
    property int maximumWidth: 280
    property bool active: false

    signal clicked

    readonly property bool playing: player?.isPlaying ?? false
    readonly property string title: player?.trackTitle || player?.identity || ""
    readonly property string artist: player?.trackArtist ?? ""

    // Slides in and out instead of popping.
    readonly property bool shown: player !== null && title !== ""
    visible: opacity > 0
    opacity: shown ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: Theme.animDuration } }

    implicitHeight: Theme.barHeight
    implicitWidth: Math.min(maximumWidth, content.implicitWidth + 2 * 6 + 8)

    Behavior on implicitWidth { NumberAnimation { duration: Theme.animDuration; easing.type: Easing.OutCubic } }

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: root.active || mouseArea.containsMouse ? Theme.surface : Theme.background
        border.width: 1
        border.color: root.active ? Theme.accent : Theme.border
        scale: mouseArea.pressed ? 0.96 : 1

        Behavior on color { ColorAnimation { duration: 120 } }
        Behavior on border.color { ColorAnimation { duration: 120 } }
        Behavior on scale { NumberAnimation { duration: 90 } }
    }

    Row {
        id: content

        anchors.left: parent.left
        anchors.leftMargin: 5
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8

        // Cover art, or a note when there is none.
        ClippingRectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: Theme.barHeight - 10
            height: width
            radius: width / 2
            color: Theme.surface

            Image {
                id: cover
                anchors.fill: parent
                source: root.player?.trackArtUrl ?? ""
                sourceSize.width: 48
                sourceSize.height: 48
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                visible: status === Image.Ready
            }

            Text {
                anchors.centerIn: parent
                visible: !cover.visible
                text: Icons.music
                color: Theme.accent
                font.pixelSize: 12
            }
        }

        // Equalizer
        Row {
            anchors.verticalCenter: parent.verticalCenter
            height: 12
            spacing: 2

            Repeater {
                model: [0.55, 1.0, 0.7]

                delegate: Rectangle {
                    id: bar

                    required property real modelData
                    required property int index
                    // 0..1, bounced by the animation while playing.
                    property real level: modelData

                    anchors.bottom: parent.bottom
                    width: 3
                    radius: 1.5
                    // Paused: short, still bars.
                    height: root.playing ? Math.max(3, 12 * level) : 4
                    color: root.playing ? Theme.accent : Theme.muted

                    Behavior on color { ColorAnimation { duration: 180 } }

                    SequentialAnimation on level {
                        running: root.playing && root.visible
                        loops: Animation.Infinite

                        PauseAnimation { duration: bar.index * 90 }
                        NumberAnimation { to: 1; duration: 260 + bar.index * 40; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 0.25; duration: 300 + bar.index * 50; easing.type: Easing.InOutSine }
                        NumberAnimation { to: bar.modelData; duration: 240; easing.type: Easing.InOutSine }
                    }
                }
            }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            // Whatever room is left in the pill after the cover and bars.
            width: Math.min(implicitWidth, root.maximumWidth - (x + 6 + 8))
            textFormat: Text.StyledText
            text: {
                const title = root.title.replace(/&/g, "&amp;").replace(/</g, "&lt;");
                const artist = root.artist.replace(/&/g, "&amp;").replace(/</g, "&lt;");
                return artist ? "<b>" + title + "</b> <font color=\"" + Theme.muted + "\">· " + artist + "</font>" : "<b>" + title + "</b>";
            }
            color: root.playing ? Theme.text : Theme.subtle
            font.pixelSize: 11
            elide: Text.ElideRight
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
