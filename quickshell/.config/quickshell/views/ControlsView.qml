import QtQuick
import QtQuick.Layouts
import "../components"
import "../styles"

// Sound & display sliders. Shows one row as a key-press popup (volume or
// brightness keys) or both when opened from the volume icon.
Item {
    id: root

    property var audioSink
    property var brightness // BrightnessService
    property bool showVolume: true
    property bool showBrightness: true

    readonly property var audio: audioSink?.audio ?? null

    implicitWidth: 260
    implicitHeight: rows.implicitHeight + 2 * card.padding

    Card {
        id: card

        anchors.fill: parent
        padding: 12

        ColumnLayout {
            id: rows

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            spacing: 10

            SliderRow {
                Layout.fillWidth: true
                visible: root.showVolume
                enabled: root.audio !== null

                icon: {
                    if (!root.audio || root.audio.muted)
                        return Icons.volumeMute;
                    if (root.audio.volume < 0.34)
                        return Icons.volumeLow;
                    return root.audio.volume < 0.67 ? Icons.volumeMedium : Icons.volumeHigh;
                }
                iconColor: root.audio?.muted ? Theme.muted : Theme.accent
                title: root.audioSink?.description || root.audioSink?.nickname || "Volume"
                valueText: !root.audio ? "--" : root.audio.muted ? "Muted" : Math.round(root.audio.volume * 100) + "%"
                value: root.audio?.volume ?? 0
                dimmed: root.audio?.muted ?? false

                onIconClicked: root.audio.muted = !root.audio.muted
                onMoved: value => root.audio.volume = value
            }

            SliderRow {
                Layout.fillWidth: true
                visible: root.showBrightness && (root.brightness?.available ?? false)

                icon: Icons.brightnessLevels[Math.min(2, Math.floor((root.brightness?.brightness ?? 0) * 3))]
                title: "Brightness"
                valueText: Math.round((root.brightness?.brightness ?? 0) * 100) + "%"
                value: root.brightness?.brightness ?? 0
                minimumValue: root.brightness?.minimum ?? 0

                onMoved: value => root.brightness.setBrightness(value)
            }
        }
    }
}
