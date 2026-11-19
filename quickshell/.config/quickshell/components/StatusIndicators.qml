import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.UPower
import QtQuick
import "../styles"

Row {
    id: root

    property var activeWifiNetwork: null
    property var audioSink: null
    property var adapter: null
    property bool recording: false
    property int recordingSeconds: 0
    property bool caffeine: false

    signal wifiRequested
    signal volumeRequested
    signal bluetoothRequested
    signal recordingStopRequested
    signal caffeineOffRequested

    readonly property var audio: audioSink?.audio ?? null
    readonly property var connectedBluetoothDevices: adapter?.devices.values.filter(device => device.connected) ?? []
    readonly property var battery: UPower.displayDevice

    spacing: 2

    // ----------------------------------
    // SCREEN RECORDING (only while it runs; click to stop and save)
    // ----------------------------------

    IconButton {
        id: recordButton

        anchors.verticalCenter: parent.verticalCenter
        visible: root.recording

        icon: Icons.record
        iconColor: Theme.error
        iconSize: 13
        label: Math.floor(root.recordingSeconds / 60) + ":" + String(root.recordingSeconds % 60).padStart(2, "0")
        tooltip: "Recording · click to stop"

        onClicked: root.recordingStopRequested()

        // Slow pulse so it reads as live.
        SequentialAnimation on opacity {
            running: root.recording
            loops: Animation.Infinite
            onStopped: recordButton.opacity = 1
            NumberAnimation { to: 0.45; duration: 900; easing.type: Easing.InOutSine }
            NumberAnimation { to: 1; duration: 900; easing.type: Easing.InOutSine }
        }
    }

    // ----------------------------------
    // CAFFEINE (only while on; click to turn off)
    // ----------------------------------

    IconButton {
        anchors.verticalCenter: parent.verticalCenter
        visible: root.caffeine

        icon: Icons.caffeine
        iconColor: Theme.warning
        iconSize: 14
        tooltip: "Caffeine · screen stays on · click to turn off"

        onClicked: root.caffeineOffRequested()
    }

    // ----------------------------------
    // KEYBOARD LAYOUT (click to switch)
    // ----------------------------------

    IconButton {
        id: layoutButton

        property string layoutName: ""

        function shortName(name) {
            const known = { "English (US)": "EN", "Persian": "FA" };
            return known[name] ?? name.slice(0, 2).toUpperCase();
        }

        anchors.verticalCenter: parent.verticalCenter
        visible: layoutName !== ""

        icon: shortName(layoutName)
        iconSize: 11
        iconColor: layoutName === "English (US)" ? Theme.text : Theme.accent
        tooltip: layoutName + " · click or Alt+Shift to switch"

        onClicked: switchProc.exec(["hyprctl", "switchxkblayout", "all", "next"])

        // Seed from the main keyboard; after that, Hyprland's activelayout events.
        Process {
            running: true
            command: ["hyprctl", "devices", "-j"]
            stdout: StdioCollector {
                onStreamFinished: {
                    try {
                        const keyboards = JSON.parse(text).keyboards;
                        const main = keyboards.find(keyboard => keyboard.main) ?? keyboards[0];
                        if (main)
                            layoutButton.layoutName = main.active_keymap;
                    } catch (e) {}
                }
            }
        }

        Process { id: switchProc }

        Connections {
            target: Hyprland
            // data is "<keyboard>,<layout name>"
            function onRawEvent(event) {
                if (event.name === "activelayout")
                    layoutButton.layoutName = event.data.slice(event.data.indexOf(",") + 1);
            }
        }
    }

    // ----------------------------------
    // WI-FI
    // ----------------------------------

    IconButton {
        anchors.verticalCenter: parent.verticalCenter

        icon: {
            if (!root.activeWifiNetwork)
                return Icons.wifiOff;
            const level = Math.min(3, Math.floor(root.activeWifiNetwork.signalStrength * 4));
            return Icons.wifiLevels[level];
        }
        iconColor: root.activeWifiNetwork ? Theme.text : Theme.muted
        tooltip: root.activeWifiNetwork ? root.activeWifiNetwork.name + " · " + Math.round(root.activeWifiNetwork.signalStrength * 100) + "%" : "Disconnected"

        onClicked: root.wifiRequested()
    }

    // ----------------------------------
    // BLUETOOTH
    // ----------------------------------

    IconButton {
        anchors.verticalCenter: parent.verticalCenter

        icon: {
            if (!root.adapter?.enabled)
                return Icons.bluetoothOff;
            return root.connectedBluetoothDevices.length > 0 ? Icons.bluetoothConnected : Icons.bluetooth;
        }
        iconColor: {
            if (!root.adapter)
                return Theme.error;
            return root.adapter.enabled ? Theme.accent : Theme.muted;
        }
        iconSize: 15
        tooltip: {
            if (!root.adapter)
                return "No Bluetooth adapter";
            if (!root.adapter.enabled)
                return "Bluetooth off";
            const names = root.connectedBluetoothDevices.map(device => device.name || device.address);
            return names.length > 0 ? names.join(", ") : "Bluetooth on";
        }

        onClicked: root.bluetoothRequested()
    }

    // ----------------------------------
    // VOLUME (scroll to adjust)
    // ----------------------------------

    IconButton {
        anchors.verticalCenter: parent.verticalCenter

        icon: {
            if (!root.audio || root.audio.muted)
                return Icons.volumeMute;
            if (root.audio.volume < 0.34)
                return Icons.volumeLow;
            return root.audio.volume < 0.67 ? Icons.volumeMedium : Icons.volumeHigh;
        }
        iconColor: !root.audio ? Theme.muted : root.audio.muted ? Theme.error : Theme.text
        tooltip: !root.audio ? "No audio output" : root.audio.muted ? "Muted" : "Volume " + Math.round(root.audio.volume * 100) + "%"

        onClicked: root.volumeRequested()
        acceptsWheel: true
        onScrolled: delta => {
            if (!root.audio || delta === 0)
                return;
            const step = delta > 0 ? 0.05 : -0.05;
            root.audio.volume = Math.max(0, Math.min(1, Math.round((root.audio.volume + step) * 100) / 100));
        }
    }

    // ----------------------------------
    // BATTERY (hidden on machines without one)
    // ----------------------------------

    IconButton {
        id: batteryButton

        readonly property real level: root.battery.percentage
        readonly property bool charging: root.battery.state === UPowerDeviceState.Charging || root.battery.state === UPowerDeviceState.PendingCharge
        readonly property bool full: root.battery.state === UPowerDeviceState.FullyCharged

        function formatDuration(seconds) {
            const hours = Math.floor(seconds / 3600);
            const minutes = Math.round((seconds % 3600) / 60);
            return hours > 0 ? hours + "h " + minutes + "m" : minutes + "m";
        }

        anchors.verticalCenter: parent.verticalCenter
        visible: root.battery.ready && root.battery.isLaptopBattery

        icon: {
            if (charging)
                return Icons.batteryCharging;
            if (level < 0.1)
                return Icons.batteryAlert;
            return Icons.batteryLevels[Math.min(9, Math.floor(level * 10))];
        }
        iconColor: {
            if (charging || full)
                return Theme.success;
            if (level < 0.15)
                return Theme.error;
            return level < 0.3 ? Theme.warning : Theme.text;
        }
        // Percentage lives in the tooltip to keep the bar calm.
        tooltip: {
            const percent = Math.round(level * 100) + "%";
            if (full)
                return percent + " · Fully charged";
            if (charging)
                return percent + (root.battery.timeToFull > 0 ? " · Full in " + formatDuration(root.battery.timeToFull) : " · Charging");
            return percent + (root.battery.timeToEmpty > 0 ? " · " + formatDuration(root.battery.timeToEmpty) + " remaining" : "");
        }
    }
}
