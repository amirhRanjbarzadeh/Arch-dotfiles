import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"
import "../styles"

Item {
    id: root

    property var audioSink
    readonly property var audio: audioSink?.audio ?? null

    implicitWidth: 240
    implicitHeight: 78

    Card {
        anchors.fill: parent
        padding: 12

        ColumnLayout {
            anchors.fill: parent
            spacing: 4

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                IconButton {
                    enabled: root.audio !== null
                    opacity: enabled ? 1 : 0.5
                    icon: root.audio?.muted ? Icons.volumeMute : Icons.volumeHigh
                    iconColor: root.audio?.muted ? Theme.muted : Theme.accent
                    iconSize: 16
                    onClicked: root.audio.muted = !root.audio.muted
                }

                Text {
                    Layout.fillWidth: true
                    text: root.audioSink?.description || root.audioSink?.nickname || "Output volume"
                    color: Theme.text
                    font.pixelSize: 11
                    font.bold: true
                    elide: Text.ElideRight
                }

                Rectangle {
                    implicitWidth: Math.max(38, volumeValue.implicitWidth + 14)
                    implicitHeight: 20
                    radius: 7
                    color: Theme.surface

                    Text {
                        id: volumeValue
                        anchors.centerIn: parent
                        text: !root.audio ? "--" : root.audio.muted ? "Muted" : Math.round(root.audio.volume * 100) + "%"
                        color: root.audio?.muted ? Theme.muted : Theme.text
                        font.pixelSize: 10
                        font.bold: true
                    }
                }
            }

            Slider {
                id: volumeSlider

                Layout.fillWidth: true
                Layout.preferredHeight: 26

                from: 0
                to: 1
                stepSize: 0.01
                enabled: root.audio !== null

                // Follow the system volume except while the user is dragging.
                Binding {
                    target: volumeSlider
                    property: "value"
                    value: root.audio?.volume ?? 0
                    when: !volumeSlider.pressed
                }

                onMoved: {
                    if (root.audio)
                        root.audio.volume = value;
                }

                background: Rectangle {
                    x: volumeSlider.leftPadding
                    y: volumeSlider.topPadding + volumeSlider.availableHeight / 2 - height / 2
                    width: volumeSlider.availableWidth
                    height: 5
                    radius: 2.5
                    color: volumeSlider.hovered ? Theme.border : Theme.surface

                    Rectangle {
                        width: parent.width * volumeSlider.visualPosition
                        height: parent.height
                        radius: parent.radius
                        color: volumeSlider.enabled && !root.audio?.muted ? Theme.accent : Theme.muted
                    }
                }

                handle: Rectangle {
                    x: volumeSlider.leftPadding + volumeSlider.visualPosition * (volumeSlider.availableWidth - width)
                    y: volumeSlider.topPadding + volumeSlider.availableHeight / 2 - height / 2
                    width: volumeSlider.hovered || volumeSlider.pressed ? 16 : 14
                    height: width
                    radius: width / 2
                    color: Theme.text
                    border.width: 3
                    border.color: root.audio?.muted ? Theme.muted : Theme.accent

                    Behavior on width { NumberAnimation { duration: 100 } }
                }
            }
        }
    }
}
