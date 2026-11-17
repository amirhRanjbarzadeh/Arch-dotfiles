pragma ComponentBehavior: Bound

import Quickshell.Widgets
import QtQuick
import "../styles"

// Now-playing pill for the lock screen: art, track and transport buttons.
Rectangle {
    id: root

    property var service // MediaService
    readonly property var player: service?.player ?? null
    readonly property bool playing: player?.isPlaying ?? false
    readonly property real progress: (player?.lengthSupported && player.length > 0) ? Math.min(1, player.position / player.length) : 0

    implicitWidth: 380
    implicitHeight: 60
    radius: height / 2
    color: Theme.background
    border.width: 1
    border.color: Theme.border

    // Thin progress line along the bottom edge.
    Rectangle {
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.leftMargin: root.radius
        anchors.bottomMargin: 1
        width: (parent.width - 2 * root.radius) * root.progress
        height: 2
        radius: 1
        color: Theme.accent
        opacity: root.progress > 0 ? 0.8 : 0

        Behavior on width { NumberAnimation { duration: 900 } }
    }

    ClippingRectangle {
        id: art

        anchors.left: parent.left
        anchors.leftMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        width: 40
        height: 40
        radius: 20
        color: Theme.surface

        Text {
            anchors.centerIn: parent
            visible: artImage.status !== Image.Ready
            text: Icons.music
            color: Theme.accent
            font.pixelSize: 18
        }

        Image {
            id: artImage
            anchors.fill: parent
            source: root.player?.trackArtUrl ?? ""
            sourceSize.width: 80
            sourceSize.height: 80
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
        }

        // Spins slowly while playing, like a record.
        RotationAnimation on rotation {
            running: root.playing && root.visible
            from: art.rotation
            to: art.rotation + 360
            duration: 12000
            loops: Animation.Infinite
        }
    }

    Column {
        anchors.left: art.right
        anchors.leftMargin: 12
        anchors.right: controls.left
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        spacing: 1

        Text {
            width: parent.width
            text: root.player?.trackTitle || "Unknown track"
            color: Theme.text
            font.pixelSize: 13
            font.bold: true
            elide: Text.ElideRight
        }

        Text {
            width: parent.width
            text: root.player?.trackArtist || root.player?.identity || ""
            color: Theme.muted
            font.pixelSize: 11
            elide: Text.ElideRight
        }
    }

    Row {
        id: controls

        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2

        Repeater {
            model: [
                { icon: Icons.skipPrevious, action: () => root.service.previous(), main: false },
                { icon: root.playing ? Icons.pause : Icons.play, action: () => root.service.togglePlaying(), main: true },
                { icon: Icons.skipNext, action: () => root.service.next(), main: false }
            ]

            delegate: Rectangle {
                id: button

                required property var modelData

                anchors.verticalCenter: parent.verticalCenter
                width: modelData.main ? 36 : 30
                height: width
                radius: width / 2
                color: modelData.main ? Theme.accent : mouse.containsMouse ? Theme.surface : "transparent"
                scale: mouse.pressed ? 0.88 : 1

                Behavior on color { ColorAnimation { duration: 120 } }
                Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutBack } }

                Text {
                    anchors.centerIn: parent
                    text: button.modelData.icon
                    color: button.modelData.main ? Theme.accentText : Theme.text
                    font.pixelSize: button.modelData.main ? 18 : 16
                }

                MouseArea {
                    id: mouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: button.modelData.action()
                }
            }
        }
    }
}
