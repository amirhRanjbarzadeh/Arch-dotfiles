import QtQuick
import QtQuick.Layouts
import "../components"
import "../styles"

// Sound & display sliders. Shows one row as a key-press popup (volume or
// brightness keys) or both, plus the screen tools, when opened from the volume icon.
Item {
    id: root

    property var audioSink
    property var brightness // BrightnessService
    property var screenTools // ScreenService
    property bool showVolume: true
    property bool showBrightness: true
    property bool showTools: true

    // Recording starts with a region pick, so the panel has to get out of the way first.
    signal recordRequested

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

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 1
                visible: root.showTools
                color: Theme.border
            }

            ColumnLayout {
                Layout.fillWidth: true
                visible: root.showTools
                spacing: 2

                ToggleRow {
                    Layout.fillWidth: true
                    icon: Icons.nightLight
                    title: "Night light"
                    detail: root.screenTools?.nightLightAvailable ? (root.screenTools?.nightLight ? "Warm, " + root.screenTools.warmTemperature + "K" : "Off") : "Install hyprsunset"
                    enabled: root.screenTools?.nightLightAvailable ?? false
                    checked: root.screenTools?.nightLight ?? false
                    onToggled: root.screenTools.toggleNightLight(false)
                }

                ToggleRow {
                    Layout.fillWidth: true
                    icon: Icons.caffeine
                    title: "Caffeine"
                    detail: root.screenTools?.caffeine ? "Screen stays on" : "Off"
                    checked: root.screenTools?.caffeine ?? false
                    onToggled: root.screenTools.toggleCaffeine(false)
                }

                ToggleRow {
                    Layout.fillWidth: true
                    visible: root.screenTools?.canMirror ?? false
                    icon: Icons.monitor
                    title: "Mirror display"
                    detail: (root.screenTools?.mirrored ? "Mirroring to " : "Extended to ") + (root.screenTools?.externalMonitor ?? "")
                    checked: root.screenTools?.mirrored ?? false
                    onToggled: root.screenTools.toggleMirror(false)
                }

                ToggleRow {
                    Layout.fillWidth: true
                    icon: Icons.record
                    title: "Record screen"
                    detail: root.screenTools?.recording ? "Recording · click to stop" : "Pick a region"
                    activeColor: Theme.error
                    checked: root.screenTools?.recording ?? false
                    onToggled: root.screenTools?.recording ? root.screenTools.toggleRecording() : root.recordRequested()
                }
            }
        }
    }
}
