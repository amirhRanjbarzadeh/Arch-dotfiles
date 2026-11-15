import Quickshell
import QtQuick
import QtQuick.Controls
import "../styles"

PopupWindow {
    id: root
    property var barWindow
    property var audioSink

    anchor.window: root.barWindow
    anchor.rect.x: root.barWindow.width - width - 18
    anchor.rect.y: root.barWindow.height + 8

    color: "transparent"

    implicitWidth: 220
    implicitHeight: 78

    visible: false
    grabFocus: true

    Rectangle {
        anchors.fill: parent

        radius: 14
        color: Theme.background

        border {
            width: 1
            color: Theme.border
        }

        Column {
            anchors {
                fill: parent
                margins: 12
            }

            spacing: 8

            Row {
                width: parent.width

                Text {
                    text: "Volume"
                    color: Theme.text
                    font.pixelSize: 12
                    font.bold: true
                }

                Item {
                    width: parent.width - 65
                    height: 1
                }

                Text {
                    text: root.audioSink?.audio ? Math.round(root.audioSink.audio.volume * 100) + "%" : "--"

                    color: Theme.subtle
                    font.pixelSize: 11
                }
            }

            Slider {
                id: popupVolumeSlider

                width: parent.width
                height: 22

                from: 0
                to: 1
                stepSize: 0.01

                enabled: root.audioSink?.audio !== undefined

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
            }
        }
    }
}
