pragma ComponentBehavior: Bound

import Quickshell.Bluetooth
import QtQuick
import QtQuick.Layouts
import "../components"
import "../styles"

Item {
    id: root

    property var adapter
    readonly property bool powered: adapter?.enabled ?? false

    // Connected devices first, then paired, then the rest; alphabetical within each group.
    readonly property var sortedDevices: {
        const devices = Array.from(adapter?.devices.values ?? []);
        const rank = device => device.connected ? 0 : device.paired ? 1 : 2;
        return devices.sort((a, b) => rank(a) - rank(b) || (a.name || a.address).localeCompare(b.name || b.address));
    }

    // Only stop discovery we started ourselves.
    property bool startedDiscovery: false

    implicitWidth: 270
    implicitHeight: 220

    onVisibleChanged: {
        if (!visible && startedDiscovery && adapter) {
            adapter.discovering = false;
            startedDiscovery = false;
        }
    }

    Card {
        anchors.fill: parent

        ColumnLayout {
            anchors.fill: parent
            spacing: 10

            // Header
            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Text {
                    Layout.fillWidth: true
                    text: "Bluetooth"
                    color: Theme.text
                    font.pixelSize: 13
                    font.bold: true
                }

                IconButton {
                    id: scanButton
                    visible: root.powered
                    icon: Icons.refresh
                    iconColor: root.adapter?.discovering ? Theme.accent : Theme.subtle
                    active: root.adapter?.discovering ?? false
                    onClicked: {
                        root.adapter.discovering = !root.adapter.discovering;
                        root.startedDiscovery = root.adapter.discovering;
                    }

                    RotationAnimation on iconRotation {
                        running: root.adapter?.discovering ?? false
                        from: 0
                        to: 360
                        duration: 1200
                        loops: Animation.Infinite
                        onRunningChanged: if (!running) scanButton.iconRotation = 0
                    }
                }

                Toggle {
                    enabled: root.adapter !== null && root.adapter !== undefined
                    checked: root.powered
                    onToggled: root.adapter.enabled = !root.adapter.enabled
                }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 1
                color: Theme.border
            }

            // Device list
            ListView {
                id: deviceList

                Layout.fillWidth: true
                Layout.fillHeight: true

                clip: true
                spacing: 6
                boundsBehavior: Flickable.StopAtBounds
                model: root.powered ? root.sortedDevices : []

                delegate: Rectangle {
                    id: deviceRow

                    required property var modelData
                    readonly property var device: modelData
                    readonly property bool busy: device.pairing || device.state === BluetoothDeviceState.Connecting || device.state === BluetoothDeviceState.Disconnecting

                    width: deviceList.width
                    height: 42
                    radius: Theme.itemRadius
                    color: Theme.surface

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 6
                        spacing: 8

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            Text {
                                Layout.fillWidth: true
                                text: deviceRow.device.name || deviceRow.device.address
                                color: Theme.text
                                font.pixelSize: 11
                                elide: Text.ElideRight
                            }

                            Text {
                                text: {
                                    if (deviceRow.device.pairing)
                                        return "Pairing…";
                                    switch (deviceRow.device.state) {
                                    case BluetoothDeviceState.Connected:
                                        return "Connected";
                                    case BluetoothDeviceState.Connecting:
                                        return "Connecting…";
                                    case BluetoothDeviceState.Disconnecting:
                                        return "Disconnecting…";
                                    default:
                                        return deviceRow.device.paired ? "Paired" : "Available";
                                    }
                                }
                                color: deviceRow.busy ? Theme.warning : deviceRow.device.connected ? Theme.success : Theme.muted
                                font.pixelSize: 9
                            }
                        }

                        Text {
                            visible: deviceRow.device.batteryAvailable && deviceRow.device.connected
                            text: Math.round(deviceRow.device.battery * 100) + "%"
                            color: Theme.subtle
                            font.pixelSize: 10
                        }

                        IconButton {
                            enabled: !deviceRow.busy
                            opacity: enabled ? 1 : 0.4
                            icon: deviceRow.device.connected ? Icons.linkOff : Icons.link
                            iconColor: deviceRow.device.connected ? Theme.error : Theme.accent
                            iconSize: 15
                            onClicked: {
                                if (deviceRow.device.connected)
                                    deviceRow.device.disconnect();
                                else if (deviceRow.device.paired)
                                    deviceRow.device.connect();
                                else
                                    deviceRow.device.pair();
                            }
                        }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: deviceList.count === 0
                    text: {
                        if (!root.adapter)
                            return "No Bluetooth adapter";
                        if (!root.powered)
                            return "Bluetooth is off";
                        return root.adapter.discovering ? "Searching for devices…" : "No devices · press " + Icons.refresh + " to scan";
                    }
                    color: Theme.muted
                    font.pixelSize: 11
                }
            }
        }
    }
}
