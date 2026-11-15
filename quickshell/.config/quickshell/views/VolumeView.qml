import Quickshell
import QtQuick
import QtQuick.Effects
import QtQuick.Controls
import "../styles"

Item {
    id: root
    property var barWindow
    property var audioSink

    implicitWidth: 240
    implicitHeight: 78

    Rectangle {
        anchors.fill: parent

        radius: 14
        color: Theme.popupBackground

        border {
            width: 1
            color: Theme.border
        }

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Theme.shadow
            shadowBlur: 0.8
            shadowVerticalOffset: 7
            shadowScale: 1.03
        }

        Column {
            anchors {
                fill: parent
                margins: 12
            }

            spacing: 4

            Item {
                width: parent.width
                height: 22

                Rectangle {
                    id: muteButton
                    width: 24
                    height: 22
                    radius: 7
                    color: muteMouseArea.containsMouse ? Theme.surface : "transparent"
                    opacity: root.audioSink?.audio ? 1 : 0.5

                    Text {
                        anchors.centerIn: parent
                        text: root.audioSink?.audio?.muted ? "󰖁" : "󰕾"
                        color: root.audioSink?.audio?.muted ? Theme.muted : Theme.accent
                        font.pixelSize: 16
                    }

                    MouseArea {
                        id: muteMouseArea
                        anchors.fill: parent
                        enabled: !!root.audioSink?.audio
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.audioSink.audio.muted = !root.audioSink.audio.muted
                    }
                }

                Text {
                    text: "Output volume"
                    color: Theme.text
                    font.pixelSize: 11
                    font.bold: true
                    anchors.left: parent.left
                    anchors.leftMargin: 32
                    anchors.verticalCenter: parent.verticalCenter
                }

                Rectangle {
                    width: volumeValue.implicitWidth + 14
                    height: 20
                    radius: 7
                    color: Theme.surface
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter

                    Text {
                        id: volumeValue
                        anchors.centerIn: parent
                        text: root.audioSink?.audio ? Math.round(root.audioSink.audio.volume * 100) + "%" : "--"
                        color: Theme.text
                        font.pixelSize: 10
                        font.bold: true
                    }
                }
            }

            Slider {
                id: popupVolumeSlider

                width: parent.width
                height: 26

                from: 0
                to: 1
                stepSize: 0.01

                enabled: root.audioSink?.audio !== null && root.audioSink?.audio !== undefined

                Binding {
                    target: popupVolumeSlider
                    property: "value"

                    value: root.audioSink?.audio?.volume ?? 0
                    when: !popupVolumeSlider.pressed
                }

                onMoved: {
                    if (root.audioSink?.audio) {
                        root.audioSink.audio.volume = value;
                    }
                }

                background: Rectangle {
                    x: popupVolumeSlider.leftPadding
                    y: popupVolumeSlider.topPadding + popupVolumeSlider.availableHeight / 2 - height / 2
                    width: popupVolumeSlider.availableWidth
                    height: 5
                    radius: 2.5
                    color: popupVolumeSlider.hovered ? Theme.border : Theme.surface

                    Rectangle {
                        width: parent.width * popupVolumeSlider.visualPosition
                        height: parent.height
                        radius: parent.radius
                        color: popupVolumeSlider.enabled ? Theme.accent : Theme.muted
                    }
                }

                handle: Rectangle {
                    x: popupVolumeSlider.leftPadding + popupVolumeSlider.visualPosition * (popupVolumeSlider.availableWidth - width)
                    y: popupVolumeSlider.topPadding + popupVolumeSlider.availableHeight / 2 - height / 2
                    width: popupVolumeSlider.hovered ? 16 : 14
                    height: popupVolumeSlider.hovered ? 16 : 14
                    radius: 8
                    color: Theme.text
                    border.width: 3
                    border.color: Theme.accent

                    Behavior on width { NumberAnimation { duration: 100 } }
                    Behavior on height { NumberAnimation { duration: 100 } }
                }
            }
        }
    }
}
